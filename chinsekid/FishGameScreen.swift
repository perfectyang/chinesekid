import AVFoundation
import SpriteKit
import SwiftUI
import UIKit

@MainActor
private final class FishGameBackgroundMusic {
    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    private var lastPlaybackAttempt = Date.distantPast
    private var isInterrupted = false
    private var playbackRequested = false

    init() {
        let bundle = Bundle.main
        let candidates = [
            bundle.url(forResource: "FishGameMusic_Looped", withExtension: "wav", subdirectory: "Resources"),
            bundle.url(forResource: "FishGameMusic_Looped", withExtension: "wav"),
            bundle.resourceURL?.appendingPathComponent("Resources/FishGameMusic_Looped.wav"),
            bundle.resourceURL?.appendingPathComponent("FishGameMusic_Looped.wav")
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            NSLog("Missing bundled fish game music")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.28
            if player?.prepareToPlay() != true {
                NSLog("Unable to prepare fish game music")
            }
        } catch {
            NSLog("Unable to load fish game music: %@", error.localizedDescription)
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(type: rawType, options: rawOptions)
            }
        }
    }

    func resume() {
        playbackRequested = true
        guard !isInterrupted else { return }
        lastPlaybackAttempt = Date()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if let player, !player.isPlaying, !player.play() {
                NSLog("Fish game music player did not start")
            }
        } catch {
            NSLog("Unable to start fish game music: %@", error.localizedDescription)
        }
    }

    func pause() {
        playbackRequested = false
        player?.pause()
    }

    func recoverIfPlaybackStopped() {
        guard playbackRequested, !isInterrupted, let player, !player.isPlaying else { return }
        guard Date().timeIntervalSince(lastPlaybackAttempt) >= 1 else { return }
        resume()
    }

    func stop() {
        playbackRequested = false
        player?.stop()
        player?.currentTime = 0
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
    }

    private func handleInterruption(type rawType: UInt?, options rawOptions: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            isInterrupted = true
        case .ended:
            isInterrupted = false
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions ?? 0)
            if options.contains(.shouldResume) {
                resume()
            } else {
                playbackRequested = false
            }
        @unknown default:
            isInterrupted = false
        }
    }
}

private struct FishSkinUnlockRule {
    let bestLevel: Int
    let totalFish: Int
    var bestRunFish: Int = 0

    func isMet(bestLevel: Int, totalFish: Int, bestRunFish: Int) -> Bool {
        bestLevel >= self.bestLevel && totalFish >= self.totalFish && bestRunFish >= self.bestRunFish
    }

    var summary: String {
        var parts = ["单局 Lv.\(bestLevel)", "累计 \(totalFish) 条"]
        if bestRunFish > 0 { parts.append("单局吃 \(bestRunFish) 条") }
        return parts.joined(separator: " · ")
    }
}

private enum FishSpecies: String, CaseIterable, Hashable, Identifiable {
    case clownfish
    case puffer
    case butterfly
    case tang
    case green
    case shark
    case angler
    case screenshotClown
    case blueMinnow
    case stripedCoral
    case reefShark
    case redfin
    case tealPuffer
    case silverfish
    case longfinFish
    case shrimp
    case octopus
    case goldenReference, patternedReef, rubyLionfish, spottedPuffer
    case azureAngelfish, fangHunter, grinningShark, yellowTang, iridescentShark

    var id: String { rawValue }

    var canonicalSkin: FishSpecies {
        switch self {
        case .screenshotClown: .clownfish
        case .blueMinnow: .tang
        case .reefShark: .shark
        case .tealPuffer: .puffer
        default: self
        }
    }

    static var selectableSkins: [FishSpecies] {
        allCases
            .filter { $0.canonicalSkin == $0 }
            .sorted {
                let left = $0.unlockRule
                let right = $1.unlockRule
                if left?.bestLevel != right?.bestLevel { return (left?.bestLevel ?? 0) < (right?.bestLevel ?? 0) }
                return (left?.totalFish ?? 0) < (right?.totalFish ?? 0)
            }
    }

    var unityModelName: String {
        switch self {
        case .clownfish, .screenshotClown: "Clownfish"
        case .puffer, .tealPuffer: "Puffer"
        case .butterfly: "ButterflyFish"
        case .tang, .blueMinnow: "BlueTang"
        case .green: "CoralGrouper"
        case .shark, .reefShark: "Shark"
        case .angler: "Anglerfish"
        case .stripedCoral: "RoyalGramma"
        case .redfin: "Goldfish"
        case .silverfish: "Koi"
        case .longfinFish: "Lionfish"
        case .shrimp: "Shrimp"
        case .octopus: "Octopus"
        case .goldenReference: "GoldenReference"
        case .patternedReef: "PatternedReef"
        case .rubyLionfish: "RubyLionfish"
        case .spottedPuffer: "SpottedPuffer"
        case .azureAngelfish: "AzureAngelfish"
        case .fangHunter: "FangHunter"
        case .grinningShark: "GrinningShark"
        case .iridescentShark: "IridescentShark"
        case .yellowTang: "Tang"
        }
    }

    var skinName: String {
        switch self {
        case .clownfish: "小丑鱼"
        case .puffer: "河豚"
        case .butterfly: "蝴蝶鱼"
        case .tang: "蓝倒吊鱼"
        case .green: "珊瑚石斑鱼"
        case .shark: "蓝鲨"
        case .angler: "灯笼鱼"
        case .screenshotClown: "珊瑚小丑鱼"
        case .blueMinnow: "蓝泡鱼"
        case .stripedCoral: "皇家双色鱼"
        case .reefShark: "礁鲨"
        case .redfin: "金鱼"
        case .tealPuffer: "大眼泡泡鱼"
        case .silverfish: "锦鲤"
        case .longfinFish: "狮子鱼"
        case .shrimp: "小虾米"
        case .octopus: "粉章鱼"
        case .goldenReference: "金鳞鱼"
        case .patternedReef: "金纹蓝鳍鱼"
        case .rubyLionfish: "红狮子鱼"
        case .spottedPuffer: "斑点河豚"
        case .azureAngelfish: "蓝神仙鱼"
        case .fangHunter: "尖牙猎手"
        case .grinningShark: "笑脸鲨鱼"
        case .iridescentShark: "幻彩大白鲨"
        case .yellowTang: "黄金倒吊鱼"
        }
    }

    var unlockRule: FishSkinUnlockRule? {
        switch self {
        case .clownfish: nil
        case .tang, .blueMinnow: .init(bestLevel: 3, totalFish: 12)
        case .shrimp: .init(bestLevel: 4, totalFish: 18)
        case .puffer, .tealPuffer: .init(bestLevel: 4, totalFish: 25)
        case .butterfly: .init(bestLevel: 5, totalFish: 30)
        case .goldenReference: .init(bestLevel: 5, totalFish: 35)
        case .yellowTang: .init(bestLevel: 6, totalFish: 50)
        case .redfin: .init(bestLevel: 6, totalFish: 55)
        case .stripedCoral: .init(bestLevel: 7, totalFish: 60)
        case .silverfish: .init(bestLevel: 7, totalFish: 70)
        case .spottedPuffer: .init(bestLevel: 8, totalFish: 85)
        case .patternedReef: .init(bestLevel: 8, totalFish: 95)
        case .octopus: .init(bestLevel: 9, totalFish: 110)
        case .longfinFish: .init(bestLevel: 9, totalFish: 120)
        case .green: .init(bestLevel: 10, totalFish: 145)
        case .azureAngelfish: .init(bestLevel: 11, totalFish: 180)
        case .angler: .init(bestLevel: 11, totalFish: 210)
        case .rubyLionfish: .init(bestLevel: 12, totalFish: 240)
        case .shark, .reefShark: .init(bestLevel: 12, totalFish: 270, bestRunFish: 25)
        case .fangHunter: .init(bestLevel: 13, totalFish: 300, bestRunFish: 30)
        case .grinningShark: .init(bestLevel: 14, totalFish: 360, bestRunFish: 40)
        case .iridescentShark: .init(bestLevel: 15, totalFish: 480, bestRunFish: 50)
        case .screenshotClown: nil
        }
    }

    var color: Color {
        switch self {
        case .clownfish: Color(red: 1.0, green: 0.39, blue: 0.20)
        case .puffer: Color(red: 0.97, green: 0.70, blue: 0.25)
        case .butterfly: Color(red: 0.99, green: 0.79, blue: 0.28)
        case .tang: Color(red: 0.24, green: 0.58, blue: 0.85)
        case .green: Color(red: 0.20, green: 0.68, blue: 0.49)
        case .shark: Color(red: 0.42, green: 0.57, blue: 0.63)
        case .angler: Color(red: 0.50, green: 0.38, blue: 0.67)
        case .screenshotClown: Color(red: 1.0, green: 0.48, blue: 0.19)
        case .blueMinnow: Color(red: 0.36, green: 0.68, blue: 0.84)
        case .stripedCoral: Color(red: 0.91, green: 0.28, blue: 0.57)
        case .reefShark: Color(red: 0.38, green: 0.55, blue: 0.65)
        case .redfin: Color(red: 0.91, green: 0.57, blue: 0.23)
        case .tealPuffer: Color(red: 0.17, green: 0.65, blue: 0.63)
        case .silverfish: Color(red: 0.62, green: 0.70, blue: 0.76)
        case .longfinFish: Color(red: 0.44, green: 0.52, blue: 0.62)
        case .shrimp: Color(red: 0.98, green: 0.48, blue: 0.58)
        case .octopus: Color(red: 0.78, green: 0.43, blue: 0.61)
        case .goldenReference, .patternedReef, .yellowTang: Color(red: 0.94, green: 0.64, blue: 0.14)
        case .rubyLionfish: Color(red: 0.76, green: 0.13, blue: 0.12)
        case .spottedPuffer: Color(red: 0.59, green: 0.69, blue: 0.31)
        case .azureAngelfish: Color(red: 0.24, green: 0.67, blue: 0.82)
        case .fangHunter: Color(red: 0.26, green: 0.47, blue: 0.49)
        case .grinningShark: Color(red: 0.20, green: 0.48, blue: 0.64)
        case .iridescentShark: Color(red: 0.28, green: 0.39, blue: 0.54)
        }
    }

    var spriteFacesRight: Bool { self != .screenshotClown }
}

private enum FishModelPreviewCatalog {
    // Generated from the exact prefabs used by Unity, including procedural shrimp/octopus.
    static let images: [FishSpecies: UIImage] = Dictionary(uniqueKeysWithValues: FishSpecies.selectableSkins.compactMap { skin in
        let name = skin.unityModelName
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Resources/FishModelPreviews"),
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "FishModelPreviews"),
            Bundle.main.url(forResource: name, withExtension: "png")
        ]
        guard let image = candidates.compactMap({ $0 }).compactMap({ UIImage(contentsOfFile: $0.path) }).first else { return nil }
        return (skin, image)
    })
}

private enum FishSpriteCatalog {
    private static let names: [(FishSpecies, String)] = [
        (.clownfish, "fish_orange"),
        (.puffer, "fish_brown"),
        (.butterfly, "fish_pink"),
        (.tang, "fish_blue"),
        (.green, "fish_green"),
        (.shark, "fish_grey_long_a"),
        (.angler, "fish_red"),
        (.screenshotClown, "fish_game_clown"),
        (.blueMinnow, "fish_game_blue"),
        (.stripedCoral, "fish_game_striped"),
        (.reefShark, "fish_game_shark"),
        (.redfin, "fish_game_redfin"),
        (.tealPuffer, "fish_game_teal"),
        (.silverfish, "fish_grey"),
        (.longfinFish, "fish_grey_long_b"),
        (.iridescentShark, "fish_iridescent_shark")
    ]
    static let sprites: [FishSpecies: UIImage] = Dictionary(uniqueKeysWithValues: names.compactMap { entry in
        guard let image = load(entry.1) else { return nil }
        return (entry.0, image)
    })

    private static func load(_ name: String) -> UIImage? {
        let bundle = Bundle.main
        let urls = [
            bundle.url(forResource: name, withExtension: "png", subdirectory: "Resources/FishSprites"),
            bundle.url(forResource: name, withExtension: "png", subdirectory: "FishSprites"),
            bundle.url(forResource: name, withExtension: "png")
        ]
        for url in urls.compactMap({ $0 }) {
            if let image = UIImage(contentsOfFile: url.path) { return image }
        }
        NSLog("Missing fish sprite: %@.png", name)
        return nil
    }
}

private struct OceanFish: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector
    var radius: CGFloat
    var speed: CGFloat
    var species: FishSpecies
    var isInSchool = false
    var turnRate: CGFloat = 2.8
    var isHuntingPlayer = false
    var chaseWindup: CGFloat = 0
    var chaseRemaining: CGFloat = 0
    var chaseCooldown: CGFloat = 0
    var levelOverride: Int? = nil
}

private enum FishPowerUpKind: CaseIterable, Equatable {
    case speed
    case shield
    case magnet

    var unlockLevel: Int {
        switch self {
        case .speed: 2
        case .shield: 3
        case .magnet: 4
        }
    }

    var title: String {
        switch self {
        case .speed: "加速"
        case .shield: "护盾"
        case .magnet: "吸鱼"
        }
    }

    var symbol: String {
        switch self {
        case .speed: "⚡"
        case .shield: "🫧"
        case .magnet: "🧲"
        }
    }

    var color: Color {
        switch self {
        case .speed: KidsTheme.orange
        case .shield: KidsTheme.blue
        case .magnet: KidsTheme.mint
        }
    }
}

private struct FishPowerUp: Identifiable {
    let id = UUID()
    var position: CGPoint
    var kind: FishPowerUpKind
    var remainingTime: CGFloat = 28
    var radius: CGFloat = 17
}

private struct SeaMine: Identifiable {
    let id = UUID()
    var position: CGPoint
    var remainingTime: CGFloat = 32
    var radius: CGFloat = 18
}

private enum FishGamePhase: Equatable {
    case intro
    case playing
}

@MainActor private final class FishRenderNode: SKNode {
    let art = SKNode()
    let sprite = SKSpriteNode()
    let emoji = SKLabelNode(fontNamed: "AppleColorEmoji")
    let levelPlate = SKShapeNode()
    let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    let playerHalo = SKShapeNode()
    let powerUpHalo = SKShapeNode()
    var renderedSpecies: FishSpecies?
    var renderedLevel: Int?
    var renderedRadius: CGFloat = -1

    override init() {
        super.init()
        addChild(art)
        art.addChild(sprite)
        emoji.horizontalAlignmentMode = .center
        emoji.verticalAlignmentMode = .center
        art.addChild(emoji)
        levelPlate.fillColor = UIColor(red: 0.04, green: 0.25, blue: 0.32, alpha: 0.84)
        levelPlate.strokeColor = .clear
        addChild(levelPlate)
        levelLabel.fontColor = .white
        levelLabel.verticalAlignmentMode = .center
        levelPlate.addChild(levelLabel)
        playerHalo.fillColor = .clear
        playerHalo.strokeColor = .white.withAlphaComponent(0.88)
        playerHalo.lineWidth = 2.5
        addChild(playerHalo)
        powerUpHalo.fillColor = .clear
        powerUpHalo.lineWidth = 2
        addChild(powerUpHalo)
        zPosition = 20
    }

    required init?(coder aDecoder: NSCoder) { nil }
}

