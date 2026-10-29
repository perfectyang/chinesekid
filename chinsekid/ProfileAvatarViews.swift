import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileAvatarView: View {
    let user: ChildProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let image = ProfileAvatarStore.image(for: user.avatarFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(KidsTheme.yellow)
                    Text(user.avatar).font(.system(size: size * 0.55))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
    }
}

struct ProfileAvatarEditor: View {
    let user: ChildProfile
    let onSave: (ChildProfile, UIImage) -> Void

    @State private var activeSheet: AvatarEditorSheet?
    @State private var cameraUnavailable = false
    @State private var capturedImage: UIImage?

    var body: some View {
        Button {
            KeyboardSupport.dismissActiveInput()
            activeSheet = .sourceOptions
        } label: {
            ProfileAvatarView(user: user, size: 52)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, KidsTheme.ink)
                        .offset(x: 2, y: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更换\(user.name)的头像")
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .sourceOptions:
                    AvatarSourceOptionsSheet(
                        userName: user.name,
                        onCamera: {
                            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                                activeSheet = nil
                                cameraUnavailable = true
                                return
                            }
                            activeSheet = .camera
                        },
                        onPhotoLibrary: { activeSheet = .photoLibrary },
                        onCancel: { activeSheet = nil }
                    )
                case .photoLibrary:
                    PhotoLibraryPicker { data in
                        activeSheet = nil
                        guard let data, let image = UIImage(data: data) else { return }
                        onSave(user, image)
                    }
                    .ignoresSafeArea()
                case .camera:
                    ProfileCameraPicker(image: $capturedImage)
                        .ignoresSafeArea()
                }
            }
            .presentationDetents(sheet == .sourceOptions ? [.height(250)] : [.large])
            .presentationDragIndicator(sheet == .sourceOptions ? .visible : .hidden)
            .interactiveDismissDisabled()
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            onSave(user, image)
            capturedImage = nil
        }
        .alert("无法更换头像", isPresented: $cameraUnavailable) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("当前设备无法打开相机或读取照片，请再试一次。")
        }
    }

}

private enum AvatarEditorSheet: String, Identifiable {
    case sourceOptions
    case photoLibrary
    case camera

    var id: String { rawValue }
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onSelect: (Data?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onSelect: (Data?) -> Void

        init(onSelect: @escaping (Data?) -> Void) {
            self.onSelect = onSelect
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onSelect(nil)
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [onSelect = self.onSelect] data, _ in
                DispatchQueue.main.async {
                    onSelect(data)
                }
            }
        }
    }
}

private struct AvatarSourceOptionsSheet: View {
    let userName: String
    let onCamera: () -> Void
    let onPhotoLibrary: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("更换头像")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            Text("为 \(userName) 选一张喜欢的照片")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
            Button(action: onCamera) {
                Label("拍照", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(KidsTheme.mint)
            .foregroundStyle(KidsTheme.ink)
            Button(action: onPhotoLibrary) {
                Label("从相册选择", systemImage: "photo")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(KidsTheme.ink)
            Button("取消", action: onCancel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StorybookBackground())
    }
}

private struct ProfileCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ProfileCameraPicker

        init(_ parent: ProfileCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
