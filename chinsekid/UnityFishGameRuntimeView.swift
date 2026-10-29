import ObjectiveC.runtime
import SwiftUI
import UIKit

enum UnityFishGameRuntimeState: Equatable {
    case waiting
    case active
    case unavailable
    case finished
}

struct UnityFishGameRuntimeView: UIViewControllerRepresentable {
    let onAvailabilityChanged: (Bool) -> Void
    let onFinish: (Int, Int, Int) -> Void

    func makeUIViewController(context: Context) -> UnityFishGameViewController {
        let controller = UnityFishGameViewController()
        controller.onAvailabilityChanged = onAvailabilityChanged
        controller.onFinish = onFinish
        return controller
    }

    func updateUIViewController(_ controller: UnityFishGameViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: UnityFishGameViewController, coordinator: ()) {
        controller.pauseUnity(true)
    }
}

@MainActor
final class UnityFishGameViewController: UIViewController {
    var onAvailabilityChanged: ((Bool) -> Void)?
    var onFinish: ((Int, Int, Int) -> Void)?
    private var unityBundle: Bundle?
    private var notification: NSObjectProtocol?
    private var didStart = false
    private weak var hostWindow: UIWindow?
    private var pendingResult: (score: Int, level: Int, eaten: Int)?
    private static var didLaunchRuntime = false
    private static var retainedFramework: NSObject?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        notification = NotificationCenter.default.addObserver(
            forName: Notification.Name("Chinsekid.UnityFishGameDidFinish"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let score = note.userInfo?["score"] as? Int ?? 0
            let level = note.userInfo?["level"] as? Int ?? 1
            let eaten = note.userInfo?["eaten"] as? Int ?? 0
            Task { @MainActor [weak self] in
                self?.pendingResult = (score, level, eaten)
                self?.unloadUnity()
            }
        }
        startUnityIfAvailable()
    }

    deinit {
        if let notification { NotificationCenter.default.removeObserver(notification) }
    }

    private func startUnityIfAvailable() {
        guard !didStart else { return }
        didStart = true
        NSLog("[UnityFishGame] Starting embedded runtime")
        guard
            let frameworkURL = Bundle.main.privateFrameworksURL?.appendingPathComponent("UnityFramework.framework"),
            let bundle = Bundle(url: frameworkURL),
            bundle.load(),
            let frameworkClass = NSClassFromString("UnityFramework")
        else {
            NSLog("[UnityFishGame] UnityFramework could not be loaded from the host app")
            showRuntimeNotInstalled()
            return
        }
        NSLog("[UnityFishGame] UnityFramework bundle loaded")

        let getInstanceSelector = NSSelectorFromString("getInstance")
        guard let classMethod = class_getClassMethod(frameworkClass, getInstanceSelector) else {
            showRuntimeNotInstalled()
            return
        }
        typealias GetInstance = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>?
        let getInstance = unsafeBitCast(method_getImplementation(classMethod), to: GetInstance.self)
        guard let framework = getInstance(frameworkClass, getInstanceSelector)?.takeUnretainedValue() as? NSObject else {
            NSLog("[UnityFishGame] UnityFramework.getInstance returned nil")
            showRuntimeNotInstalled()
            return
        }

        unityBundle = bundle
        hostWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        let registerListener = NSSelectorFromString("registerFrameworkListener:")
        if framework.responds(to: registerListener) { _ = framework.perform(registerListener, with: self) }
        let showWindow = NSSelectorFromString("showUnityWindow")
        if Self.didLaunchRuntime {
            guard framework.perform(NSSelectorFromString("appController"))?.takeUnretainedValue() as? NSObject != nil else {
                NSLog("[UnityFishGame] Unity app controller is unavailable after launch")
                showRuntimeNotInstalled()
                return
            }
            if framework.responds(to: showWindow) { _ = framework.perform(showWindow) }
            pauseUnity(false, framework: framework)
            notifyAvailabilityChanged(true)
            return
        }

        let selector = NSSelectorFromString("runEmbeddedWithArgc:argv:appLaunchOpts:")
        guard framework.responds(to: selector) else {
            showRuntimeNotInstalled()
            return
        }

        let setBundleSelector = NSSelectorFromString("setDataBundleId:")
        if framework.responds(to: setBundleSelector), let bundleID = Bundle.main.bundleIdentifier {
            typealias SetDataBundleID = @convention(c) (NSObject, Selector, UnsafePointer<CChar>) -> Void
            let setDataBundleID = unsafeBitCast(framework.method(for: setBundleSelector), to: SetDataBundleID.self)
            bundleID.withCString { setDataBundleID(framework, setBundleSelector, $0) }
            NSLog("[UnityFishGame] Unity Data bundle id set to %@", bundleID)
        }

        typealias RunEmbedded = @convention(c) (NSObject, Selector, Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, NSDictionary) -> Void
        let runEmbedded = unsafeBitCast(framework.method(for: selector), to: RunEmbedded.self)
        NSLog("[UnityFishGame] Calling runEmbeddedWithArgc")
        // Unity retains argv and reads it again during pause/unload. A withCString
        // buffer is temporary and causes a later crash in HasARGV/strlen.
        runEmbedded(framework, selector, CommandLine.argc, CommandLine.unsafeArgv, [:])
        NSLog("[UnityFishGame] runEmbeddedWithArgc returned")

        guard framework.perform(NSSelectorFromString("appController"))?.takeUnretainedValue() as? NSObject != nil else {
            NSLog("[UnityFishGame] Unity app controller is unavailable after embedded launch")
            showRuntimeNotInstalled()
            return
        }

        if framework.responds(to: showWindow) {
            _ = framework.perform(showWindow)
            NSLog("[UnityFishGame] showUnityWindow called")
        }
        Self.didLaunchRuntime = true
        Self.retainedFramework = framework
        notifyAvailabilityChanged(true)
    }

    func pauseUnity(_ paused: Bool) {
        guard let framework = Self.retainedFramework else { return }
        pauseUnity(paused, framework: framework)
    }

    private func pauseUnity(_ paused: Bool, framework: NSObject) {
        let selector = NSSelectorFromString("pause:")
        guard framework.responds(to: selector) else { return }
        typealias Pause = @convention(c) (NSObject, Selector, Bool) -> Void
        let pause = unsafeBitCast(framework.method(for: selector), to: Pause.self)
        pause(framework, selector, paused)
    }

    private func unloadUnity() {
        guard let framework = Self.retainedFramework else { return }
        let selector = NSSelectorFromString("unloadApplication")
        if framework.responds(to: selector) { _ = framework.perform(selector) }
    }

    @objc func unityDidUnload(_ notification: NSNotification) {
        if let framework = Self.retainedFramework {
            let selector = NSSelectorFromString("unregisterFrameworkListener:")
            if framework.responds(to: selector) { _ = framework.perform(selector, with: self) }
        }
        hostWindow?.makeKeyAndVisible()
        Self.retainedFramework = nil
        Self.didLaunchRuntime = false
        if let result = pendingResult {
            pendingResult = nil
            onFinish?(result.score, result.level, result.eaten)
        }
    }

    private func showRuntimeNotInstalled() {
        notifyAvailabilityChanged(false)
    }

    private func notifyAvailabilityChanged(_ available: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onAvailabilityChanged?(available)
        }
    }
}