@MainActor private final class FishPowerUpRenderNode: SKNode {
    let glow = SKShapeNode()
    let symbol = SKLabelNode(fontNamed: "AppleColorEmoji")
    var renderedRadius: CGFloat = -1
    var renderedKind: FishPowerUpKind?

    override init() {
        super.init()
        glow.fillColor = UIColor.white.withAlphaComponent(0.18)
        glow.strokeColor = UIColor.white.withAlphaComponent(0.7)
        glow.lineWidth = 1.5
        addChild(glow)
        symbol.horizontalAlignmentMode = .center
        symbol.verticalAlignmentMode = .center
        addChild(symbol)
        zPosition = 12
    }

    required init?(coder aDecoder: NSCoder) { nil }
}

/// SpriteKit owns the per-frame rendering; SwiftUI continues to own game rules and the surrounding UI.
@MainActor private final class FishRenderScene: SKScene {
    private let water = SKSpriteNode()
    private let surfaceGlow = SKShapeNode()
    private let seaFloor = SKShapeNode()
    private let seaweed = SKShapeNode()
    private var fishNodes: [UUID: FishRenderNode] = [:]
    private var powerUpNodes: [UUID: FishPowerUpRenderNode] = [:]
    private var mineNodes: [UUID: SKNode] = [:]
    private let growthHUD = SKNode()
    private let growthPlate = SKShapeNode()
    private let growthText = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let growthTrack = SKShapeNode()
    private let growthFill = SKShapeNode()
    private var bubbleNodes: [SKShapeNode] = []
    private var lightRays: [SKShapeNode] = []
    private var backgroundSize = CGSize.zero
    private var renderedGrowthText: String?
    private var renderedGrowthProgress: CGFloat?
    private static let fishTextures = FishSpriteCatalog.sprites.mapValues { SKTexture(image: $0) }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.035, green: 0.29, blue: 0.39, alpha: 1)
        water.texture = Self.waterTexture
        water.zPosition = -100
        addChild(water)
        configureGrowthHUD()
        configureBubbles()
        configureLightRays()
    }

    required init?(coder aDecoder: NSCoder) { nil }

    func synchronize(
        viewport: CGSize,
        camera: CGPoint,
        fishes: [(OceanFish, Int)],
        powerUps: [FishPowerUp],
        seaMines: [SeaMine],
        playerPosition: CGPoint,
        playerRadius: CGFloat,
        playerDirection: CGVector,
        playerSpecies: FishSpecies,
        playerLevel: Int,
        score: Int,
        scorePerLevel: Int,
        time: CGFloat,
        hasSpeedBoost: Bool,
        hasShield: Bool,
        hasMagnet: Bool
    ) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        if size != viewport { size = viewport }
        if backgroundSize != viewport { resizeBackground(to: viewport) }

        var fishIds = Set(fishes.map { $0.0.id })
        fishIds.insert(Self.playerNodeID)
        for id in fishNodes.keys.filter({ !fishIds.contains($0) }) {
            fishNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for (fish, fishLevel) in fishes {
            let node = fishNodes[fish.id] ?? makeFishNode()
            if node.parent == nil {
                addChild(node)
                fishNodes[fish.id] = node
            }
            updateFishNode(node, position: fish.position, camera: camera, radius: fish.radius, direction: fish.direction, species: fish.species, level: fishLevel, time: time, isPlayer: false)
        }

        let powerUpIds = Set(powerUps.map(\.id))
        for id in powerUpNodes.keys.filter({ !powerUpIds.contains($0) }) {
            powerUpNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for powerUp in powerUps {
            let node = powerUpNodes[powerUp.id] ?? FishPowerUpRenderNode()
            if node.parent == nil {
                addChild(node)
                powerUpNodes[powerUp.id] = node
            }
            let point = screenPoint(powerUp.position, camera: camera, viewport: viewport)
            node.position = point
            node.isHidden = point.x < -powerUp.radius * 2 || point.x > viewport.width + powerUp.radius * 2 || point.y < -powerUp.radius * 2 || point.y > viewport.height + powerUp.radius * 2
            if node.renderedRadius != powerUp.radius || node.renderedKind != powerUp.kind {
                node.glow.path = CGPath(ellipseIn: CGRect(x: -powerUp.radius * 1.5, y: -powerUp.radius * 1.5, width: powerUp.radius * 3, height: powerUp.radius * 3), transform: nil)
                node.glow.fillColor = Self.powerUpColor(powerUp.kind).withAlphaComponent(0.2)
                node.glow.strokeColor = Self.powerUpColor(powerUp.kind).withAlphaComponent(0.85)
                node.symbol.text = powerUp.kind.symbol
                node.symbol.fontSize = powerUp.radius * 1.65
                node.renderedRadius = powerUp.radius
                node.renderedKind = powerUp.kind
            }
            node.setScale(1 + sin(time * 4 + point.x * 0.02) * 0.06)
        }

        let mineIds = Set(seaMines.map(\.id))
        for id in mineNodes.keys.filter({ !mineIds.contains($0) }) {
            mineNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for mine in seaMines {
            let node = mineNodes[mine.id] ?? makeMineNode()
            if node.parent == nil {
                addChild(node)
                mineNodes[mine.id] = node
            }
            node.position = screenPoint(mine.position, camera: camera, viewport: viewport)
            node.isHidden = node.position.x < -mine.radius * 2 || node.position.x > viewport.width + mine.radius * 2 || node.position.y < -mine.radius * 2 || node.position.y > viewport.height + mine.radius * 2
            node.setScale(mine.radius / 18)
            node.zRotation = sin(time * 2 + node.position.x * 0.02) * 0.08
        }

        let playerNode = fishNodes[Self.playerNodeID] ?? makeFishNode()
        if playerNode.parent == nil {
            addChild(playerNode)
            fishNodes[Self.playerNodeID] = playerNode
        }
        updateFishNode(playerNode, position: playerPosition, camera: camera, radius: playerRadius, direction: playerDirection, species: playerSpecies, level: playerLevel, time: time, isPlayer: true)
        playerNode.playerHalo.isHidden = false
        playerNode.powerUpHalo.isHidden = !(hasSpeedBoost || hasShield || hasMagnet)
        playerNode.powerUpHalo.strokeColor = hasShield ? UIColor.systemTeal.withAlphaComponent(0.9) : (hasSpeedBoost ? UIColor.systemYellow.withAlphaComponent(0.95) : UIColor.systemGreen.withAlphaComponent(0.9))
        playerNode.powerUpHalo.lineWidth = hasShield ? 3 : 2
        playerNode.powerUpHalo.path = CGPath(ellipseIn: CGRect(x: -playerRadius * 1.95, y: -playerRadius * 1.48, width: playerRadius * 3.9, height: playerRadius * 2.96), transform: nil)
        if playerNode.powerUpHalo.action(forKey: "power-up-pulse") == nil {
            playerNode.powerUpHalo.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.4, duration: 0.42),
                .fadeAlpha(to: 1, duration: 0.42)
            ])), withKey: "power-up-pulse")
        }
        growthHUD.isHidden = true
    }

    private static let playerNodeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private static let waterTexture: SKTexture = {
        let size = CGSize(width: 2, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { rendererContext in
            let colors = [
                UIColor(red: 0.33, green: 0.76, blue: 0.80, alpha: 1).cgColor,
                UIColor(red: 0.12, green: 0.48, blue: 0.58, alpha: 1).cgColor,
                UIColor(red: 0.035, green: 0.29, blue: 0.39, alpha: 1).cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.48, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                rendererContext.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        return SKTexture(image: image)
    }()

    private func resizeBackground(to viewport: CGSize) {
        backgroundSize = viewport
        water.size = viewport
        water.position = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        surfaceGlow.path = CGPath(roundedRect: CGRect(x: 0, y: viewport.height * 0.68, width: viewport.width, height: viewport.height * 0.36), cornerWidth: 24, cornerHeight: 24, transform: nil)
        surfaceGlow.fillColor = UIColor(red: 0.78, green: 0.92, blue: 0.84, alpha: 0.2)
        surfaceGlow.strokeColor = .clear
        surfaceGlow.zPosition = -90
        if surfaceGlow.parent == nil { addChild(surfaceGlow) }
        let floorPath = CGMutablePath()
        floorPath.move(to: .zero)
        floorPath.addLine(to: CGPoint(x: viewport.width, y: 0))
        floorPath.addLine(to: CGPoint(x: viewport.width, y: viewport.height * 0.13))
        floorPath.addCurve(to: CGPoint(x: 0, y: viewport.height * 0.1), control1: CGPoint(x: viewport.width * 0.72, y: viewport.height * 0.22), control2: CGPoint(x: viewport.width * 0.3, y: viewport.height * 0.04))
        floorPath.closeSubpath()
        seaFloor.path = floorPath
        seaFloor.fillColor = UIColor(red: 0.06, green: 0.32, blue: 0.35, alpha: 0.9)
        seaFloor.strokeColor = UIColor(red: 0.39, green: 0.68, blue: 0.57, alpha: 0.75)
        seaFloor.lineWidth = 2
        seaFloor.zPosition = -45
        if seaFloor.parent == nil { addChild(seaFloor) }
        let seaweedPath = CGMutablePath()
        for index in 0..<9 {
            let x = CGFloat(index + 1) * viewport.width / 10
            let height = CGFloat(38 + (index * 29) % 72)
            seaweedPath.move(to: CGPoint(x: x, y: viewport.height * 0.09))
            seaweedPath.addCurve(to: CGPoint(x: x + (index.isMultiple(of: 2) ? 14 : -14), y: viewport.height * 0.09 + height), control1: CGPoint(x: x - 22, y: viewport.height * 0.09 + height * 0.28), control2: CGPoint(x: x + 24, y: viewport.height * 0.09 + height * 0.72))
        }
        seaweed.path = seaweedPath
        seaweed.strokeColor = UIColor(red: 0.19, green: 0.53, blue: 0.34, alpha: 0.86)
        seaweed.lineWidth = 5
        seaweed.lineCap = .round
        seaweed.zPosition = -40
        if seaweed.parent == nil { addChild(seaweed) }
        for (index, ray) in lightRays.enumerated() {
            let x = viewport.width * CGFloat(index + 1) / CGFloat(lightRays.count + 1)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - 36, y: viewport.height))
            path.addLine(to: CGPoint(x: x + 36, y: viewport.height))
            path.addLine(to: CGPoint(x: x + 175, y: viewport.height * 0.36))
            path.addLine(to: CGPoint(x: x + 100, y: viewport.height * 0.36))
            path.closeSubpath()
            ray.path = path
            ray.position = .zero
        }
        for (index, bubble) in bubbleNodes.enumerated() {
            bubble.position = CGPoint(x: CGFloat((index * 137 + 59) % 997) / 997 * viewport.width, y: CGFloat((index * 223 + 47) % 997) / 997 * viewport.height)
        }
    }

    private func configureGrowthHUD() {
        growthPlate.path = CGPath(roundedRect: CGRect(x: -54, y: -16, width: 108, height: 32), cornerWidth: 12, cornerHeight: 12, transform: nil)
        growthPlate.fillColor = UIColor(red: 0.035, green: 0.20, blue: 0.29, alpha: 0.62)
        growthPlate.strokeColor = UIColor.white.withAlphaComponent(0.46)
        growthPlate.lineWidth = 0.8
        growthHUD.addChild(growthPlate)
        growthText.fontSize = 9
        growthText.fontColor = .white.withAlphaComponent(0.94)
        growthText.verticalAlignmentMode = .center
        growthText.position = CGPoint(x: 0, y: 7)
        growthHUD.addChild(growthText)
        growthTrack.path = CGPath(roundedRect: CGRect(x: -47, y: -10.5, width: 94, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
        growthTrack.fillColor = UIColor.white.withAlphaComponent(0.25)
        growthTrack.strokeColor = .clear
        growthHUD.addChild(growthTrack)
        growthFill.fillColor = UIColor.systemYellow
        growthFill.strokeColor = .clear
        growthHUD.addChild(growthFill)
        growthHUD.zPosition = 25
        addChild(growthHUD)
    }

    private func configureBubbles() {
        for index in 0..<26 {
            let radius = CGFloat(index % 3 + 2)
            let bubble = SKShapeNode(circleOfRadius: radius)
            bubble.fillColor = .white.withAlphaComponent(0.05)
            bubble.strokeColor = .white.withAlphaComponent(0.24)
            bubble.lineWidth = 1
            bubble.zPosition = -70
            addChild(bubble)
            let duration = TimeInterval(6 + index % 6)
            bubble.run(.repeatForever(.sequence([
                .moveBy(x: CGFloat(index % 2 == 0 ? 9 : -9), y: 48, duration: duration),
                .moveTo(y: 0, duration: 0)
            ])))
            bubbleNodes.append(bubble)
        }
    }

    private func configureLightRays() {
        for _ in 0..<5 {
            let ray = SKShapeNode()
            ray.fillColor = UIColor(red: 0.86, green: 0.95, blue: 0.81, alpha: 0.07)
            ray.strokeColor = .clear
            ray.zPosition = -80
            addChild(ray)
            ray.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.035, duration: 2.2),
                .fadeAlpha(to: 0.11, duration: 2.2)
            ])))
            lightRays.append(ray)
        }
    }

    private func makeFishNode() -> FishRenderNode {
        let node = FishRenderNode()
        node.playerHalo.isHidden = true
        node.powerUpHalo.isHidden = true
        return node
    }

    private func updateFishNode(_ node: FishRenderNode, position: CGPoint, camera: CGPoint, radius: CGFloat, direction: CGVector, species: FishSpecies, level: Int, time: CGFloat, isPlayer: Bool) {
        node.position = screenPoint(position, camera: camera, viewport: size)
        let angle = atan2(-direction.dy, direction.dx)
        node.art.zRotation = angle + (species.spriteFacesRight ? 0 : .pi)
        if let texture = Self.fishTextures[species] {
            if node.renderedSpecies != species {
                node.sprite.texture = texture
                node.renderedSpecies = species
            }
            node.sprite.size = CGSize(width: radius * 3.3, height: radius * 2.96)
            node.sprite.isHidden = false
            node.emoji.isHidden = true
        } else {
            node.sprite.isHidden = true
            node.emoji.isHidden = false
            if node.renderedSpecies != species {
                node.emoji.text = species == .shrimp ? "🦐" : "🐙"
                node.renderedSpecies = species
            }
            node.emoji.fontSize = radius * 2.1
        }
        node.levelLabel.isHidden = false
        node.levelPlate.isHidden = false
        let levelChanged = node.renderedLevel != level
        if levelChanged {
            node.levelLabel.text = "Lv.\(level)"
            node.renderedLevel = level
        }
        node.levelLabel.fontSize = max(10, min(15, radius * 0.46))
        if node.renderedRadius != radius || levelChanged {
            let plateWidth = max(38, CGFloat(level.description.count + 3) * node.levelLabel.fontSize * 0.58)
            node.levelPlate.path = CGPath(roundedRect: CGRect(x: -plateWidth / 2, y: -9.5, width: plateWidth, height: 19), cornerWidth: 9, cornerHeight: 9, transform: nil)
            node.playerHalo.path = CGPath(ellipseIn: CGRect(x: -radius * 1.82, y: -radius * 1.35, width: radius * 3.64, height: radius * 2.7), transform: nil)
            node.renderedRadius = radius
        }
        node.levelPlate.position = CGPoint(x: 0, y: radius * 1.35 + 10)
        node.levelLabel.position = .zero
        node.levelPlate.fillColor = isPlayer ? UIColor(red: 0.96, green: 0.38, blue: 0.18, alpha: 1) : UIColor(red: 0.04, green: 0.25, blue: 0.32, alpha: 0.84)
        node.playerHalo.isHidden = !isPlayer
        node.zPosition = isPlayer ? 20 : 10
        let margin = radius * 3
        node.isHidden = !isPlayer && (node.position.x < -margin || node.position.x > size.width + margin || node.position.y < -margin || node.position.y > size.height + margin)
        if node.art.action(forKey: "swim") == nil {
            node.art.run(.repeatForever(.sequence([
                .scaleY(to: 0.97, duration: 0.18),
                .scaleY(to: 1.03, duration: 0.18)
            ])), withKey: "swim")
        }
        node.art.xScale = 1 + sin(time * 8 + position.x * 0.02) * 0.012
    }

    private func makeMineNode() -> SKNode {
        let node = SKNode()
        let halo = SKShapeNode(circleOfRadius: 19)
        halo.fillColor = UIColor.systemOrange.withAlphaComponent(0.2)
        halo.strokeColor = UIColor.systemOrange.withAlphaComponent(0.78)
        halo.lineWidth = 2
        node.addChild(halo)
        let symbol = SKLabelNode(fontNamed: "AppleColorEmoji")
        symbol.text = "🦔"
        symbol.fontSize = 26
        symbol.verticalAlignmentMode = .center
        node.addChild(symbol)
        node.zPosition = 14
        return node
    }

    private func updateGrowthHUD(position: CGPoint, radius: CGFloat, level: Int, score: Int, scorePerLevel: Int) {
        let levelScore = score % scorePerLevel
        let progress = CGFloat(levelScore) / CGFloat(scorePerLevel)
        let status = "Lv.\(level) · 还差\(scorePerLevel - levelScore)分"
        if renderedGrowthText != status {
            growthText.text = status
            renderedGrowthText = status
        }
        growthHUD.position = CGPoint(x: position.x, y: position.y + radius * 1.55 + 32)
        if renderedGrowthProgress != progress {
            growthFill.path = progress > 0 ? CGPath(roundedRect: CGRect(x: -47, y: -10.5, width: 94 * progress, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil) : nil
            renderedGrowthProgress = progress
        }
    }

    private func screenPoint(_ worldPoint: CGPoint, camera: CGPoint, viewport: CGSize) -> CGPoint {
        CGPoint(x: worldPoint.x - camera.x, y: viewport.height - (worldPoint.y - camera.y))
    }

    private static func powerUpColor(_ kind: FishPowerUpKind) -> UIColor {
        switch kind {
        case .speed: .systemOrange
        case .shield: .systemTeal
        case .magnet: .systemGreen
        }
    }
}

struct FishGameScreen: View {
    private static let maximumPlayerRadius: CGFloat = 40
    private static let maximumThreatFishRadius: CGFloat = 55
    private static let scorePerLevel = 91

    @ObservedObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundMusic = FishGameBackgroundMusic()
    @State private var renderingScene = FishRenderScene(size: CGSize(width: 1024, height: 768))
    @State private var phase: FishGamePhase = .intro
    @State private var showingResult = false
    @State private var showingTicketPractice = false
    @State private var resultLevel = 1
    @State private var unityRuntimeState: UnityFishGameRuntimeState = .waiting
    @State private var fishes: [OceanFish] = []
    @State private var powerUps: [FishPowerUp] = []
    @State private var seaMines: [SeaMine] = []
    @State private var playerPosition = CGPoint(x: 900, y: 700)
    @State private var cameraPosition = CGPoint(x: 388, y: 316)
    @State private var viewportSize = CGSize(width: 1024, height: 768)
    @State private var playerDirection = CGVector(dx: 1, dy: 0)
    @State private var movementTargetInWorld: CGPoint?
    @State private var isBoosting = false
    @State private var boostIntensity: CGFloat = 0
    @State private var score = 0
    @State private var eatenCount = 0
    @State private var lifetimeFishEaten = 0
    @State private var lifetimeFishBestLevel = 1
    @State private var lifetimeBestRunFishEaten = 0
    @State private var isTemporaryTrialRun = false
    @State private var activeDifficulty: FishGameDifficulty = .standard
    @State private var unlockedFishSkins: Set<FishSpecies> = [.clownfish]
    @State private var selectedFishSkin: FishSpecies = .clownfish
    @State private var inspectedLockedSkin: FishSpecies?
    @State private var skinUnlockNotice: String?
    @State private var skinUnlockNoticeRemaining: CGFloat = 0
    @State private var lastFrame = Date()
    @State private var oceanTime: CGFloat = 0
    @State private var fishSchoolTimer: CGFloat = 6
    @State private var fishSchoolWave = 0
    @State private var fishSchoolNoticeRemaining: CGFloat = 0
    @State private var highestLevelReached = 1
    @State private var speedPowerUpRemaining: CGFloat = 0
    @State private var shieldPowerUpRemaining: CGFloat = 0
    @State private var shieldGraceRemaining: CGFloat = 0
    @State private var magnetPowerUpRemaining: CGFloat = 0
    @State private var hazardSlowRemaining: CGFloat = 0
    @State private var powerUpSpawnTimer: CGFloat = 9
    @State private var seaMineSpawnTimer: CGFloat = 17
    @State private var powerUpNotice: String?
    @State private var powerUpNoticeRemaining: CGFloat = 0

    private var playerRadius: CGFloat { min(Self.maximumPlayerRadius, 15 + CGFloat(score) * 0.055) }
    private var level: Int { max(1, score / Self.scorePerLevel + 1) }
    private var nearestThreat: OceanFish? {
        fishes
            .filter { $0.isHuntingPlayer && ($0.chaseWindup > 0 || $0.chaseRemaining > 0) && level(for: $0) > level }
            .min { distance($0.position, playerPosition) < distance($1.position, playerPosition) }
    }
    private var threatIsNear: Bool {
        guard let nearestThreat else { return false }
        return distance(nearestThreat.position, playerPosition) < 210
    }
    private var activePowerUpLabel: String? {
        if shieldPowerUpRemaining > 0 { return "🫧 护盾 \(Int(ceil(shieldPowerUpRemaining))) 秒" }
        if magnetPowerUpRemaining > 0 { return "🧲 吸鱼 \(Int(ceil(magnetPowerUpRemaining))) 秒" }
        if speedPowerUpRemaining > 0 { return "⚡ 加速 \(Int(ceil(speedPowerUpRemaining))) 秒" }
        if hazardSlowRemaining > 0 { return "🌀 减速 \(Int(ceil(hazardSlowRemaining))) 秒" }
        return nil
    }

    var body: some View {
        ZStack {
            if phase == .playing && unityRuntimeState != .unavailable {
                UnityFishGameRuntimeView(
                    onAvailabilityChanged: { available in
                        unityRuntimeState = available ? .active : .unavailable
                    },
                    onFinish: { finalScore, finalLevel, totalEaten in
                        score = max(0, finalScore)
                        eatenCount = max(0, totalEaten)
                        if !isTemporaryTrialRun {
                            lifetimeFishEaten += eatenCount
                            lifetimeFishBestLevel = max(lifetimeFishBestLevel, finalLevel)
                            lifetimeBestRunFishEaten = max(lifetimeBestRunFishEaten, eatenCount)
                            unlockEligibleFishSkins()
                        }
                        updateLevelUnlocks()
                        saveFishSkinProgress()
                        unityRuntimeState = .finished
                        returnToIntro()
                        resultLevel = max(1, finalLevel)
                        showingResult = true
                    }
                )
                .ignoresSafeArea()
            } else {
                StorybookBackground()
                if phase == .intro {
                    intro
                } else {
                    gameBoard
                }
            }
            if showingResult {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                resultCard
                    .padding(24)
            }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(phase == .playing)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .playing && scenePhase == .active {
                backgroundMusic.resume()
            } else {
                backgroundMusic.pause()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && phase == .playing {
                backgroundMusic.resume()
            } else {
                backgroundMusic.pause()
            }
        }
        .onDisappear {
            backgroundMusic.stop()
        }
        .onAppear {
            app.refreshSnakeRewardStatus()
            loadFishSkinProgress()
        }
        .onChange(of: app.currentUser.id) { _, _ in loadFishSkinProgress() }
        .fullScreenCover(isPresented: $showingTicketPractice, onDismiss: {
            app.refreshSnakeRewardStatus()
        }) {
            Group {
                if app.fishTicketSettings.questionType == .alphabet {
                    AlphabetModuleScreen(
                        app: app,
                        snakeTicketPractice: true,
                        ticketOptionDisplay: app.fishTicketSettings.alphabetOptionDisplay,
                        onSnakeTicketEarned: { showingTicketPractice = false }
                    )
                } else if app.fishTicketSettings.questionType == .alphabetDictation {
                    FishAlphabetDictationScreen(
                        app: app,
                        letterForm: app.fishTicketSettings.alphabetOptionDisplay,
                        onTicketEarned: { showingTicketPractice = false }
                    )
                } else if app.fishTicketSettings.questionType == .humanDictation {
                    FishHumanDictationTicketPracticeScreen(
                        app: app,
                        worksheetID: app.fishTicketSettings.humanDictationWorksheetID,
                        onTicketEarned: { showingTicketPractice = false }
                    )
                } else if app.fishTicketSettings.questionType == .englishWordDictation {
                    FishEnglishWordDictationTicketPracticeScreen(
                        app: app,
                        worksheetID: app.fishTicketSettings.englishWordWorksheetID,
                        onTicketEarned: { showingTicketPractice = false }
                    )
                } else {
                    FishPinyinTicketPracticeScreen(
                        app: app,
                        type: app.fishTicketSettings.questionType,
                        items: app.fishTicketSettings.items(for: app.fishTicketSettings.questionType),
                        onTicketEarned: { showingTicketPractice = false }
                    )
                }
            }
        }
        .alert(item: $inspectedLockedSkin) { skin in
            Alert(
                title: Text("\(skin.skinName) · 解锁条件"),
                message: Text(skinUnlockDetails(for: skin)),
                dismissButton: .default(Text("知道啦"))
            )
        }
        .task(id: phase == .playing && unityRuntimeState == .unavailable) {
            guard phase == .playing && unityRuntimeState == .unavailable else { return }
            lastFrame = Date()
            while !Task.isCancelled && phase == .playing && unityRuntimeState == .unavailable {
                try? await Task.sleep(nanoseconds: 16_666_667)
                guard phase == .playing else { continue }
                let now = Date()
                let dt = min(CGFloat(now.timeIntervalSince(lastFrame)), 0.06)
                lastFrame = now
                updateWorld(deltaTime: dt)
            }
        }
    }

    private var intro: some View {
        ScrollView {
        VStack(spacing: 16) {
            HStack {
                closeButton
                Spacer()
                Text("海底大冒险")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                Spacer()
                closeButton.opacity(0)
            }
            ZStack {
                Circle().fill(KidsTheme.blue.opacity(0.18)).frame(width: 170, height: 170)
                if let sprite = FishModelPreviewCatalog.images[selectedFishSkin.canonicalSkin] {
                    Image(uiImage: sprite)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 120)
                } else {
                    Text("🐠").font(.system(size: 92))
                }
                Text("🐟").font(.system(size: 38)).offset(x: 85, y: 44)
            }
            VStack(spacing: 9) {
                Text("从一条小鱼开始")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                Text("拖动屏幕改变方向，吃掉不比你大的鱼。\n升级可解锁加速、护盾和吸鱼；Lv.3 后还要躲开海胆！")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .foregroundStyle(KidsTheme.muted)
                Text("升级必解锁新道具：Lv.2 加速、Lv.3 护盾、Lv.4 吸鱼。留心躲开海胆障碍。")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KidsTheme.blue)
            }
            ticketBalanceCard
            fishSkinPicker
            if app.snakeRewardStatus.ticketCount < app.fishTicketSettings.ticketsPerGame {
                Label("还差 \(app.fishTicketSettings.ticketsPerGame - app.snakeRewardStatus.ticketCount) 张游戏券就能开始", systemImage: "ticket.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
            }
            if app.fishTicketSettings.ticketsPerGame > 0 {
                Text(app.fishTicketSettings.practiceHint)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KidsTheme.muted)
            }
            Button(action: startGame) {
                Label(app.fishTicketSettings.ticketsPerGame == 0 ? "开始探险" : "使用 \(app.fishTicketSettings.ticketsPerGame) 张券，开始探险", systemImage: "water.waves")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 34)
                    .frame(height: 56)
                    .background(KidsTheme.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(app.snakeRewardStatus.ticketCount < app.fishTicketSettings.ticketsPerGame)
            .opacity(app.snakeRewardStatus.ticketCount >= app.fishTicketSettings.ticketsPerGame ? 1 : 0.5)
            if app.fishTicketSettings.allowsTemporaryTrial {
                Button(action: startTemporaryTrial) {
                    Label("快速进入", systemImage: "play.circle.fill")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(KidsTheme.blue)
                        .padding(.horizontal, 24)
                        .frame(height: 48)
                        .background(.white.opacity(0.88), in: Capsule())
                        .overlay(Capsule().stroke(KidsTheme.blue.opacity(0.24), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Button { showingTicketPractice = true } label: {
                Label("练习赢游戏券", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .padding(.horizontal, 22)
                    .frame(height: 48)
                    .background(KidsTheme.mint.opacity(0.72), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        }
    }

    private var ticketBalanceCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(KidsTheme.orange)
                .frame(width: 48, height: 48)
                .background(KidsTheme.yellow.opacity(0.35), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("当前游戏券")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KidsTheme.muted)
                Text("\(app.snakeRewardStatus.ticketCount) 张")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
            }
            Spacer(minLength: 8)
            Text(app.fishTicketSettings.ticketsPerGame == 0
                 ? "本局免费"
                 : "本局消耗 \(app.fishTicketSettings.ticketsPerGame) 张")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsTheme.blue)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 12)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(KidsTheme.blue.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var fishSkinPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("挑选你的 3D 小鱼")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                Spacer()
                Text("已解锁 \(FishSpecies.selectableSkins.filter { unlockedFishSkins.contains($0) }.count)/\(FishSpecies.selectableSkins.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(KidsTheme.muted)
            }
            Text("达到等级与吃鱼目标后解锁 · 点按锁定皮肤查看进度")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(FishSpecies.selectableSkins, id: \.self) { skin in
                        fishSkinCard(skin)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(11)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
    }

    private func fishSkinCard(_ skin: FishSpecies) -> some View {
        let isUnlocked = unlockedFishSkins.contains(skin)
        let isSelected = selectedFishSkin == skin
        return Button {
            guard isUnlocked else {
                inspectedLockedSkin = skin
                return
            }
            selectedFishSkin = skin
            saveFishSkinProgress()
        } label: {
            VStack(spacing: 3) {
                if let sprite = FishModelPreviewCatalog.images[skin] {
                    Image(uiImage: sprite)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 55)
                } else if skin == .shrimp || skin == .octopus {
                    Text(skin == .shrimp ? "🦐" : "🐙")
                        .font(.system(size: 31))
                        .frame(height: 40)
                } else {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(skin.color)
                        .frame(height: 40)
                }
                Text(skin.skinName)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .lineLimit(1)
                Text(isUnlocked ? (isSelected ? "已选中" : "点击选择") : (skin.unlockRule?.summary ?? "初始拥有"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isUnlocked ? KidsTheme.blue : KidsTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(height: 27)
                if !isUnlocked {
                    Text(skinUnlockProgress(for: skin))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(KidsTheme.blue)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .frame(height: 25)
                }
            }
            .frame(width: 140, height: 145)
            .padding(.horizontal, 4)
            .background(isSelected ? KidsTheme.yellow.opacity(0.24) : KidsTheme.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? KidsTheme.orange : .clear, lineWidth: 2.5)
            }
            .overlay(alignment: .topTrailing) {
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(KidsTheme.muted, in: Circle())
                        .offset(x: 2, y: -2)
                }
            }
            .opacity(isUnlocked ? 1 : 0.84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isUnlocked ? "\(skin.skinName)，\(isSelected ? "已选中" : "点击选择")" : "\(skin.skinName)，\(skinUnlockDetails(for: skin))")
    }

    private func skinUnlockProgress(for skin: FishSpecies) -> String {
        guard let rule = skin.unlockRule else { return "已拥有" }
        var parts = ["Lv.\(min(lifetimeFishBestLevel, rule.bestLevel))/\(rule.bestLevel)",
                     "累计 \(min(lifetimeFishEaten, rule.totalFish))/\(rule.totalFish) 条"]
        if rule.bestRunFish > 0 {
            parts.append("单局 \(min(lifetimeBestRunFishEaten, rule.bestRunFish))/\(rule.bestRunFish) 条")
        }
        return parts.joined(separator: " · ")
    }

    private func skinUnlockDetails(for skin: FishSpecies) -> String {
        guard let rule = skin.unlockRule else { return "初始皮肤，已经拥有。" }
        var details = "需同时达到：\n单局最高 Lv.\(rule.bestLevel)（当前 Lv.\(lifetimeFishBestLevel)）\n累计吃鱼 \(rule.totalFish) 条（当前 \(lifetimeFishEaten) 条）"
        if rule.bestRunFish > 0 {
            details += "\n单局吃鱼 \(rule.bestRunFish) 条（当前最高 \(lifetimeBestRunFishEaten) 条）"
        }
        return details
    }

    private var gameBoard: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                SpriteView(scene: renderingScene, preferredFramesPerSecond: 60)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            movementTargetInWorld = CGPoint(
                                x: value.location.x + cameraPosition.x,
                                y: value.location.y + cameraPosition.y
                            )
                        }
                )

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🌟 \(score)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text("等级 \(level) · 吃到 \(eatenCount) 条")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        if fishSchoolNoticeRemaining > 0 {
                            Text("🐟 第\(fishSchoolWave)波鱼群来了！有一条奖励鱼")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(KidsTheme.blue)
                        }
                        if let powerUpNotice, powerUpNoticeRemaining > 0 {
                            Text(powerUpNotice)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(KidsTheme.orange)
                        }
                        if let skinUnlockNotice, skinUnlockNoticeRemaining > 0 {
                            Text(skinUnlockNotice)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(KidsTheme.mint)
                        }
                        if let activePowerUpLabel {
                            Text(activePowerUpLabel)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(KidsTheme.ink)
                        }
                    }
                    Spacer()
                    Text("♾️ 不限时")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    closeButton
                }
                .foregroundStyle(KidsTheme.ink)
                .padding(.horizontal, 15)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .allowsHitTesting(true)

                if threatIsNear, let nearestThreat {
                    threatBanner(threat: nearestThreat, size: proxy.size)
                }


            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                viewportSize = proxy.size
                centerCameraOnPlayer()
                synchronizeRenderingScene()
            }
            .onChange(of: proxy.size) { _, newSize in
                viewportSize = newSize
                synchronizeRenderingScene()
            }
        }
        .ignoresSafeArea()
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            Text("🌊").font(.system(size: 52))
            Text("本次冒险结束啦！")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            Text("吃到 \(eatenCount) 条小鱼 · Lv.\(resultLevel)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
            Text("成长分数 \(score)")
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsTheme.orange)
            Button("知道啦") { showingResult = false }
                .buttonStyle(FishActionButtonStyle(color: KidsTheme.blue))
        }
        .padding(30)
        .frame(maxWidth: 440)
        .background(.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: KidsTheme.ink.opacity(0.12), radius: 24, y: 12)
        .accessibilityAddTraits(.isModal)
    }

    private var closeButton: some View {
        Button {
            if phase == .playing {
                returnToIntro()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(KidsTheme.ink)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.86), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭游戏")
    }

    private func threatBanner(threat: OceanFish, size: CGSize) -> some View {
        let dx = threat.position.x - playerPosition.x
        let dy = threat.position.y - playerPosition.y
        let direction = arrow(for: -dx, dy: -dy)
        return HStack(spacing: 8) {
            Text("❗").font(.system(size: 20))
            Text("大鱼靠近！往\(direction)方向躲")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(KidsTheme.red, in: Capsule())
        .position(x: size.width / 2, y: 90)
        .allowsHitTesting(false)
    }

    private func drawOcean(in context: GraphicsContext, size: CGSize) {
        var drawing = context
        let deepSea = Color(red: 0.035, green: 0.29, blue: 0.39)
        drawing.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.33, green: 0.76, blue: 0.80), Color(red: 0.12, green: 0.48, blue: 0.58), deepSea]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        // Sunlit surface and soft rays give the water depth without obscuring play.
        let surface = wavePath(width: size.width, baseY: 132, amplitude: 13, phase: 0.4 + oceanTime * 0.9, bottom: 210)
        drawing.fill(surface, with: .color(Color(red: 0.78, green: 0.92, blue: 0.84).opacity(0.72)))
        for beam in 0..<5 {
            let drift = sin(oceanTime * 0.28 + CGFloat(beam) * 1.3) * 18
            let left = CGFloat(beam) * size.width / 4.8 - 120 + drift
            var ray = Path()
            ray.move(to: CGPoint(x: left, y: 0))
            ray.addLine(to: CGPoint(x: left + 110, y: 0))
            ray.addLine(to: CGPoint(x: left + 390, y: size.height * 0.66))
            ray.addLine(to: CGPoint(x: left + 220, y: size.height * 0.66))
            ray.closeSubpath()
            let shimmer = 0.045 + sin(oceanTime * 0.7 + CGFloat(beam)) * 0.012
            drawing.fill(ray, with: .color(Color(red: 0.86, green: 0.95, blue: 0.81).opacity(shimmer)))
        }

        for layer in 0..<4 {
            let y = CGFloat(190 + layer * 118)
            let wave = wavePath(width: size.width, baseY: y, amplitude: CGFloat(13 + layer * 3), phase: CGFloat(layer) * 1.25 + oceanTime * (0.42 + CGFloat(layer) * 0.11), bottom: y + 86)
            let colors: [Color] = [Color(red: 0.50, green: 0.83, blue: 0.81), Color(red: 0.27, green: 0.68, blue: 0.70), Color(red: 0.12, green: 0.50, blue: 0.59), Color(red: 0.06, green: 0.37, blue: 0.47)]
            drawing.fill(wave, with: .color(colors[layer].opacity(0.16)))
        }

        drawSeaFloor(in: &drawing, size: size, time: oceanTime)
        let camera = cameraPosition
        for index in 0..<28 {
            let x = positiveRemainder(CGFloat((index * 137 + 59) % 1777) - camera.x * 0.12 + sin(oceanTime * 0.32 + CGFloat(index)) * 9, period: size.width)
            let y = positiveRemainder(CGFloat((index * 223 + 47) % 1377) - camera.y * 0.12 - oceanTime * CGFloat(7 + index % 5), period: size.height)
            guard x > -10, x < size.width + 10, y > -10, y < size.height + 10 else { continue }
            let r = CGFloat(index % 3 + 2)
            let bubble = Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2))
            drawing.stroke(bubble, with: .color(.white.opacity(0.19)), lineWidth: 1.5)
            drawing.fill(Path(ellipseIn: CGRect(x: x + r * 0.35, y: y + r * 0.3, width: r * 0.48, height: r * 0.48)), with: .color(.white.opacity(0.3)))
        }
        for fish in fishes {
            let point = CGPoint(x: fish.position.x - camera.x, y: fish.position.y - camera.y)
            guard point.x > -fish.radius * 3, point.x < size.width + fish.radius * 3,
                  point.y > -fish.radius * 3, point.y < size.height + fish.radius * 3 else { continue }
            let fishLevel = level(for: fish)
            drawFish(at: point, radius: fish.radius, species: fish.species, level: fishLevel, direction: fish.direction, isPlayer: false, time: oceanTime, in: &drawing)
        }
        for powerUp in powerUps {
            let point = CGPoint(x: powerUp.position.x - camera.x, y: powerUp.position.y - camera.y)
            guard point.x > -40, point.x < size.width + 40, point.y > -40, point.y < size.height + 40 else { continue }
            drawPowerUp(powerUp, at: point, time: oceanTime, in: &drawing)
        }
        for mine in seaMines {
            let point = CGPoint(x: mine.position.x - camera.x, y: mine.position.y - camera.y)
            guard point.x > -42, point.x < size.width + 42, point.y > -42, point.y < size.height + 42 else { continue }
            drawSeaMine(at: point, radius: mine.radius, time: oceanTime, in: &drawing)
        }
        let playerScreenPosition = CGPoint(x: playerPosition.x - camera.x, y: playerPosition.y - camera.y)
        drawFish(at: playerScreenPosition, radius: playerRadius, species: selectedFishSkin, level: level, direction: playerDirection, isPlayer: true, time: oceanTime, in: &drawing)

    }

    private func synchronizeRenderingScene() {
        renderingScene.synchronize(
            viewport: viewportSize,
            camera: cameraPosition,
            fishes: fishes.map { ($0, level(for: $0)) },
            powerUps: powerUps,
            seaMines: seaMines,
            playerPosition: playerPosition,
            playerRadius: playerRadius,
            playerDirection: playerDirection,
            playerSpecies: selectedFishSkin,
            playerLevel: level,
            score: score,
            scorePerLevel: Self.scorePerLevel,
            time: oceanTime,
            hasSpeedBoost: speedPowerUpRemaining > 0,
            hasShield: shieldPowerUpRemaining > 0,
            hasMagnet: magnetPowerUpRemaining > 0
        )
    }

    private func drawPlayerGrowthHUD(at point: CGPoint, radius: CGFloat, level: Int, score: Int, in context: inout GraphicsContext) {
        let panelWidth: CGFloat = 108
        let panelHeight: CGFloat = 32
        let panelX = point.x - panelWidth / 2
        let panelY = point.y - radius * 1.55 - panelHeight
        let panelRect = CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
        let panel = Path(roundedRect: panelRect, cornerRadius: 12)
        context.fill(panel, with: .color(Color(red: 0.035, green: 0.20, blue: 0.29).opacity(0.62)))
        context.stroke(panel, with: .color(.white.opacity(0.46)), lineWidth: 0.8)

        let levelScore = score % Self.scorePerLevel
        let progress = CGFloat(levelScore) / CGFloat(Self.scorePerLevel)
        let remainingScore = Self.scorePerLevel - levelScore
        let progressText = "还差\(remainingScore)分"

        let statusLabel = Text("Lv.\(level) · \(progressText)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.94))
        context.draw(statusLabel, at: CGPoint(x: point.x, y: panelY + 9))

        let barX = panelX + 7
        let barY = panelY + 18
        let barWidth: CGFloat = panelWidth - 14
        let barHeight: CGFloat = 5
        let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
        let barBackground = Path(roundedRect: barRect, cornerRadius: barHeight / 2)
        context.fill(barBackground, with: .color(.white.opacity(0.25)))

        let fillWidth = barWidth * progress
        if fillWidth > 0 {
            let fillRect = CGRect(x: barX, y: barY, width: fillWidth, height: barHeight)
            let progressBar = Path(roundedRect: fillRect, cornerRadius: barHeight / 2)
            context.fill(progressBar, with: .color(KidsTheme.yellow))
        }
    }

    private func drawPowerUp(_ powerUp: FishPowerUp, at point: CGPoint, time: CGFloat, in context: inout GraphicsContext) {
        let pulse = 1 + sin(time * 4 + point.x * 0.02) * 0.07
        let radius = powerUp.radius * pulse
        let glow = Path(ellipseIn: CGRect(x: point.x - radius * 1.55, y: point.y - radius * 1.55, width: radius * 3.1, height: radius * 3.1))
        context.fill(glow, with: .color(powerUp.kind.color.opacity(0.19)))
        let gem = Path(roundedRect: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2), cornerRadius: radius * 0.65)
        context.fill(gem, with: .radialGradient(
            Gradient(colors: [.white, powerUp.kind.color, powerUp.kind.color.opacity(0.72)]),
            center: CGPoint(x: point.x - radius * 0.3, y: point.y - radius * 0.35),
            startRadius: 0,
            endRadius: radius * 1.8
        ))
        context.stroke(gem, with: .color(.white.opacity(0.92)), lineWidth: 2.5)
        context.draw(Text(powerUp.kind.symbol).font(.system(size: radius * 1.15)), at: point)
        for sparkle in 0..<4 {
            let angle = time * 1.3 + CGFloat(sparkle) * (.pi / 2)
            let star = CGPoint(x: point.x + cos(angle) * radius * 1.55, y: point.y + sin(angle) * radius * 1.55)
            context.fill(Path(ellipseIn: CGRect(x: star.x - 2, y: star.y - 2, width: 4, height: 4)), with: .color(.white.opacity(0.9)))
        }
    }

    private func drawSeaMine(at point: CGPoint, radius: CGFloat, time: CGFloat, in context: inout GraphicsContext) {
        let pulse = 1 + sin(time * 3.2 + point.y * 0.02) * 0.05
        let r = radius * pulse
        let warning = Path(ellipseIn: CGRect(x: point.x - r * 1.55, y: point.y - r * 1.55, width: r * 3.1, height: r * 3.1))
        context.fill(warning, with: .color(KidsTheme.red.opacity(0.14)))
        for spike in 0..<10 {
            let angle = CGFloat(spike) * (.pi / 5) + time * 0.16
            var barb = Path()
            barb.move(to: CGPoint(x: point.x + cos(angle) * r * 0.62, y: point.y + sin(angle) * r * 0.62))
            barb.addLine(to: CGPoint(x: point.x + cos(angle) * r * 1.05, y: point.y + sin(angle) * r * 1.05))
            context.stroke(barb, with: .color(Color(red: 0.31, green: 0.17, blue: 0.39)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            let dot = CGPoint(x: point.x + cos(angle) * r * 1.04, y: point.y + sin(angle) * r * 1.04)
            context.fill(Path(ellipseIn: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)), with: .color(KidsTheme.orange))
        }
        let body = Path(ellipseIn: CGRect(x: point.x - r * 0.68, y: point.y - r * 0.68, width: r * 1.36, height: r * 1.36))
        context.fill(body, with: .radialGradient(Gradient(colors: [Color(red: 0.98, green: 0.49, blue: 0.38), Color(red: 0.62, green: 0.17, blue: 0.26)]), center: CGPoint(x: point.x - r * 0.2, y: point.y - r * 0.28), startRadius: 0, endRadius: r))
        context.stroke(body, with: .color(.white.opacity(0.9)), lineWidth: 2)
        context.draw(Text("!").font(.system(size: r * 1.05, weight: .black, design: .rounded)).foregroundColor(.white), at: point)
    }

    private func drawSeaFloor(in context: inout GraphicsContext, size: CGSize, time: CGFloat) {
        let floorY = size.height * 0.79
        context.fill(wavePath(width: size.width, baseY: floorY, amplitude: 17, phase: 2.1 + time * 0.24, bottom: size.height + 20), with: .color(Color(red: 0.79, green: 0.60, blue: 0.30)))
        context.fill(wavePath(width: size.width, baseY: floorY + 35, amplitude: 13, phase: 5.2 + time * 0.2, bottom: size.height + 20), with: .color(Color(red: 0.89, green: 0.70, blue: 0.37).opacity(0.9)))
        context.fill(wavePath(width: size.width, baseY: floorY + 75, amplitude: 10, phase: 1.1 + time * 0.17, bottom: size.height + 20), with: .color(Color(red: 0.94, green: 0.77, blue: 0.45)))

        for index in 0..<90 {
            let x = CGFloat((index * 83 + 17) % 1901) / 1901 * size.width
            let y = floorY + 34 + CGFloat((index * 47 + 19) % max(1, Int(size.height - floorY - 25)))
            let radius = CGFloat(index % 4 + 2)
            let pebble = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2.2, height: radius * 1.5))
            let pebbleColor: Color = [Color(red: 0.72, green: 0.42, blue: 0.24), Color(red: 0.98, green: 0.83, blue: 0.53), Color(red: 0.58, green: 0.54, blue: 0.32)][index % 3]
            context.fill(pebble, with: .color(pebbleColor.opacity(0.75)))
        }

        for stalk in 0..<9 {
            let x = CGFloat(stalk + 1) * size.width / 10
            let height = CGFloat(55 + (stalk * 31) % 105)
            let sway = sin(time * 0.8 + CGFloat(stalk) * 0.9) * 15
            var plant = Path()
            plant.move(to: CGPoint(x: x, y: floorY + 22))
            plant.addCurve(to: CGPoint(x: x + CGFloat(stalk % 2 == 0 ? 17 : -17) + sway, y: floorY - height), control1: CGPoint(x: x - 24 + sway * 0.25, y: floorY - height * 0.25), control2: CGPoint(x: x + 29 + sway * 0.7, y: floorY - height * 0.76))
            context.stroke(plant, with: .color(Color(red: 0.12, green: 0.42, blue: 0.31).opacity(0.78)), style: StrokeStyle(lineWidth: CGFloat(stalk % 3 + 4), lineCap: .round))
            for leaf in 0..<3 {
                let leafY = floorY - CGFloat(leaf + 1) * height / 3.4
                let side: CGFloat = (leaf + stalk).isMultiple(of: 2) ? 1 : -1
                var leafPath = Path()
                leafPath.move(to: CGPoint(x: x, y: leafY + 16))
                leafPath.addQuadCurve(to: CGPoint(x: x + side * 30, y: leafY - 8), control: CGPoint(x: x + side * 22, y: leafY - 18))
                leafPath.addQuadCurve(to: CGPoint(x: x, y: leafY + 16), control: CGPoint(x: x + side * 16, y: leafY + 1))
                context.fill(leafPath, with: .color(Color(red: 0.19, green: 0.53, blue: 0.34).opacity(0.88)))
            }
        }
    }

    private func wavePath(width: CGFloat, baseY: CGFloat, amplitude: CGFloat, phase: CGFloat, bottom: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseY + sin(phase) * amplitude))
        for x in stride(from: CGFloat(0), through: width, by: 14) {
            let y = baseY + sin(x * 0.009 + phase) * amplitude + sin(x * 0.021 + phase * 1.8) * amplitude * 0.28
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: bottom))
        path.addLine(to: CGPoint(x: 0, y: bottom))
        path.closeSubpath()
        return path
    }

    private func positiveRemainder(_ value: CGFloat, period: CGFloat) -> CGFloat {
        guard period > 0 else { return 0 }
        let remainder = value.truncatingRemainder(dividingBy: period)
        return remainder >= 0 ? remainder : remainder + period
    }

    private func drawFish(at point: CGPoint, radius: CGFloat, species: FishSpecies, level: Int, direction heading: CGVector, isPlayer: Bool, time: CGFloat, in context: inout GraphicsContext) {
        let facesLeft = heading.dx < 0
        let tiltAngle = atan2(heading.dy, max(abs(heading.dx), 0.0001)) * (facesLeft ? -1 : 1)
        if isPlayer {
            drawActivePowerUpEffects(at: point, radius: radius, time: time, in: &context)
        }
        if species == .shrimp {
            drawShrimp(at: point, radius: radius, direction: heading, level: level, isPlayer: isPlayer, time: time, in: &context)
            return
        }
        if species == .octopus {
            drawOctopus(at: point, radius: radius, direction: heading, level: level, isPlayer: isPlayer, time: time, in: &context)
            return
        }
        if let sprite = FishSpriteCatalog.sprites[species] {
            let flipHorizontally = facesLeft == species.spriteFacesRight
            drawFishSprite(sprite, at: point, radius: radius, level: level, tiltAngle: tiltAngle, flipHorizontally: flipHorizontally, isPlayer: isPlayer, in: &context)
            return
        }

        var fishBodyContext = context
        fishBodyContext.translateBy(x: point.x, y: point.y)
        fishBodyContext.rotate(by: Angle(radians: Double(tiltAngle)))
        fishBodyContext.scaleBy(x: facesLeft ? -1 : 1, y: 1)
        fishBodyContext.translateBy(x: -point.x, y: -point.y)
        let direction: CGFloat = 1
        let bodyColor = species.color
        let darkColor = bodyColor.opacity(0.68)
        let fishWidth = radius * (species == .shark ? 2.45 : 2.0)
        let fishHeight = radius * (species == .puffer ? 1.8 : 1.28)

        if isPlayer {
            let halo = Path(ellipseIn: CGRect(x: point.x - radius * 1.82, y: point.y - radius * 1.35, width: radius * 3.64, height: radius * 2.7))
            fishBodyContext.stroke(halo, with: .color(.white.opacity(0.85)), lineWidth: 3)
        }

        // A soft offset shadow separates the fish from the layered water.
        for layer in 0..<3 {
            let spread = CGFloat(layer) * radius * 0.08
            let shadow = Path(ellipseIn: CGRect(
                x: point.x - fishWidth * 0.42 - spread,
                y: point.y + radius * 0.28 + spread,
                width: fishWidth * 0.84 + spread * 2,
                height: fishHeight * 0.42 + spread
            ))
            fishBodyContext.fill(shadow, with: .color(Color(red: 0.015, green: 0.12, blue: 0.19).opacity(0.14 - Double(layer) * 0.035)))
        }

        var tail = Path()
        let tailWag = sin(time * 9 + point.x * 0.025) * radius * 0.14
        tail.move(to: CGPoint(x: point.x - direction * radius * 0.58, y: point.y))
        tail.addLine(to: CGPoint(x: point.x - direction * radius * 1.36 + tailWag, y: point.y - radius * 0.7))
        tail.addLine(to: CGPoint(x: point.x - direction * radius * 1.30 + tailWag, y: point.y + radius * 0.75))
        tail.closeSubpath()
        fishBodyContext.fill(tail, with: .linearGradient(
            Gradient(colors: [bodyColor.opacity(0.72), darkColor]),
            startPoint: CGPoint(x: point.x - direction * radius * 1.25, y: point.y - radius * 0.6),
            endPoint: CGPoint(x: point.x - direction * radius * 0.45, y: point.y + radius * 0.55)
        ))

        var dorsalFin = Path()
        dorsalFin.move(to: CGPoint(x: point.x - direction * radius * 0.36, y: point.y - radius * 0.34))
        dorsalFin.addQuadCurve(to: CGPoint(x: point.x + direction * radius * 0.35, y: point.y - radius * 0.34), control: CGPoint(x: point.x - direction * radius * 0.05, y: point.y - radius * 1.02))
        dorsalFin.addQuadCurve(to: CGPoint(x: point.x + direction * radius * 0.08, y: point.y - radius * 0.17), control: CGPoint(x: point.x + direction * radius * 0.08, y: point.y - radius * 0.35))
        dorsalFin.closeSubpath()
        fishBodyContext.fill(dorsalFin, with: .linearGradient(
            Gradient(colors: [bodyColor.opacity(0.85), darkColor]),
            startPoint: CGPoint(x: point.x, y: point.y - radius),
            endPoint: CGPoint(x: point.x, y: point.y - radius * 0.15)
        ))

        if species == .shark {
            var dorsal = Path()
            dorsal.move(to: CGPoint(x: point.x - radius * 0.1, y: point.y - radius * 0.42))
            dorsal.addLine(to: CGPoint(x: point.x + direction * radius * 0.18, y: point.y - radius * 1.05))
            dorsal.addLine(to: CGPoint(x: point.x + direction * radius * 0.54, y: point.y - radius * 0.46))
            dorsal.closeSubpath()
            fishBodyContext.fill(dorsal, with: .color(darkColor))
        }

        let body = Path(ellipseIn: CGRect(x: point.x - fishWidth / 2, y: point.y - fishHeight / 2, width: fishWidth, height: fishHeight))
        fishBodyContext.fill(body, with: .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.88), location: 0),
                .init(color: bodyColor.opacity(0.96), location: 0.42),
                .init(color: darkColor, location: 1)
            ]),
            center: CGPoint(x: point.x - direction * radius * 0.3, y: point.y - radius * 0.42),
            startRadius: 0,
            endRadius: radius * 2.25
        ))
        fishBodyContext.stroke(body, with: .color(Color(red: 1, green: 0.95, blue: 0.76).opacity(0.92)), lineWidth: max(1.5, radius * 0.09))

        let belly = Path(ellipseIn: CGRect(x: point.x - radius * 0.38, y: point.y + radius * 0.12, width: radius * 0.92, height: radius * 0.32))
        fishBodyContext.fill(belly, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.58), .white.opacity(0.08)]),
            startPoint: CGPoint(x: point.x, y: point.y + radius * 0.12),
            endPoint: CGPoint(x: point.x, y: point.y + radius * 0.46)
        ))

        switch species {
        case .clownfish, .screenshotClown:
            for stripe in [CGFloat(-0.28), CGFloat(0.28)] {
                let band = Path(roundedRect: CGRect(x: point.x + direction * radius * stripe - radius * 0.09, y: point.y - radius * 0.48, width: radius * 0.18, height: radius * 0.96), cornerRadius: radius * 0.08)
                fishBodyContext.fill(band, with: .color(.white.opacity(0.95)))
            }
        case .puffer, .tealPuffer:
            for spike in 0..<12 {
                let angle = CGFloat(spike) * (.pi / 6)
                let start = CGPoint(x: point.x + cos(angle) * radius * 0.72, y: point.y + sin(angle) * radius * 0.62)
                let tip = CGPoint(x: point.x + cos(angle) * radius * 1.02, y: point.y + sin(angle) * radius * 0.94)
                var path = Path()
                path.move(to: start)
                path.addLine(to: tip)
                fishBodyContext.stroke(path, with: .color(darkColor), style: StrokeStyle(lineWidth: max(1, radius * 0.08), lineCap: .round))
            }
            for dot in 0..<5 {
                let x = point.x - radius * 0.35 + CGFloat(dot % 3) * radius * 0.3
                let y = point.y + CGFloat(dot / 3) * radius * 0.26
                fishBodyContext.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 0.1, height: radius * 0.1)), with: .color(darkColor))
            }
        case .butterfly, .tang, .green, .blueMinnow, .stripedCoral:
            for stripe in 0..<3 {
                let x = point.x - radius * 0.25 + CGFloat(stripe) * radius * 0.27
                var line = Path()
                line.move(to: CGPoint(x: x, y: point.y - radius * 0.48))
                line.addQuadCurve(to: CGPoint(x: x + direction * radius * 0.08, y: point.y + radius * 0.48), control: CGPoint(x: x - direction * radius * 0.12, y: point.y))
                fishBodyContext.stroke(line, with: .color(species == .tang ? Color(red: 0.1, green: 0.33, blue: 0.67) : .white.opacity(0.85)), lineWidth: max(1.5, radius * 0.11))
            }
        case .shark, .reefShark:
            var fin = Path()
            fin.move(to: CGPoint(x: point.x - direction * radius * 0.08, y: point.y + radius * 0.38))
            fin.addLine(to: CGPoint(x: point.x + direction * radius * 0.17, y: point.y + radius * 0.76))
            fin.addLine(to: CGPoint(x: point.x + direction * radius * 0.45, y: point.y + radius * 0.42))
            fin.closeSubpath()
            fishBodyContext.fill(fin, with: .color(darkColor))
        case .angler:
            var lure = Path()
            lure.move(to: CGPoint(x: point.x + direction * radius * 0.2, y: point.y - radius * 0.48))
            lure.addQuadCurve(to: CGPoint(x: point.x + direction * radius * 0.52, y: point.y - radius * 1.05), control: CGPoint(x: point.x + direction * radius * 0.54, y: point.y - radius * 0.68))
            fishBodyContext.stroke(lure, with: .color(bodyColor.opacity(0.9)), lineWidth: max(1.5, radius * 0.08))
            fishBodyContext.fill(Path(ellipseIn: CGRect(x: point.x + direction * radius * 0.43, y: point.y - radius * 1.15, width: radius * 0.2, height: radius * 0.2)), with: .color(KidsTheme.yellow))
        case .redfin:
            var dorsalFin = Path()
            dorsalFin.move(to: CGPoint(x: point.x - direction * radius * 0.08, y: point.y - radius * 0.38))
            dorsalFin.addLine(to: CGPoint(x: point.x + direction * radius * 0.12, y: point.y - radius * 0.82))
            dorsalFin.addLine(to: CGPoint(x: point.x + direction * radius * 0.42, y: point.y - radius * 0.34))
            dorsalFin.closeSubpath()
            fishBodyContext.fill(dorsalFin, with: .color(darkColor))
        case .silverfish, .longfinFish, .goldenReference, .patternedReef, .rubyLionfish, .spottedPuffer, .azureAngelfish, .fangHunter, .grinningShark, .yellowTang, .iridescentShark:
            break
        case .shrimp, .octopus:
            break
        }

        // Pectoral fin and gill catch a little light to make the body feel rounded.
        var pectoralFin = Path()
        pectoralFin.move(to: CGPoint(x: point.x - direction * radius * 0.08, y: point.y + radius * 0.02))
        pectoralFin.addQuadCurve(to: CGPoint(x: point.x + direction * radius * 0.45, y: point.y + radius * 0.4), control: CGPoint(x: point.x + direction * radius * 0.42, y: point.y + radius * 0.06))
        pectoralFin.addQuadCurve(to: CGPoint(x: point.x + direction * radius * 0.12, y: point.y + radius * 0.08), control: CGPoint(x: point.x + direction * radius * 0.17, y: point.y + radius * 0.3))
        pectoralFin.closeSubpath()
        fishBodyContext.fill(pectoralFin, with: .linearGradient(
            Gradient(colors: [bodyColor.opacity(0.9), darkColor.opacity(0.88)]),
            startPoint: CGPoint(x: point.x, y: point.y),
            endPoint: CGPoint(x: point.x + direction * radius * 0.35, y: point.y + radius * 0.42)
        ))
        fishBodyContext.stroke(pectoralFin, with: .color(.white.opacity(0.36)), lineWidth: max(1, radius * 0.035))

        var gill = Path()
        gill.move(to: CGPoint(x: point.x - direction * radius * 0.16, y: point.y - radius * 0.3))
        gill.addQuadCurve(to: CGPoint(x: point.x - direction * radius * 0.18, y: point.y + radius * 0.22), control: CGPoint(x: point.x - direction * radius * 0.36, y: point.y - radius * 0.02))
        fishBodyContext.stroke(gill, with: .color(darkColor.opacity(0.62)), lineWidth: max(1, radius * 0.045))

        let shine = Path(ellipseIn: CGRect(x: point.x - direction * radius * 0.48, y: point.y - radius * 0.39, width: radius * 0.62, height: max(2, radius * 0.15)))
        fishBodyContext.fill(shine, with: .color(.white.opacity(0.42)))

        let eyeX = point.x + direction * radius * 0.43
        let eye = Path(ellipseIn: CGRect(x: eyeX - radius * 0.15, y: point.y - radius * 0.23, width: radius * 0.3, height: radius * 0.3))
        fishBodyContext.fill(eye, with: .color(.white))
        fishBodyContext.stroke(eye, with: .color(darkColor), lineWidth: max(1, radius * 0.045))
        fishBodyContext.fill(Path(ellipseIn: CGRect(x: eyeX + direction * radius * 0.035, y: point.y - radius * 0.16, width: max(2, radius * 0.13), height: max(2, radius * 0.13))), with: .color(KidsTheme.ink))

        let label = Text("Lv.\(level)")
            .font(.system(size: max(10, min(15, radius * 0.46)), weight: .black, design: .rounded))
            .foregroundColor(.white)
        let labelWidth = max(38, CGFloat(level.description.count + 3) * max(10, min(15, radius * 0.46)) * 0.58)
        let labelRect = CGRect(x: point.x - labelWidth / 2, y: point.y - radius * 0.88 - 22, width: labelWidth, height: 19)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 9), with: .color(isPlayer ? Color(red: 0.96, green: 0.38, blue: 0.18) : Color(red: 0.04, green: 0.25, blue: 0.32).opacity(0.84)))
        context.draw(label, at: CGPoint(x: point.x, y: labelRect.midY + 0.5))
    }

    private func drawShrimp(at point: CGPoint, radius: CGFloat, direction heading: CGVector, level: Int, isPlayer: Bool, time: CGFloat, in context: inout GraphicsContext) {
        let length = max(0.001, hypot(heading.dx, heading.dy))
        let angle = atan2(heading.dy / length, heading.dx / length)
        var shrimpContext = context
        shrimpContext.translateBy(x: point.x, y: point.y)
        shrimpContext.rotate(by: Angle(radians: Double(angle)))
        shrimpContext.translateBy(x: -point.x, y: -point.y)
        let coral = Color(red: 0.98, green: 0.43, blue: 0.53)
        let dark = Color(red: 0.72, green: 0.24, blue: 0.37)

        for segment in 0..<5 {
            let progress = CGFloat(segment)
            let x = point.x - radius * (0.54 + progress * 0.2)
            let y = point.y + sin(time * 6 + progress * 0.65) * radius * 0.05
            let segmentSize = radius * (0.63 - progress * 0.055)
            let shell = Path(ellipseIn: CGRect(x: x - segmentSize * 0.35, y: y - segmentSize * 0.34, width: segmentSize * 0.7, height: segmentSize * 0.68))
            shrimpContext.fill(shell, with: .linearGradient(Gradient(colors: [.white.opacity(0.85), coral, dark]), startPoint: CGPoint(x: x, y: y - segmentSize * 0.35), endPoint: CGPoint(x: x, y: y + segmentSize * 0.35)))
            shrimpContext.stroke(shell, with: .color(.white.opacity(0.8)), lineWidth: max(1, radius * 0.045))
            var swimmeret = Path()
            swimmeret.move(to: CGPoint(x: x, y: y + segmentSize * 0.2))
            swimmeret.addQuadCurve(to: CGPoint(x: x - radius * 0.12, y: y + radius * 0.42), control: CGPoint(x: x + radius * 0.02, y: y + radius * 0.25))
            shrimpContext.stroke(swimmeret, with: .color(dark), style: StrokeStyle(lineWidth: max(1, radius * 0.055), lineCap: .round))
        }
        var tail = Path()
        tail.move(to: CGPoint(x: point.x - radius * 1.37, y: point.y - radius * 0.12))
        tail.addQuadCurve(to: CGPoint(x: point.x - radius * 1.62, y: point.y - radius * 0.3), control: CGPoint(x: point.x - radius * 1.5, y: point.y - radius * 0.12))
        tail.addQuadCurve(to: CGPoint(x: point.x - radius * 1.4, y: point.y + radius * 0.2), control: CGPoint(x: point.x - radius * 1.48, y: point.y + radius * 0.16))
        shrimpContext.fill(tail, with: .color(dark))
        let head = Path(ellipseIn: CGRect(x: point.x + radius * 0.14, y: point.y - radius * 0.38, width: radius * 0.72, height: radius * 0.72))
        shrimpContext.fill(head, with: .linearGradient(Gradient(colors: [.white.opacity(0.88), coral, dark]), startPoint: CGPoint(x: point.x + radius * 0.35, y: point.y - radius * 0.38), endPoint: CGPoint(x: point.x + radius * 0.55, y: point.y + radius * 0.38)))
        shrimpContext.stroke(head, with: .color(.white.opacity(0.86)), lineWidth: max(1, radius * 0.05))
        for whisker in [-1.0, 1.0] {
            var antenna = Path()
            antenna.move(to: CGPoint(x: point.x + radius * 0.72, y: point.y - radius * 0.23))
            antenna.addQuadCurve(to: CGPoint(x: point.x + radius * 1.16, y: point.y + CGFloat(whisker) * radius * 0.34), control: CGPoint(x: point.x + radius * 1.12, y: point.y - radius * 0.35 * CGFloat(whisker)))
            shrimpContext.stroke(antenna, with: .color(dark), style: StrokeStyle(lineWidth: max(1, radius * 0.045), lineCap: .round))
        }
        shrimpContext.fill(Path(ellipseIn: CGRect(x: point.x + radius * 0.58, y: point.y - radius * 0.18, width: max(2, radius * 0.13), height: max(2, radius * 0.13))), with: .color(KidsTheme.ink))
        drawCreatureLevel(level, at: point, radius: radius, isPlayer: isPlayer, in: &context)
    }

    private func drawOctopus(at point: CGPoint, radius: CGFloat, direction heading: CGVector, level: Int, isPlayer: Bool, time: CGFloat, in context: inout GraphicsContext) {
        let length = max(0.001, hypot(heading.dx, heading.dy))
        let angle = atan2(heading.dy / length, heading.dx / length)
        var octopusContext = context
        octopusContext.translateBy(x: point.x, y: point.y)
        octopusContext.rotate(by: Angle(radians: Double(angle)))
        octopusContext.translateBy(x: -point.x, y: -point.y)
        let mantle = Color(red: 0.78, green: 0.45, blue: 0.63)
        let shadow = Color(red: 0.52, green: 0.25, blue: 0.47)
        for arm in 0..<8 {
            let normalized = CGFloat(arm) / 7
            let startX = point.x - radius * 0.62 + normalized * radius * 1.24
            let sway = sin(time * 5 + CGFloat(arm) * 0.8) * radius * 0.13
            var tentacle = Path()
            tentacle.move(to: CGPoint(x: startX, y: point.y + radius * 0.28))
            tentacle.addCurve(to: CGPoint(x: startX - radius * 0.14 + sway, y: point.y + radius * (0.95 + (arm % 2 == 0 ? 0.08 : 0))), control1: CGPoint(x: startX - radius * 0.24, y: point.y + radius * 0.52), control2: CGPoint(x: startX + radius * 0.3 + sway, y: point.y + radius * 0.68))
            octopusContext.stroke(tentacle, with: .color(mantle), style: StrokeStyle(lineWidth: max(2, radius * 0.19), lineCap: .round))
            octopusContext.stroke(tentacle, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: max(1, radius * 0.045), lineCap: .round))
        }
        let head = Path(ellipseIn: CGRect(x: point.x - radius * 0.78, y: point.y - radius * 0.88, width: radius * 1.56, height: radius * 1.4))
        octopusContext.fill(head, with: .linearGradient(Gradient(colors: [.white.opacity(0.8), mantle, shadow]), startPoint: CGPoint(x: point.x - radius * 0.3, y: point.y - radius * 0.85), endPoint: CGPoint(x: point.x + radius * 0.3, y: point.y + radius * 0.55)))
        octopusContext.stroke(head, with: .color(.white.opacity(0.82)), lineWidth: max(1.5, radius * 0.07))
        for eyeOffset in [-0.28, 0.28] {
            let eye = CGRect(x: point.x + radius * CGFloat(eyeOffset) - radius * 0.12, y: point.y - radius * 0.13, width: radius * 0.24, height: radius * 0.28)
            octopusContext.fill(Path(ellipseIn: eye), with: .color(.white))
            octopusContext.fill(Path(ellipseIn: eye.insetBy(dx: radius * 0.07, dy: radius * 0.05)), with: .color(KidsTheme.ink))
        }
        drawCreatureLevel(level, at: point, radius: radius, isPlayer: isPlayer, in: &context)
    }

    private func drawCreatureLevel(_ level: Int, at point: CGPoint, radius: CGFloat, isPlayer: Bool, in context: inout GraphicsContext) {
        let label = Text("Lv.\(level)").font(.system(size: max(10, min(15, radius * 0.46)), weight: .black, design: .rounded)).foregroundColor(.white)
        let width = max(38, CGFloat(level.description.count + 3) * max(10, min(15, radius * 0.46)) * 0.58)
        let rect = CGRect(x: point.x - width / 2, y: point.y - radius * 0.88 - 22, width: width, height: 19)
        context.fill(Path(roundedRect: rect, cornerRadius: 9), with: .color(isPlayer ? Color(red: 0.96, green: 0.38, blue: 0.18) : Color(red: 0.04, green: 0.25, blue: 0.32).opacity(0.84)))
        context.draw(label, at: CGPoint(x: point.x, y: rect.midY + 0.5))
    }

    private func drawActivePowerUpEffects(at point: CGPoint, radius: CGFloat, time: CGFloat, in context: inout GraphicsContext) {
        if shieldPowerUpRemaining > 0 {
            let shieldRadius = radius * 2.05
            let bubble = Path(ellipseIn: CGRect(x: point.x - shieldRadius, y: point.y - shieldRadius * 0.78, width: shieldRadius * 2, height: shieldRadius * 1.56))
            context.fill(bubble, with: .color(KidsTheme.blue.opacity(0.13)))
            context.stroke(bubble, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 3, dash: [9, 5], dashPhase: time * 9))
            context.stroke(bubble, with: .color(KidsTheme.blue.opacity(0.82)), lineWidth: 1.5)
            for bubbleIndex in 0..<5 {
                let angle = time * 0.9 + CGFloat(bubbleIndex) * (.pi * 2 / 5)
                let center = CGPoint(x: point.x + cos(angle) * shieldRadius, y: point.y + sin(angle) * shieldRadius * 0.78)
                let size = CGFloat(4 + bubbleIndex % 2 * 2)
                let glint = Path(ellipseIn: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))
                context.fill(glint, with: .color(.white.opacity(0.9)))
            }
        }

        if speedPowerUpRemaining > 0 {
            let headingLength = max(1, hypot(playerDirection.dx, playerDirection.dy))
            let backward = CGVector(dx: -playerDirection.dx / headingLength, dy: -playerDirection.dy / headingLength)
            let side = CGVector(dx: -backward.dy, dy: backward.dx)
            let pulse = 0.62 + (sin(time * 15) + 1) * 0.16
            for streak in -1...1 {
                let offset = CGFloat(streak) * radius * 0.48
                let start = CGPoint(x: point.x + backward.dx * radius * 0.55 + side.dx * offset, y: point.y + backward.dy * radius * 0.55 + side.dy * offset)
                let streakLengthMultiplier: CGFloat = streak == 0 ? 1.15 : 1.4
                let streakLength = radius * streakLengthMultiplier
                let endX = start.x + backward.dx * streakLength
                let endY = start.y + backward.dy * streakLength
                let end = CGPoint(x: endX, y: endY)
                var wake = Path()
                wake.move(to: start)
                wake.addLine(to: end)
                context.stroke(wake, with: .color(KidsTheme.orange.opacity(Double(pulse))), style: StrokeStyle(lineWidth: max(3, radius * 0.17), lineCap: .round))
                let glimmer = CGPoint(x: end.x + side.dx * radius * 0.12, y: end.y + side.dy * radius * 0.12)
                context.fill(Path(ellipseIn: CGRect(x: glimmer.x - 2.5, y: glimmer.y - 2.5, width: 5, height: 5)), with: .color(KidsTheme.yellow.opacity(0.95)))
            }
            let speedHalo = Path(ellipseIn: CGRect(x: point.x - radius * 1.85, y: point.y - radius * 1.3, width: radius * 3.7, height: radius * 2.6))
            context.stroke(speedHalo, with: .color(KidsTheme.yellow.opacity(Double(0.35 + pulse * 0.3))), lineWidth: 2)
        }

        if magnetPowerUpRemaining > 0 {
            let magnetRadius = radius * 2.25
            let field = Path(ellipseIn: CGRect(x: point.x - magnetRadius, y: point.y - magnetRadius * 0.83, width: magnetRadius * 2, height: magnetRadius * 1.66))
            context.stroke(field, with: .color(KidsTheme.mint.opacity(0.72)), style: StrokeStyle(lineWidth: 3, dash: [3, 7], dashPhase: -time * 14))
            for spark in 0..<6 {
                let angle = -time * 1.4 + CGFloat(spark) * (.pi / 3)
                let center = CGPoint(x: point.x + cos(angle) * magnetRadius, y: point.y + sin(angle) * magnetRadius * 0.83)
                let sparkSize = CGFloat(4 + spark % 3)
                let sparkle = Path(ellipseIn: CGRect(x: center.x - sparkSize / 2, y: center.y - sparkSize / 2, width: sparkSize, height: sparkSize))
                context.fill(sparkle, with: .color(.white.opacity(0.95)))
            }
        }
    }

    private func drawFishSprite(_ sprite: UIImage, at point: CGPoint, radius: CGFloat, level: Int, tiltAngle: CGFloat, flipHorizontally: Bool, isPlayer: Bool, in context: inout GraphicsContext) {
        if isPlayer {
            let halo = Path(ellipseIn: CGRect(x: point.x - radius * 1.82, y: point.y - radius * 1.35, width: radius * 3.64, height: radius * 2.7))
            context.stroke(halo, with: .color(.white.opacity(0.9)), lineWidth: 3)
        }

        let bounds = CGRect(x: point.x - radius * 1.65, y: point.y - radius * 1.48, width: radius * 3.3, height: radius * 2.96)
        var spriteContext = context
        spriteContext.translateBy(x: point.x, y: point.y)
        spriteContext.rotate(by: Angle(radians: Double(tiltAngle)))
        spriteContext.scaleBy(x: flipHorizontally ? -1 : 1, y: 1)
        spriteContext.translateBy(x: -point.x, y: -point.y)
        spriteContext.draw(Image(uiImage: sprite), in: bounds)

        let fontSize = max(10, min(15, radius * 0.46))
        let label = Text("Lv.\(level)")
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .foregroundColor(.white)
        let labelWidth = max(38, CGFloat(level.description.count + 3) * fontSize * 0.58)
        let labelRect = CGRect(x: point.x - labelWidth / 2, y: point.y - radius * 1.25 - 20, width: labelWidth, height: 19)
        context.fill(Path(roundedRect: labelRect, cornerRadius: 9), with: .color(isPlayer ? Color(red: 0.96, green: 0.38, blue: 0.18) : Color(red: 0.04, green: 0.25, blue: 0.32).opacity(0.84)))
        context.draw(label, at: CGPoint(x: point.x, y: labelRect.midY + 0.5))
    }

    private func startGame() {
        let cost = app.fishTicketSettings.ticketsPerGame
        guard cost == 0 || app.spendSnakeTicket(count: cost) else { return }
        isTemporaryTrialRun = false
        beginGameAfterTicketSpend()
    }

    private func startTemporaryTrial() {
        guard app.fishTicketSettings.allowsTemporaryTrial else { return }
        isTemporaryTrialRun = true
        beginGameAfterTicketSpend()
    }

    private func returnToIntro() {
        showingResult = false
        isBoosting = false
        movementTargetInWorld = nil
        saveFishSkinProgress()
        app.refreshSnakeRewardStatus()
        phase = .intro
    }

    private func beginGameAfterTicketSpend() {
        showingResult = false
        activeDifficulty = app.fishTicketSettings.difficulty
        UserDefaults.standard.set(selectedFishSkin.rawValue, forKey: "Chinsekid.UnityFishSelectedSkin")
        UserDefaults.standard.set(activeDifficulty.rawValue, forKey: "Chinsekid.UnityFishDifficulty")
        unityRuntimeState = .waiting
        // The ocean has no outer edge; each run starts at a fresh origin and
        // the world coordinate space can continue growing as the camera moves.
        playerPosition = .zero
        cameraPosition = CGPoint(x: playerPosition.x - viewportSize.width / 2, y: playerPosition.y - viewportSize.height / 2)
        playerDirection = CGVector(dx: 1, dy: 0)
        movementTargetInWorld = nil
        isBoosting = false
        boostIntensity = 0
        score = 0
        eatenCount = 0
        fishSchoolTimer = 6
        fishSchoolWave = 0
        fishSchoolNoticeRemaining = 0
        highestLevelReached = 1
        powerUps = []
        seaMines = []
        speedPowerUpRemaining = 0
        shieldPowerUpRemaining = 0
        shieldGraceRemaining = 0
        magnetPowerUpRemaining = 0
        hazardSlowRemaining = 0
        powerUpSpawnTimer = 9
        seaMineSpawnTimer = activeDifficulty.mineInterval.lowerBound
        powerUpNotice = nil
        powerUpNoticeRemaining = 0
        fishes = (0..<34).map { _ in makeFish() }
        for index in 0..<8 {
            let angle = CGFloat(index) * (.pi / 4)
            let offset = CGFloat.random(in: 110...220)
            fishes.append(OceanFish(
                position: CGPoint(x: playerPosition.x + cos(angle) * offset, y: playerPosition.y + sin(angle) * offset),
                direction: CGVector(dx: cos(angle + .pi), dy: sin(angle + .pi)),
                radius: CGFloat.random(in: 7...11),
                speed: CGFloat.random(in: 16...28),
                species: FishSpecies.allCases.randomElement() ?? .clownfish
            ))
        }
        ensureHigherLevelFishExists()
        updateHunterSelection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
        synchronizeRenderingScene()
    }

    private func makeFish() -> OceanFish {
        // After the player's size reaches its cap, keep generating smaller
        // edible fish at nearby ranks so score-based levels can continue.
        let fishLevel: Int
        if level <= 6 {
            fishLevel = [1, 1, 1, 1, 2, 2, 2, 3, 3, 4, 5, 6].randomElement() ?? 1
        } else {
            let rankOffset = Int.random(in: 1...min(4, level - 1))
            fishLevel = max(1, level - rankOffset)
        }
        let lowerBound: CGFloat
        let upperBound: CGFloat
        if fishLevel == 1 {
            // The player starts at radius 15, so every level-one fish must
            // remain visibly smaller and edible from the first moment.
            lowerBound = 8
            upperBound = 14
        } else {
            let rankRadius = min(38, CGFloat(8 + fishLevel * 5))
            lowerBound = max(15, rankRadius - 1.5)
            upperBound = min(rankRadius + 1.5, Self.maximumPlayerRadius - 1)
        }
        let radius = CGFloat.random(in: lowerBound...upperBound)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let spawnDistance = CGFloat.random(in: 180...540)
        let point = CGPoint(
            x: playerPosition.x + cos(angle) * spawnDistance,
            y: playerPosition.y + sin(angle) * spawnDistance
        )
        return OceanFish(
            position: point,
            direction: CGVector(dx: cos(angle), dy: sin(angle)),
            radius: radius,
            speed: CGFloat.random(in: 18...46),
            species: FishSpecies.allCases.randomElement() ?? .clownfish,
            levelOverride: fishLevel
        )
    }

    private func spawnFishSchool() {
        fishSchoolWave += 1
        let direction: CGVector
        if Bool.random() {
            direction = CGVector(dx: Bool.random() ? 1 : -1, dy: 0)
        } else {
            direction = CGVector(dx: 0, dy: Bool.random() ? 1 : -1)
        }

        var origin = CGPoint(
            x: cameraPosition.x + viewportSize.width * CGFloat.random(in: 0.28...0.72),
            y: cameraPosition.y + viewportSize.height * CGFloat.random(in: 0.28...0.72)
        )
        if direction.dx > 0 { origin.x = cameraPosition.x - 48 }
        if direction.dx < 0 { origin.x = cameraPosition.x + viewportSize.width + 48 }
        if direction.dy > 0 { origin.y = cameraPosition.y - 48 }
        if direction.dy < 0 { origin.y = cameraPosition.y + viewportSize.height + 48 }

        let perpendicular = CGVector(dx: -direction.dy, dy: direction.dx)
        let schoolSpecies: [FishSpecies] = [.clownfish, .butterfly, .tang, .puffer, .green, .screenshotClown, .blueMinnow, .stripedCoral, .redfin, .tealPuffer, .silverfish, .longfinFish, .shrimp, .octopus]
        let extraColumns = min(3, max(0, (highestLevelReached - 1) / 2))
        let columns = 5 + extraColumns
        let proposedSchoolSpeed = CGFloat(54 + highestLevelReached * 2)
        let schoolSpeed: CGFloat = min(76, proposedSchoolSpeed)
        let rewardFishRadius = min(playerRadius - 0.7, CGFloat(17 + highestLevelReached))
        for row in 0..<2 {
            for column in 0..<columns {
                let trailDistance = CGFloat(column) * 54
                let sideOffset = (CGFloat(row) - 0.5) * 52
                let isRewardFish = row == 0 && column == 0
                let fishX = origin.x - direction.dx * trailDistance + perpendicular.dx * sideOffset
                let fishY = origin.y - direction.dy * trailDistance + perpendicular.dy * sideOffset
                let fishPosition = CGPoint(x: fishX, y: fishY)
                let fishRadius: CGFloat
                if isRewardFish {
                    fishRadius = max(8, rewardFishRadius)
                } else {
                    fishRadius = CGFloat.random(in: 7...12)
                }
                let fishSpeed = schoolSpeed + CGFloat.random(in: -4...4)
                let fish = OceanFish(
                    position: fishPosition,
                    direction: direction,
                    radius: fishRadius,
                    speed: fishSpeed,
                    species: schoolSpecies[(row * 3 + column) % schoolSpecies.count],
                    isInSchool: true,
                    levelOverride: min(level, level(for: fishRadius))
                )
                fishes.append(fish)
            }
        }
        fishSchoolNoticeRemaining = 2.4
    }

    private func level(for radius: CGFloat) -> Int {
        max(1, Int((radius - 10) / 5))
    }

    private func level(for fish: OceanFish) -> Int {
        fish.levelOverride ?? level(for: fish.radius)
    }

    // The level badge is the game's eatability rule: equal-level fish are
    // edible, even when their visual radius differs slightly from the player's.
    private func canEat(_ fish: OceanFish) -> Bool {
        level(for: fish) <= level
    }

    private func ensureHigherLevelFishExists() {
        let requiredLevel = level + 2
        let minimumThreatCount = activeDifficulty.threatCount
        let existingThreatCount = fishes.filter { level(for: $0) >= requiredLevel }.count
        guard existingThreatCount < minimumThreatCount else { return }

        let threatRadius: CGFloat
        if requiredLevel <= 6 {
            threatRadius = min(38, CGFloat(8 + requiredLevel * 5))
        } else {
            threatRadius = min(Self.maximumThreatFishRadius, playerRadius + CGFloat(requiredLevel - level) * 5)
        }
        for _ in existingThreatCount..<minimumThreatCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let spawnDistance = CGFloat.random(in: 210...360)
            fishes.append(OceanFish(
                position: CGPoint(
                    x: playerPosition.x + cos(angle) * spawnDistance,
                    y: playerPosition.y + sin(angle) * spawnDistance
                ),
                direction: CGVector(dx: cos(angle + .pi), dy: sin(angle + .pi)),
                radius: threatRadius,
                speed: CGFloat.random(in: 30...42),
                species: .shark,
                levelOverride: requiredLevel
            ))
        }
    }

    private func updateHunterSelection() {
        for index in fishes.indices {
            let canHunt = !fishes[index].isInSchool && level(for: fishes[index]) > level
            if !canHunt {
                fishes[index].isHuntingPlayer = false
            }
        }

        let activeHunterCount = fishes.filter { $0.isHuntingPlayer }.count
        guard activeHunterCount < activeDifficulty.maxChasers + 1 else { return }

        let candidates = fishes.indices.filter {
            !fishes[$0].isInSchool
                && !fishes[$0].isHuntingPlayer
                && level(for: fishes[$0]) > level
        }.shuffled()
        let desiredCount = activeDifficulty.maxChasers + 1
        let additionalHunters = min(desiredCount - activeHunterCount, candidates.count)
        for index in candidates.prefix(additionalHunters) {
            fishes[index].isHuntingPlayer = true
        }
    }

    private func updateChase(at index: Int, gap: CGFloat, activeChasers: Int, deltaTime dt: CGFloat) {
        let canChase = fishes[index].isHuntingPlayer
            && level(for: fishes[index]) > level && gap < 360
            && (fishes[index].chaseRemaining > 0 || fishes[index].chaseWindup > 0
                || activeChasers < activeDifficulty.maxChasers)
        if fishes[index].chaseWindup > 0 {
            guard canChase else { fishes[index].chaseWindup = 0; return }
            fishes[index].chaseWindup = max(0, fishes[index].chaseWindup - dt)
            if fishes[index].chaseWindup == 0 {
                fishes[index].chaseRemaining = CGFloat.random(in: activeDifficulty.chaseDuration)
            }
            return
        }
        if fishes[index].chaseCooldown > 0 {
            fishes[index].chaseCooldown = max(0, fishes[index].chaseCooldown - dt)
            return
        }
        if fishes[index].chaseRemaining > 0 {
            fishes[index].chaseRemaining = max(0, fishes[index].chaseRemaining - dt)
            if canChase && fishes[index].chaseRemaining > 0 { return }
            fishes[index].chaseRemaining = 0
            fishes[index].chaseCooldown = CGFloat.random(in: activeDifficulty.chaseCooldown)
            // Turn away on giving up rather than coasting toward the player.
            let dx = fishes[index].position.x - playerPosition.x
            let dy = fishes[index].position.y - playerPosition.y
            let distance = max(1, hypot(dx, dy))
            fishes[index].direction = CGVector(dx: dx / distance, dy: dy / distance)
        } else if canChase {
            fishes[index].chaseWindup = activeDifficulty.chaseWindup
        }
    }

    private func safeItemSpawnPoint() -> CGPoint {
        let insetX = min(90, viewportSize.width * 0.18)
        let insetY = min(110, viewportSize.height * 0.18)
        for _ in 0..<12 {
            let point = CGPoint(
                x: cameraPosition.x + CGFloat.random(in: insetX...max(insetX + 1, viewportSize.width - insetX)),
                y: cameraPosition.y + CGFloat.random(in: insetY...max(insetY + 1, viewportSize.height - insetY))
            )
            let clearOfPlayer = distance(point, playerPosition) > 130
            let clearOfOtherItems = powerUps.allSatisfy { distance(point, $0.position) > 90 }
                && seaMines.allSatisfy { distance(point, $0.position) > 100 }
            if clearOfPlayer && clearOfOtherItems { return point }
        }
        let angle = CGFloat.random(in: 0...(2 * .pi))
        return CGPoint(x: playerPosition.x + cos(angle) * 210, y: playerPosition.y + sin(angle) * 210)
    }

    private func spawnPowerUp(_ kind: FishPowerUpKind, forUnlock: Bool = false) {
        if powerUps.count >= 4 {
            guard forUnlock else { return }
            powerUps.removeFirst()
        }
        powerUps.append(FishPowerUp(position: safeItemSpawnPoint(), kind: kind))
    }

    private func spawnRandomUnlockedPowerUp() {
        let unlocked = FishPowerUpKind.allCases.filter { $0.unlockLevel <= highestLevelReached }
        guard let kind = unlocked.randomElement() else { return }
        spawnPowerUp(kind)
    }

    private func spawnSeaMine() {
        guard seaMines.count < activeDifficulty.maxMines else { return }
        seaMines.append(SeaMine(position: safeItemSpawnPoint()))
    }

    private func updateLevelUnlocks() {
        let reachedLevel = level
        if !isTemporaryTrialRun && reachedLevel > lifetimeFishBestLevel {
            lifetimeFishBestLevel = reachedLevel
            unlockEligibleFishSkins()
            saveFishSkinProgress()
        }
        guard reachedLevel > highestLevelReached else { return }
        let previousLevel = highestLevelReached
        highestLevelReached = reachedLevel
        for kind in FishPowerUpKind.allCases where kind.unlockLevel > previousLevel && kind.unlockLevel <= reachedLevel {
            spawnPowerUp(kind, forUnlock: true)
            powerUpNotice = "🔓 升到 Lv.\(kind.unlockLevel)，解锁\(kind.title)道具！"
            powerUpNoticeRemaining = 3.5
        }
        if reachedLevel >= 3, previousLevel < 3 {
            spawnSeaMine()
            seaMineSpawnTimer = CGFloat.random(in: activeDifficulty.mineInterval)
            powerUpNotice = "⚠️ 海胆障碍出现了，记得躲开！"
            powerUpNoticeRemaining = 3.5
        }
    }

    private var fishSkinDefaultsPrefix: String {
        "fish.skinProgress.\(app.currentUser.id)"
    }

    private func loadFishSkinProgress() {
        let defaults = UserDefaults.standard
        let prefix = fishSkinDefaultsPrefix
        lifetimeFishEaten = defaults.integer(forKey: "\(prefix).officialEaten")
        lifetimeFishBestLevel = max(1, defaults.integer(forKey: "\(prefix).officialBestLevel"))
        lifetimeBestRunFishEaten = defaults.integer(forKey: "\(prefix).officialBestRunEaten")
        unlockedFishSkins = Set((defaults.stringArray(forKey: "\(prefix).unlocked") ?? []).compactMap(FishSpecies.init(rawValue:)))
        unlockedFishSkins.formUnion(unlockedFishSkins.map(\.canonicalSkin))
        unlockedFishSkins.insert(.clownfish)
        if let selected = defaults.string(forKey: "\(prefix).selected").flatMap(FishSpecies.init(rawValue:)), unlockedFishSkins.contains(selected) {
            selectedFishSkin = selected.canonicalSkin
        } else {
            selectedFishSkin = .clownfish
        }
        unlockEligibleFishSkins()
        saveFishSkinProgress()
    }

    private func saveFishSkinProgress() {
        let defaults = UserDefaults.standard
        let prefix = fishSkinDefaultsPrefix
        defaults.set(lifetimeFishEaten, forKey: "\(prefix).officialEaten")
        defaults.set(lifetimeFishBestLevel, forKey: "\(prefix).officialBestLevel")
        defaults.set(lifetimeBestRunFishEaten, forKey: "\(prefix).officialBestRunEaten")
        defaults.set(unlockedFishSkins.map(\.rawValue).sorted(), forKey: "\(prefix).unlocked")
        defaults.set(selectedFishSkin.rawValue, forKey: "\(prefix).selected")
    }

    private func unlockEligibleFishSkins() {
        let newlyUnlocked = FishSpecies.selectableSkins.filter { skin in
            guard !unlockedFishSkins.contains(skin) else { return false }
            guard let rule = skin.unlockRule else { return false }
            return rule.isMet(
                bestLevel: lifetimeFishBestLevel,
                totalFish: lifetimeFishEaten,
                bestRunFish: lifetimeBestRunFishEaten
            )
        }
        guard !newlyUnlocked.isEmpty else { return }
        unlockedFishSkins.formUnion(newlyUnlocked)
        skinUnlockNotice = "🐠 解锁新皮肤：\(newlyUnlocked.map(\.skinName).joined(separator: "、"))"
        skinUnlockNoticeRemaining = 3.5
        saveFishSkinProgress()
    }

    private func activate(_ kind: FishPowerUpKind) {
        switch kind {
        case .speed:
            speedPowerUpRemaining = 8
        case .shield:
            shieldPowerUpRemaining = 7
            shieldGraceRemaining = 0
        case .magnet:
            magnetPowerUpRemaining = 9
        }
        powerUpNotice = "拿到\(kind.symbol)\(kind.title)！"
        powerUpNoticeRemaining = 2.5
    }

    private func repelThreat(at index: Int) {
        let dx = fishes[index].position.x - playerPosition.x
        let dy = fishes[index].position.y - playerPosition.y
        let gap = max(1, hypot(dx, dy))
        let direction = CGVector(dx: dx / gap, dy: dy / gap)
        fishes[index].direction = turnedDirection(from: fishes[index].direction, toward: direction, maxRadians: 0.35)
        let safeGap = playerRadius + fishes[index].radius + 20
        fishes[index].position = CGPoint(x: playerPosition.x + direction.dx * safeGap, y: playerPosition.y + direction.dy * safeGap)
    }

    private func updateWorld(deltaTime dt: CGFloat) {
        guard phase == .playing else { return }
        backgroundMusic.recoverIfPlaybackStopped()
        oceanTime += dt
        let boostTarget: CGFloat = isBoosting ? 1 : 0
        let boostBlend = 1 - exp(-CGFloat(8) * dt)
        boostIntensity += (boostTarget - boostIntensity) * boostBlend
        fishSchoolTimer -= dt
        fishSchoolNoticeRemaining = max(0, fishSchoolNoticeRemaining - dt)
        powerUpNoticeRemaining = max(0, powerUpNoticeRemaining - dt)
        skinUnlockNoticeRemaining = max(0, skinUnlockNoticeRemaining - dt)
        speedPowerUpRemaining = max(0, speedPowerUpRemaining - dt)
        shieldPowerUpRemaining = max(0, shieldPowerUpRemaining - dt)
        shieldGraceRemaining = max(0, shieldGraceRemaining - dt)
        magnetPowerUpRemaining = max(0, magnetPowerUpRemaining - dt)
        hazardSlowRemaining = max(0, hazardSlowRemaining - dt)
        powerUpSpawnTimer -= dt
        seaMineSpawnTimer -= dt
        if powerUpSpawnTimer <= 0 {
            spawnRandomUnlockedPowerUp()
            powerUpSpawnTimer = CGFloat.random(in: 13...19)
        }
        if highestLevelReached >= 3 && seaMineSpawnTimer <= 0 {
            spawnSeaMine()
            seaMineSpawnTimer = CGFloat.random(in: activeDifficulty.mineInterval)
        }
        if fishSchoolTimer <= 0 {
            spawnFishSchool()
            let elapsedLevels = CGFloat(max(0, highestLevelReached - 1))
            let levelReduction = elapsedLevels * 0.8
            let proposedInterval = 23 - levelReduction
            let interval = max(13, proposedInterval)
            fishSchoolTimer = CGFloat.random(in: interval...(interval + 4))
        }
        if let target = movementTargetInWorld {
            let dx = target.x - playerPosition.x
            let dy = target.y - playerPosition.y
            let gap = hypot(dx, dy)
            if gap > 3 {
                let targetDirection = CGVector(dx: dx / gap, dy: dy / gap)
                playerDirection = turnedDirection(from: playerDirection, toward: targetDirection, maxRadians: 14 * dt)
            } else {
                movementTargetInWorld = nil
            }
        }
        let boostMultiplier: CGFloat = speedPowerUpRemaining > 0 ? 1.42 : 1
        let slowMultiplier: CGFloat = hazardSlowRemaining > 0 ? 0.72 : 1
        let growthLevels = CGFloat(max(0, level - 1))
        let growthBonus = min(0.2, growthLevels * 0.025)
        let growthSpeedMultiplier: CGFloat = 1 + growthBonus
        let targetDistance: CGFloat
        if let movementTargetInWorld {
            targetDistance = distance(movementTargetInWorld, playerPosition)
        } else {
            targetDistance = 0
        }
        let catchUpLimit = 0.55 - boostIntensity * 0.17
        let catchUpRatio = targetDistance / 260
        let catchUpBonus = min(catchUpLimit, catchUpRatio)
        let catchUpMultiplier: CGFloat = movementTargetInWorld == nil ? 1 : 1 + catchUpBonus
        let basePlayerSpeed: CGFloat = 132 + boostIntensity * 73
        let speedWithPowerUp = basePlayerSpeed * boostMultiplier
        let speedWithHazard = speedWithPowerUp * slowMultiplier
        let speedWithGrowth = speedWithHazard * growthSpeedMultiplier
        let playerSpeed = speedWithGrowth * catchUpMultiplier
        if let target = movementTargetInWorld {
            let remaining = distance(playerPosition, target)
            let targetDX = target.x - playerPosition.x
            let targetDY = target.y - playerPosition.y
            let facingDotProduct = playerDirection.dx * targetDX + playerDirection.dy * targetDY
            let isFacingTarget = facingDotProduct > 0
            let step = isFacingTarget ? min(playerSpeed * dt, remaining) : playerSpeed * dt
            playerPosition.x += playerDirection.dx * step
            playerPosition.y += playerDirection.dy * step
        }
        followCameraSmoothly(deltaTime: dt)

        var activeChasers = fishes.filter { $0.chaseWindup > 0 || $0.chaseRemaining > 0 }.count
        for index in fishes.indices {
            let dx = playerPosition.x - fishes[index].position.x
            let dy = playerPosition.y - fishes[index].position.y
            let gap = max(1, hypot(dx, dy))
            let wasChasing = fishes[index].chaseWindup > 0 || fishes[index].chaseRemaining > 0
            updateChase(at: index, gap: gap, activeChasers: activeChasers, deltaTime: dt)
            let isChasing = fishes[index].chaseWindup > 0 || fishes[index].chaseRemaining > 0
            if wasChasing && !isChasing { activeChasers -= 1 }
            if !wasChasing && isChasing { activeChasers += 1 }
            let isHunter = fishes[index].isHuntingPlayer
                && fishes[index].chaseRemaining > 0 && level(for: fishes[index]) > level
            var desiredDirection = fishes[index].direction
            if fishes[index].isInSchool {
                // School members keep their shared heading and spacing as they cross the view.
            } else if isHunter && gap < 360 {
                desiredDirection = CGVector(dx: dx / gap, dy: dy / gap)
            } else if magnetPowerUpRemaining > 0 && level(for: fishes[index]) <= level && gap < 380 {
                desiredDirection = CGVector(dx: dx / gap, dy: dy / gap)
            } else if gap > 650 && fishes[index].chaseCooldown <= 0 {
                desiredDirection = CGVector(dx: dx / gap, dy: dy / gap)
            } else if Int.random(in: 0..<40) == 0 && gap > 80 {
                let angle = atan2(fishes[index].direction.dy, fishes[index].direction.dx) + CGFloat.random(in: -0.13...0.13)
                desiredDirection = CGVector(dx: cos(angle), dy: sin(angle))
            }
            let hunterTurnRate = min(4.8, 3.4 + CGFloat(max(0, level - 1)) * 0.28)
            let turnRate = isHunter ? hunterTurnRate : fishes[index].turnRate
            fishes[index].direction = turnedDirection(from: fishes[index].direction, toward: desiredDirection, maxRadians: turnRate * dt)
            if isHunter && gap < 360 {
                let chaseBoost = min(0.16, CGFloat(max(0, highestLevelReached - 1)) * 0.025)
                fishes[index].position.x += fishes[index].direction.dx * fishes[index].speed * (1 + chaseBoost) * dt
                fishes[index].position.y += fishes[index].direction.dy * fishes[index].speed * (1 + chaseBoost) * dt
                continue
            }
            fishes[index].position.x += fishes[index].direction.dx * fishes[index].speed * dt
            fishes[index].position.y += fishes[index].direction.dy * fishes[index].speed * dt
        }
        resolveFishSpacing()

        for index in powerUps.indices.reversed() where distance(powerUps[index].position, playerPosition) < powerUps[index].radius + playerRadius * 0.8 {
            let item = powerUps.remove(at: index)
            activate(item.kind)
        }

        for index in seaMines.indices.reversed() where distance(seaMines[index].position, playerPosition) < seaMines[index].radius + playerRadius * 0.58 {
            seaMines.remove(at: index)
            score = max(0, score - 8)
            hazardSlowRemaining = 3
            powerUpNotice = "💥 撞到海胆了！减速 3 秒，小心一点"
            powerUpNoticeRemaining = 3
        }

        for index in fishes.indices.reversed() {
            let fish = fishes[index]
            let gap = distance(fish.position, playerPosition)
            if gap < fish.radius * 0.55 + playerRadius * 0.52 {
                if canEat(fish) {
                    score += max(5, Int(fish.radius.rounded()))
                    eatenCount += 1
                    if !isTemporaryTrialRun {
                        lifetimeFishEaten += 1
                        lifetimeFishBestLevel = max(lifetimeFishBestLevel, level)
                        lifetimeBestRunFishEaten = max(lifetimeBestRunFishEaten, eatenCount)
                        unlockEligibleFishSkins()
                        saveFishSkinProgress()
                    }
                    fishes[index] = makeFish()
                } else {
                    if shieldPowerUpRemaining > 0 || shieldGraceRemaining > 0 {
                        let usedShield = shieldPowerUpRemaining > 0
                        shieldPowerUpRemaining = 0
                        if usedShield {
                            shieldGraceRemaining = 1.2
                            powerUpNotice = "🫧 护盾挡住大鱼了！快游开！"
                            powerUpNoticeRemaining = 2.5
                        }
                        repelThreat(at: index)
                    } else {
                        resultLevel = level
                        returnToIntro()
                        showingResult = true
                        return
                    }
                }
            }
        }
        updateLevelUnlocks()
        for index in powerUps.indices { powerUps[index].remainingTime -= dt }
        for index in seaMines.indices { seaMines[index].remainingTime -= dt }
        let itemCullDistance = max(viewportSize.width, viewportSize.height) * 1.6
        powerUps.removeAll { $0.remainingTime <= 0 || distance($0.position, playerPosition) > itemCullDistance }
        seaMines.removeAll { $0.remainingTime <= 0 || distance($0.position, playerPosition) > itemCullDistance }
        let schoolMargin = max(viewportSize.width, viewportSize.height) * 0.45
        fishes.removeAll { fish in
            guard fish.isInSchool else { return false }
            return fish.position.x < cameraPosition.x - schoolMargin
                || fish.position.x > cameraPosition.x + viewportSize.width + schoolMargin
                || fish.position.y < cameraPosition.y - schoolMargin
                || fish.position.y > cameraPosition.y + viewportSize.height + schoolMargin
        }
        ensureHigherLevelFishExists()
        updateHunterSelection()
        synchronizeRenderingScene()
    }

    private func resolveFishSpacing() {
        guard fishes.count > 1 else { return }
        for first in 0..<(fishes.count - 1) {
            for second in (first + 1)..<fishes.count {
                let dx = fishes[second].position.x - fishes[first].position.x
                let dy = fishes[second].position.y - fishes[first].position.y
                let gap = hypot(dx, dy)
                let minimumGap = (fishes[first].radius + fishes[second].radius) * 1.7 + 2
                guard gap < minimumGap else { continue }

                let angle = gap > 0.001 ? atan2(dy, dx) : CGFloat(first + second) * 2.399963
                let push = (minimumGap - gap) * 0.5 + 0.1
                let pushX = cos(angle) * push
                let pushY = sin(angle) * push
                fishes[first].position.x -= pushX
                fishes[first].position.y -= pushY
                fishes[second].position.x += pushX
                fishes[second].position.y += pushY
            }
        }
    }

    private func centerCameraOnPlayer() {
        cameraPosition = CGPoint(
            x: playerPosition.x - viewportSize.width / 2,
            y: playerPosition.y - viewportSize.height / 2
        )
    }

    private func followCameraSmoothly(deltaTime dt: CGFloat) {
        // Let the fish move freely through the middle of the view. Once it
        // enters the outer band, ease the camera along with it instead of
        // recentering in one step when it reaches the edge.
        let marginX = viewportSize.width * 0.24
        let marginY = viewportSize.height * 0.24
        let screenX = playerPosition.x - cameraPosition.x
        let screenY = playerPosition.y - cameraPosition.y
        let targetX: CGFloat
        let targetY: CGFloat

        if screenX < marginX {
            targetX = playerPosition.x - marginX
        } else if screenX > viewportSize.width - marginX {
            targetX = playerPosition.x - (viewportSize.width - marginX)
        } else {
            targetX = cameraPosition.x
        }

        if screenY < marginY {
            targetY = playerPosition.y - marginY
        } else if screenY > viewportSize.height - marginY {
            targetY = playerPosition.y - (viewportSize.height - marginY)
        } else {
            targetY = cameraPosition.y
        }

        let blend = 1 - exp(-CGFloat(7) * dt)
        cameraPosition.x += (targetX - cameraPosition.x) * blend
        cameraPosition.y += (targetY - cameraPosition.y) * blend
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func turnedDirection(from current: CGVector, toward target: CGVector, maxRadians: CGFloat) -> CGVector {
        let currentAngle = atan2(current.dy, current.dx)
        let targetAngle = atan2(target.dy, target.dx)
        let difference = atan2(sin(targetAngle - currentAngle), cos(targetAngle - currentAngle))
        let turn = min(max(difference, -maxRadians), maxRadians)
        let angle = currentAngle + turn
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private func arrow(for dx: CGFloat, dy: CGFloat) -> String {
        if abs(dx) > abs(dy) { return dx < 0 ? "左" : "右" }
        return dy < 0 ? "上" : "下"
    }
}

private struct FishActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background(color.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
