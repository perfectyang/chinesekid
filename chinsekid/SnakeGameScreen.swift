import AVFoundation
import SwiftUI

@MainActor
private final class SnakeBackgroundMusic {
    private var player: AVAudioPlayer?

    init() {
        let bundle = Bundle.main
        let candidateURLs = [
            bundle.url(forResource: "SnakeGameMusic", withExtension: "wav", subdirectory: "Resources"),
            bundle.url(forResource: "SnakeGameMusic", withExtension: "wav", subdirectory: nil),
            bundle.resourceURL?.appendingPathComponent("Resources/SnakeGameMusic.wav"),
            bundle.resourceURL?.appendingPathComponent("SnakeGameMusic.wav")
        ]
        guard let url = candidateURLs.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            NSLog("Missing bundled snake game music")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.35
            if player?.prepareToPlay() != true {
                NSLog("Unable to prepare snake game music")
            }
        } catch {
            NSLog("Unable to load snake game music: %@", error.localizedDescription)
        }
    }

    func resume() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if let player, !player.isPlaying, !player.play() {
                NSLog("Snake game music player did not start")
            }
        } catch {
            NSLog("Unable to start snake game music: %@", error.localizedDescription)
        }
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
    }
}

private struct SnakeOrb: Identifiable {
    let id = UUID()
    var point: CGPoint
    let growth: Int
}

private struct SnakeLetterChest: Identifiable {
    let id = UUID()
    var point: CGPoint
    let letter: Character
    let colorIndex: Int
}

private final class SnakeTimerAccumulator {
    var elapsed: CGFloat = 0
}

private final class SnakeSteeringState {
    var targetDirection = CGVector(dx: 1, dy: 0)
    var lastPoint: CGPoint?
    var pendingDelta = CGSize.zero
    var lastTapAt: Date?

    func reset(direction: CGVector) {
        targetDirection = direction
        lastPoint = nil
        pendingDelta = .zero
        lastTapAt = nil
    }
}

private struct SnakeChestPalette {
    let lidLight: Color
    let lidDark: Color
    let bodyLight: Color
    let bodyDark: Color
    let outline: Color
    let glow: Color
}

private enum SnakeTactic: Equatable {
    case foraging
    case tailing
    case overtaking
    case encircling
}

private struct SnakeAITarget {
    let id: UUID?
    let isPlayer: Bool
    let segments: [CGPoint]
    let direction: CGVector
}

private struct SnakeAIPlan {
    let tactic: SnakeTactic
    let direction: CGVector
    let targetID: UUID?
    let targetsPlayer: Bool
}

private struct SnakeRival: Identifiable {
    let id = UUID()
    var segments: [CGPoint]
    var direction: CGVector
    var targetDirection: CGVector
    var turnTimer: CGFloat
    let colorIndex: Int
    var pendingGrowth = 0
    var growthProgress: CGFloat = 0
    var tactic: SnakeTactic = .foraging
    var targetRivalID: UUID?
    var targetsPlayer = false
    var tacticDuration: CGFloat = 0
    var boostRemaining: CGFloat = 0
    var boostCooldown: CGFloat = 0
    var orbitDirection: CGFloat = 1
}

struct SnakeGameScreen: View {
    // The camera shows roughly this many world units across. The world itself has no edge.
    private static let cameraViewUnits: CGFloat = 40
    private static let freePlayForTesting = false
    private static let frameIntervalNanoseconds: UInt64 = 16_666_667
    private static let initialSpeed: CGFloat = 4.8
    private static let speedIncreasePerSegment: CGFloat = 0.024
    private static let maximumSpeed: CGFloat = 6.8
    private static let segmentSpacing: CGFloat = 0.58
    private static let maximumTurnRate: CGFloat = 10.5
    private static let initialChestDeadline: CGFloat = 60
    private static let nextChestDeadline: CGFloat = 15
    private static let targetOrbCount = 72
    private static let orbRefillBatchSize = 12
    private static let targetRivalCount = 8
    private static let targetLetterChestCount = 4
    private static let chestPaletteCount = 6

    let app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var alphabetSpeech = AlphabetSpeech()
    @State private var backgroundMusic = SnakeBackgroundMusic()
    @State private var rewardLetter: AlphabetLetter?
    @State private var rewardLetterNameTapCount = 0
    @State private var rewardLetterExampleTapCount = 0
    @State private var snake: [CGPoint] = []
    @State private var rivals: [SnakeRival] = []
    @State private var orbs: [SnakeOrb] = []
    @State private var letterChests: [SnakeLetterChest] = []
    @State private var collectedLetters: Set<String> = []
    @State private var directionVector = CGVector(dx: 1, dy: 0)
    @State private var steering = SnakeSteeringState()
    @State private var pendingGrowth = 0
    @State private var growthProgress: CGFloat = 0
    @State private var crawlPhase: CGFloat = 0
    @State private var boostRemaining: CGFloat = 0
    @State private var boostCooldown: CGFloat = 0
    @State private var finalLength = 0
    @State private var finalRank = 1
    @State private var orbRefillTimer: CGFloat = 0
    @State private var rivalRespawnTimer: CGFloat = 0
    @State private var chestRespawnTimer: CGFloat = 0
    @State private var timeUntilNextChest = Self.initialChestDeadline
    @State private var chestTimerAccumulator = SnakeTimerAccumulator()
    @State private var isChestDeadlineActive = false
    @State private var isPlaying = false
    @State private var hasStarted = false
    @State private var outcome: String?
    @State private var showingTicketPractice = false

    var body: some View {
        ZStack {
            StorybookBackground()
            Circle().fill(KidsTheme.mint.opacity(0.16)).frame(width: 210, height: 210).blur(radius: 2).offset(x: 170, y: -330).allowsHitTesting(false)
            Circle().fill(KidsTheme.yellow.opacity(0.18)).frame(width: 150, height: 150).blur(radius: 2).offset(x: -180, y: 330).allowsHitTesting(false)
            VStack(spacing: hasStarted ? 0 : 14) {
                header.padding(.horizontal, hasStarted ? 12 : 0)

                if !hasStarted {
                    introduction
                    Spacer(minLength: 0)
                } else {
                    board
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, hasStarted ? 0 : 22)
            .padding(.top, hasStarted ? 0 : 16)
            .padding(.bottom, hasStarted ? 0 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if hasStarted && !isPlaying && rewardLetter == nil {
                Color.black.opacity(0.20).ignoresSafeArea()
                result
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 480)
                    .transition(.scale.combined(with: .opacity))
            }

            if hasStarted, let rewardLetter {
                letterRewardOverlay(for: rewardLetter)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .ignoresSafeArea(.container, edges: hasStarted ? .bottom : [])
        .preferredColorScheme(.light)
        .onAppear { app.refreshSnakeRewardStatus() }
        .fullScreenCover(isPresented: $showingTicketPractice) {
            AlphabetModuleScreen(
                app: app,
                snakeTicketPractice: true,
                onSnakeTicketEarned: {
                    app.refreshSnakeRewardStatus()
                    showingTicketPractice = false
                }
            )
        }
        .onChange(of: isPlaying) { _, playing in
            if playing && scenePhase == .active {
                backgroundMusic.resume()
            } else {
                backgroundMusic.pause()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isPlaying {
                backgroundMusic.resume()
            } else {
                backgroundMusic.pause()
            }
        }
        .onDisappear {
            isPlaying = false
            alphabetSpeech.stop()
            backgroundMusic.stop()
        }
        .onChange(of: rewardLetter?.id) { _, letterID in
            guard let letterID else { return }
            backgroundMusic.pause()
            alphabetSpeech.play("name_\(letterID.lowercased())")
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            var lastFrameAt = Date()
            while !Task.isCancelled && isPlaying {
                do {
                    try await Task.sleep(nanoseconds: Self.frameIntervalNanoseconds)
                } catch {
                    return
                }
                guard isPlaying else { continue }
                let now = Date()
                let deltaTime = min(CGFloat(now.timeIntervalSince(lastFrameAt)), 0.05)
                lastFrameAt = now
                moveSnake(deltaTime: deltaTime)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.9), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回学习")
            Spacer()
            Text("小蛇闯关")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            Spacer()
            Text(hasStarted ? "双击冲刺" : (Self.freePlayForTesting ? "试玩模式" : "持券开局"))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(KidsTheme.yellow.opacity(0.72), in: Capsule())
                .frame(width: 68)
        }
    }

    private var currentSpeed: CGFloat {
        min(Self.maximumSpeed, Self.initialSpeed + CGFloat(max(0, snake.count - 7)) * Self.speedIncreasePerSegment) + (boostRemaining > 0 ? 2.4 : 0)
    }

    private var canCloseLetterReward: Bool {
        rewardLetterNameTapCount >= 2 && rewardLetterExampleTapCount >= 2
    }

    private var chestTimerProgress: CGFloat {
        min(1, max(0, timeUntilNextChest / (collectedLetters.isEmpty ? Self.initialChestDeadline : Self.nextChestDeadline)))
    }

    private var chestTimerColor: Color {
        timeUntilNextChest <= 5 ? KidsTheme.orange : KidsTheme.blue
    }

    private var mapCollectionHUD: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.94))
            Circle()
                .stroke(KidsTheme.mint.opacity(0.48), lineWidth: 4)
            Circle()
                .trim(from: 0, to: chestTimerProgress)
                .stroke(chestTimerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(Int(ceil(timeUntilNextChest)))")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                Text("秒")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(KidsTheme.ink)
        }
        .frame(width: 48, height: 48)
        .shadow(color: KidsTheme.ink.opacity(0.14), radius: 7, x: 0, y: 3)
        .padding(12)
        .allowsHitTesting(false)
    }

    private func letterRewardOverlay(for letter: AlphabetLetter) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.48).ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack {
                        Label("字母宝箱奖励", systemImage: "sparkles")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(KidsTheme.ink)
                        Spacer()
                        Button(action: resumeAfterLetterReward) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(canCloseLetterReward ? KidsTheme.ink : KidsTheme.muted)
                                .frame(width: 38, height: 38)
                                .background(KidsTheme.yellow.opacity(canCloseLetterReward ? 0.72 : 0.32), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canCloseLetterReward)
                        .accessibilityLabel(canCloseLetterReward ? "关闭字母卡片并继续游戏" : "请先手动点读字母名称和示范各两次")
                    }

                    ScrollView {
                        AlphabetLetterCard(
                            letter: letter,
                            color: [KidsTheme.mint, KidsTheme.yellow, KidsTheme.lilac, KidsTheme.blue, KidsTheme.peach][(AlphabetCatalog.all.firstIndex(where: { $0.id == letter.id }) ?? 0) % 5],
                            isStudied: app.studiedAlphabetLetters.contains(letter.id),
                            speech: alphabetSpeech
                        ) {
                            app.recordAlphabetStudy(letter: letter.id)
                        } onManualNamePlayback: {
                            rewardLetterNameTapCount = min(2, rewardLetterNameTapCount + 1)
                        } onManualExamplePlayback: {
                            rewardLetterExampleTapCount = min(2, rewardLetterExampleTapCount + 1)
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)

                    Button(action: resumeAfterLetterReward) {
                        Label(canCloseLetterReward ? "关闭，继续游戏" : "名称 \(rewardLetterNameTapCount)/2 · 示例 \(rewardLetterExampleTapCount)/2", systemImage: canCloseLetterReward ? "play.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(canCloseLetterReward ? KidsTheme.ink : KidsTheme.muted)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(KidsTheme.mint.opacity(canCloseLetterReward ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCloseLetterReward)
                }
                .padding(18)
                .frame(maxWidth: 420, maxHeight: min(geometry.size.height - 28, 620))
                .background(.white, in: RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.85), lineWidth: 2))
                .shadow(color: .black.opacity(0.24), radius: 22, x: 0, y: 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
            }
        }
        .ignoresSafeArea()
    }

    private func resumeAfterLetterReward() {
        alphabetSpeech.stop()
        rewardLetter = nil
        rewardLetterNameTapCount = 0
        rewardLetterExampleTapCount = 0
        if collectedLetters.count == AlphabetCatalog.all.count {
            finish("集齐 26 个字母！挑战完成")
            return
        }
        timeUntilNextChest = Self.nextChestDeadline
        chestTimerAccumulator.elapsed = 0
        isChestDeadlineActive = true
        isPlaying = true
    }

    private var renderedSnake: [CGPoint] {
        renderedSegments(snake, pendingGrowth: pendingGrowth, progress: growthProgress)
    }

    private var playerRank: Int {
        1 + rivals.filter { $0.segments.count > snake.count }.count
    }

    private var introduction: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(KidsTheme.mint.opacity(0.18)).frame(height: 118)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("学习小奖励")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(KidsTheme.muted)
                        Text("26 题全对，攒券开新局")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(KidsTheme.ink)
                        Text("答错也没关系，继续加油！")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(KidsTheme.muted)
                    }
                    Spacer(minLength: 4)
                    ZStack {
                        Circle().fill(.white.opacity(0.74)).frame(width: 82, height: 82)
                        Text("🐍🍎").font(.system(size: 34)).rotationEffect(.degrees(-8))
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 9) {
                ruleCard("超车拦截", detail: "双击冲刺，绕到前方", icon: "bolt.fill", color: KidsTheme.yellow)
                ruleCard("尾行觅食", detail: "大蛇身后找机会", icon: "arrow.turn.down.right", color: KidsTheme.blue)
                ruleCard("围堵逼位", detail: "长度占优时包围", icon: "circle.dashed", color: KidsTheme.orange)
            }

            if Self.freePlayForTesting {
                Label("试玩模式：可直接开始，不消耗游戏券", systemImage: "play.circle.fill")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
            } else if app.snakeRewardStatus.hasTicket {
                Label("已攒 \(app.snakeRewardStatus.ticketCount) 张游戏券", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
            } else if app.snakeRewardStatus.hasPlayed {
                Label("这张游戏券已使用，再答对 26 个字母就能获得新券", systemImage: "moon.stars.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.muted)
            } else {
                Text("需要完成 26 个字母挑战并全部答对，才能获得游戏券")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(KidsTheme.muted)
            }

            Button(action: startGame) {
                Label("使用 1 张券，开始一局", systemImage: "play.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(KidsTheme.yellow, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(!canStartGame)
            .opacity(canStartGame ? 1 : 0.48)

            Button {
                showingTicketPractice = true
            } label: {
                Label("再练 26 题，攒一张游戏券", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(KidsTheme.mint.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.9), lineWidth: 2))
        .shadow(color: KidsTheme.ink.opacity(0.08), radius: 18, x: 0, y: 9)
        .padding(.top, 10)
    }

    private var board: some View {
        GeometryReader { geometry in
            Canvas(opaque: true, colorMode: .nonLinear, rendersAsynchronously: true) { context, size in
                let cellSize = min(size.width, size.height) / Self.cameraViewUnits
                let cameraCenter = snake.first ?? .zero
                let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                let boardRect = CGRect(origin: .zero, size: size)
                let meadow = Color(red: 0.89, green: 0.96, blue: 0.83)
                context.fill(Path(boardRect), with: .color(meadow))

                let visibleHalfWidth = size.width / (2 * cellSize)
                let visibleHalfHeight = size.height / (2 * cellSize)
                let textureSpacing: CGFloat = 5
                let minTextureX = Int(floor((cameraCenter.x - visibleHalfWidth) / textureSpacing)) - 1
                let maxTextureX = Int(ceil((cameraCenter.x + visibleHalfWidth) / textureSpacing)) + 1
                let minTextureY = Int(floor((cameraCenter.y - visibleHalfHeight) / textureSpacing)) - 1
                let maxTextureY = Int(ceil((cameraCenter.y + visibleHalfHeight) / textureSpacing)) + 1
                for tileX in minTextureX...maxTextureX {
                    for tileY in minTextureY...maxTextureY {
                        let seed = (tileX &* 73856093) ^ (tileY &* 19349663)
                        let offsetX = CGFloat(abs(seed % 997)) / 997 * textureSpacing
                        let offsetY = CGFloat(abs((seed &* 83492791) % 991)) / 991 * textureSpacing
                        let worldPoint = CGPoint(x: CGFloat(tileX) * textureSpacing + offsetX, y: CGFloat(tileY) * textureSpacing + offsetY)
                        let point = canvasPoint(worldPoint, cameraCenter: cameraCenter, viewCenter: viewCenter, scale: cellSize)
                        let radius = cellSize * (0.08 + CGFloat(abs(seed % 5)) * 0.025)
                        let fleck = CGRect(x: point.x, y: point.y, width: radius, height: radius)
                        context.fill(Path(ellipseIn: fleck), with: .color(seed.isMultiple(of: 2) ? .white.opacity(0.18) : Color(red: 0.55, green: 0.72, blue: 0.45).opacity(0.12)))
                    }
                }

                for orb in orbs where abs(orb.point.x - cameraCenter.x) < visibleHalfWidth + 2 && abs(orb.point.y - cameraCenter.y) < visibleHalfHeight + 2 {
                    drawOrb(orb, context: &context, cameraCenter: cameraCenter, viewCenter: viewCenter, scale: cellSize, cellSize: cellSize)
                }
                for chest in letterChests where abs(chest.point.x - cameraCenter.x) < visibleHalfWidth + 2 && abs(chest.point.y - cameraCenter.y) < visibleHalfHeight + 2 {
                    drawLetterChest(chest, phase: crawlPhase, context: &context, cameraCenter: cameraCenter, viewCenter: viewCenter, scale: cellSize, cellSize: cellSize)
                }
                for (index, rival) in rivals.enumerated() {
                    drawSnake(renderedSegments(rival.segments, pendingGrowth: rival.pendingGrowth, progress: rival.growthProgress), direction: rival.direction, headColor: rivalHeadColor(index), firstBodyColor: rivalColor(index), secondBodyColor: rivalAccentColor(index), context: &context, cameraCenter: cameraCenter, viewCenter: viewCenter, canvasSize: size, scale: cellSize, cellSize: cellSize)
                }
                drawSnake(renderedSnake, direction: directionVector, headColor: Color(red: 0.10, green: 0.42, blue: 0.27), firstBodyColor: Color(red: 0.20, green: 0.62, blue: 0.38), secondBodyColor: Color(red: 0.62, green: 0.88, blue: 0.38), context: &context, cameraCenter: cameraCenter, viewCenter: viewCenter, canvasSize: size, scale: cellSize, cellSize: cellSize)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard isPlaying else { return }
                        if steering.lastPoint == nil {
                            steering.lastPoint = value.startLocation
                        }

                        let previousPoint = steering.lastPoint ?? value.location
                        steering.pendingDelta.width += value.location.x - previousPoint.x
                        steering.pendingDelta.height += value.location.y - previousPoint.y
                        steering.lastPoint = value.location

                        let threshold = max(2.5, min(geometry.size.width, geometry.size.height) / Self.cameraViewUnits * 0.12)
                        let dx = steering.pendingDelta.width
                        let dy = steering.pendingDelta.height
                        let magnitude = sqrt(dx * dx + dy * dy)
                        guard magnitude >= threshold else { return }
                        steering.targetDirection = CGVector(dx: dx / magnitude, dy: dy / magnitude)
                        steering.pendingDelta = .zero
                    }
                    .onEnded { value in
                        let tapDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                        if tapDistance < 18 {
                            let now = Date()
                            if let lastTapAt = steering.lastTapAt, now.timeIntervalSince(lastTapAt) < 0.34 {
                                activateBoost()
                                steering.lastTapAt = nil
                            } else {
                                steering.lastTapAt = now
                            }
                        } else {
                            steering.lastTapAt = nil
                        }
                        steering.lastPoint = nil
                        steering.pendingDelta = .zero
                    }
            )
        }
        .overlay(alignment: .topTrailing) {
            mapCollectionHUD
        }
    }

    private var result: some View {
        VStack(spacing: 16) {
            Text(outcome?.contains("挑战完成") == true || finalRank == 1 ? "🏆" : "🐍")
                .font(.system(size: 72))
            Text(outcome ?? "这一局结束啦")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            Text(outcome?.contains("挑战完成") == true ? "字母收集完成 · 最终长度 \(finalLength) 节" : "最终长度 \(finalLength) 节 · 第 \(finalRank) 名")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    hasStarted = false
                    outcome = nil
                }
            } label: {
                Label("返回小蛇闯关", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
            .background(KidsTheme.mint, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(KidsTheme.yellow.opacity(0.55), lineWidth: 2))
        .shadow(color: KidsTheme.ink.opacity(0.08), radius: 18, x: 0, y: 9)
    }

    private func ruleCard(_ title: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(KidsTheme.ink)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.62), in: RoundedRectangle(cornerRadius: 11))
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
    }

    private func drawOrb(_ orb: SnakeOrb, context: inout GraphicsContext, cameraCenter: CGPoint, viewCenter: CGPoint, scale: CGFloat, cellSize: CGFloat) {
        let color: Color = orb.growth >= 8 ? KidsTheme.yellow : (orb.growth >= 3 ? KidsTheme.blue : KidsTheme.lilac)
        let radius = cellSize * (orb.growth >= 8 ? 0.48 : (orb.growth >= 3 ? 0.32 : 0.22))
        let center = canvasPoint(orb.point, cameraCenter: cameraCenter, viewCenter: viewCenter, scale: scale)
        let glowRadius = radius * 2.2
        let glow = CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        let core = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: glow), with: .color(color.opacity(0.20)))
        context.fill(Path(ellipseIn: core), with: .color(color))
        let shineRadius = radius * 0.34
        let shine = CGRect(x: center.x - radius * 0.24 - shineRadius, y: center.y - radius * 0.28 - shineRadius, width: shineRadius * 2, height: shineRadius * 2)
        context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.9)))
    }

    private func drawLetterChest(_ chest: SnakeLetterChest, phase: CGFloat, context: inout GraphicsContext, cameraCenter: CGPoint, viewCenter: CGPoint, scale: CGFloat, cellSize: CGFloat) {
        let center = canvasPoint(chest.point, cameraCenter: cameraCenter, viewCenter: viewCenter, scale: scale)
        let palette = chestPalette(for: chest.colorIndex)
        let glowRadius = cellSize * 1.68
        let glow = CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(Path(ellipseIn: glow), with: .color(palette.glow.opacity(0.32)))

        let bodyRect = CGRect(x: center.x - cellSize * 0.95, y: center.y - cellSize * 0.13, width: cellSize * 1.9, height: cellSize * 0.94)
        let lidRect = CGRect(x: center.x - cellSize * 1.04, y: center.y - cellSize * 0.64, width: cellSize * 2.08, height: cellSize * 0.55)
        let bodyPath = Path(roundedRect: bodyRect, cornerRadius: cellSize * 0.18)
        let lidPath = Path(roundedRect: lidRect, cornerRadius: cellSize * 0.19)
        context.fill(bodyPath, with: .linearGradient(
            Gradient(colors: [palette.bodyLight, palette.bodyDark]),
            startPoint: CGPoint(x: bodyRect.minX, y: bodyRect.minY),
            endPoint: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY)
        ))
        context.fill(lidPath, with: .linearGradient(
            Gradient(colors: [palette.lidLight, palette.lidDark]),
            startPoint: CGPoint(x: lidRect.minX, y: lidRect.minY),
            endPoint: CGPoint(x: lidRect.maxX, y: lidRect.maxY)
        ))
        context.stroke(bodyPath, with: .color(palette.outline), lineWidth: cellSize * 0.065)
        context.stroke(lidPath, with: .color(palette.outline.opacity(0.9)), lineWidth: cellSize * 0.06)

        let buckle = CGRect(x: center.x - cellSize * 0.12, y: center.y + cellSize * 0.48, width: cellSize * 0.24, height: cellSize * 0.2)
        context.fill(Path(roundedRect: buckle, cornerRadius: cellSize * 0.07), with: .color(.white.opacity(0.88)))
        let lowercaseLetter = String(chest.letter).lowercased()
        let letterText = Text("\(chest.letter)\(lowercaseLetter)")
            .font(.system(size: cellSize * 0.78, weight: .black, design: .rounded))
            .foregroundColor(chest.colorIndex == 0 ? Color(red: 0.38, green: 0.22, blue: 0.04) : .white)
        context.draw(letterText, at: CGPoint(x: center.x, y: center.y + cellSize * 0.18))

        for (index, offset) in [CGPoint(x: -0.78, y: -0.58), CGPoint(x: 0.82, y: -0.52), CGPoint(x: 0.70, y: 0.48)].enumerated() {
            let sparkleCenter = CGPoint(x: center.x + offset.x * cellSize, y: center.y + offset.y * cellSize)
            let sparkleRadius = cellSize * (index == 1 ? 0.18 : 0.14)
            let shimmer = 0.55 + 0.4 * abs(sin(phase * 1.7 + CGFloat(index) * 1.8))
            var sparkle = Path()
            sparkle.move(to: CGPoint(x: sparkleCenter.x, y: sparkleCenter.y - sparkleRadius))
            sparkle.addLine(to: CGPoint(x: sparkleCenter.x, y: sparkleCenter.y + sparkleRadius))
            sparkle.move(to: CGPoint(x: sparkleCenter.x - sparkleRadius, y: sparkleCenter.y))
            sparkle.addLine(to: CGPoint(x: sparkleCenter.x + sparkleRadius, y: sparkleCenter.y))
            context.stroke(sparkle, with: .color(.white.opacity(shimmer)), style: StrokeStyle(lineWidth: cellSize * 0.08, lineCap: .round))
        }
    }

    private func chestPalette(for index: Int) -> SnakeChestPalette {
        let palettes = [
            SnakeChestPalette(lidLight: Color(red: 1, green: 0.96, blue: 0.58), lidDark: Color(red: 1, green: 0.70, blue: 0.12), bodyLight: Color(red: 1, green: 0.83, blue: 0.27), bodyDark: Color(red: 0.91, green: 0.48, blue: 0.04), outline: Color(red: 0.58, green: 0.31, blue: 0.03), glow: Color(red: 1, green: 0.77, blue: 0.12)),
            SnakeChestPalette(lidLight: Color(red: 1, green: 0.69, blue: 0.77), lidDark: Color(red: 0.91, green: 0.18, blue: 0.36), bodyLight: Color(red: 1, green: 0.42, blue: 0.56), bodyDark: Color(red: 0.70, green: 0.08, blue: 0.27), outline: Color(red: 0.49, green: 0.04, blue: 0.18), glow: Color(red: 1, green: 0.23, blue: 0.42)),
            SnakeChestPalette(lidLight: Color(red: 0.63, green: 0.90, blue: 1), lidDark: Color(red: 0.10, green: 0.56, blue: 0.91), bodyLight: Color(red: 0.27, green: 0.76, blue: 1), bodyDark: Color(red: 0.05, green: 0.36, blue: 0.76), outline: Color(red: 0.03, green: 0.25, blue: 0.55), glow: Color(red: 0.10, green: 0.69, blue: 1)),
            SnakeChestPalette(lidLight: Color(red: 0.87, green: 0.71, blue: 1), lidDark: Color(red: 0.58, green: 0.27, blue: 0.88), bodyLight: Color(red: 0.73, green: 0.48, blue: 1), bodyDark: Color(red: 0.40, green: 0.16, blue: 0.71), outline: Color(red: 0.28, green: 0.09, blue: 0.52), glow: Color(red: 0.65, green: 0.37, blue: 1)),
            SnakeChestPalette(lidLight: Color(red: 0.68, green: 1, blue: 0.75), lidDark: Color(red: 0.13, green: 0.68, blue: 0.34), bodyLight: Color(red: 0.31, green: 0.88, blue: 0.45), bodyDark: Color(red: 0.06, green: 0.48, blue: 0.24), outline: Color(red: 0.02, green: 0.34, blue: 0.16), glow: Color(red: 0.20, green: 0.88, blue: 0.39)),
            SnakeChestPalette(lidLight: Color(red: 1, green: 0.82, blue: 0.58), lidDark: Color(red: 0.96, green: 0.39, blue: 0.08), bodyLight: Color(red: 1, green: 0.59, blue: 0.22), bodyDark: Color(red: 0.77, green: 0.22, blue: 0.02), outline: Color(red: 0.55, green: 0.13, blue: 0.01), glow: Color(red: 1, green: 0.48, blue: 0.11))
        ]
        return palettes[index % palettes.count]
    }

    private func drawSnake(_ segments: [CGPoint], direction: CGVector, headColor: Color, firstBodyColor: Color, secondBodyColor: Color, context: inout GraphicsContext, cameraCenter: CGPoint, viewCenter: CGPoint, canvasSize: CGSize, scale: CGFloat, cellSize: CGFloat) {
        guard let head = segments.first else { return }
        let firstPoint = canvasPoint(head, cameraCenter: cameraCenter, viewCenter: viewCenter, scale: scale)
        let thicknessScale = snakeThicknessScale(for: segments.count)
        let margin = cellSize * 2
        let visibleRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: -margin, dy: -margin)
        if segments.count > 1 {
            for index in stride(from: segments.count - 1, through: 1, by: -1) {
                let point = canvasPoint(segments[index], cameraCenter: cameraCenter, viewCenter: viewCenter, scale: scale)
                guard visibleRect.contains(point) else { continue }
                let taper: CGFloat = index == segments.count - 1 ? 0.72 : (index == segments.count - 2 ? 0.88 : 1)
                let segmentColor = index.isMultiple(of: 2) ? secondBodyColor : firstBodyColor
                drawSnakeBall(at: point, radius: cellSize * 0.42 * thicknessScale * taper, color: segmentColor, context: &context, cellSize: cellSize)
            }
        }
        let headRadius = cellSize * 0.43 * thicknessScale
        if visibleRect.contains(firstPoint) {
            drawSnakeBall(at: firstPoint, radius: headRadius, color: headColor, context: &context, cellSize: cellSize)
            drawSnakeEyes(at: firstPoint, direction: direction, thicknessScale: thicknessScale, context: &context, cellSize: cellSize)
        }
    }

    private func snakeThicknessScale(for segmentCount: Int) -> CGFloat {
        1 + min(0.18, CGFloat(max(0, segmentCount - 7)) * 0.0025)
    }

    private func drawSnakeBall(at center: CGPoint, radius: CGFloat, color: Color, context: inout GraphicsContext, cellSize: CGFloat) {
        let shadowRect = CGRect(x: center.x - radius, y: center.y - radius + cellSize * 0.09, width: radius * 2, height: radius * 2)
        let ballRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: shadowRect), with: .color(KidsTheme.ink.opacity(0.18)))
        context.fill(
            Path(ellipseIn: ballRect),
            with: .linearGradient(
                Gradient(colors: [color.opacity(0.78), color, color.opacity(0.88)]),
                startPoint: CGPoint(x: ballRect.minX, y: ballRect.minY),
                endPoint: CGPoint(x: ballRect.maxX, y: ballRect.maxY)
            )
        )
        context.stroke(Path(ellipseIn: ballRect), with: .color(color.opacity(0.72)), lineWidth: cellSize * 0.045)

        let shineRect = CGRect(x: center.x - radius * 0.62, y: center.y - radius * 0.62, width: radius * 0.88, height: radius * 0.48)
        context.fill(Path(ellipseIn: shineRect), with: .color(.white.opacity(0.44)))
    }

    private func rivalColor(_ index: Int) -> Color {
        let colors = [KidsTheme.orange, KidsTheme.lilac, KidsTheme.blue, KidsTheme.red, Color(red: 0.78, green: 0.66, blue: 0.20)]
        return colors[index % colors.count]
    }

    private func rivalAccentColor(_ index: Int) -> Color {
        let colors = [
            Color(red: 1, green: 0.79, blue: 0.36),
            Color(red: 0.98, green: 0.56, blue: 0.83),
            Color(red: 0.35, green: 0.88, blue: 0.96),
            Color(red: 1, green: 0.59, blue: 0.39),
            Color(red: 0.62, green: 0.91, blue: 0.47)
        ]
        return colors[index % colors.count]
    }

    private func rivalHeadColor(_ index: Int) -> Color {
        let colors = [
            Color(red: 0.78, green: 0.31, blue: 0.08),
            Color(red: 0.43, green: 0.25, blue: 0.66),
            Color(red: 0.05, green: 0.39, blue: 0.67),
            Color(red: 0.69, green: 0.12, blue: 0.22),
            Color(red: 0.48, green: 0.43, blue: 0.12)
        ]
        return colors[index % colors.count]
    }

    private func drawSnakeEyes(at head: CGPoint, direction: CGVector, thicknessScale: CGFloat, context: inout GraphicsContext, cellSize: CGFloat) {
        let forwardDistance = cellSize * 0.16 * thicknessScale
        let sideDistance = cellSize * 0.19 * thicknessScale
        let eyeRadius = cellSize * 0.10 * thicknessScale
        let pupilRadius = eyeRadius * 0.53
        let perpendicular = CGVector(dx: -direction.dy, dy: direction.dx)
        for side in [CGFloat(-1), CGFloat(1)] {
            let eyeCenter = CGPoint(
                x: head.x + direction.dx * forwardDistance + perpendicular.dx * sideDistance * side,
                y: head.y + direction.dy * forwardDistance + perpendicular.dy * sideDistance * side
            )
            let eye = CGRect(x: eyeCenter.x - eyeRadius, y: eyeCenter.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2)
            context.fill(Path(ellipseIn: eye), with: .color(.white))
            let pupilCenter = CGPoint(x: eyeCenter.x + direction.dx * eyeRadius * 0.18, y: eyeCenter.y + direction.dy * eyeRadius * 0.18)
            let pupil = CGRect(x: pupilCenter.x - pupilRadius, y: pupilCenter.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2)
            context.fill(Path(ellipseIn: pupil), with: .color(KidsTheme.ink))
        }
    }

    private func canvasPoint(_ point: CGPoint, cameraCenter: CGPoint, viewCenter: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: viewCenter.x + (point.x - cameraCenter.x) * scale, y: viewCenter.y + (point.y - cameraCenter.y) * scale)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard magnitude > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)
    }

    private func startGame() {
        if !Self.freePlayForTesting {
            guard app.spendSnakeTicket() else { return }
        }
        alphabetSpeech.stop()
        rewardLetter = nil
        rewardLetterNameTapCount = 0
        rewardLetterExampleTapCount = 0
        collectedLetters = []
        snake = makeSegments(start: .zero, direction: CGVector(dx: 1, dy: 0), count: 7)
        rivals = makeStartingRivals()
        orbs = makeStartingOrbs(avoiding: snake + rivals.flatMap(\.segments))
        letterChests = makeStartingLetterChests(avoiding: snake + rivals.flatMap(\.segments) + orbs.map(\.point))
        directionVector = CGVector(dx: 1, dy: 0)
        steering.reset(direction: directionVector)
        pendingGrowth = 0
        growthProgress = 0
        crawlPhase = 0
        boostRemaining = 0
        boostCooldown = 0
        finalLength = 0
        finalRank = 1
        orbRefillTimer = 0
        rivalRespawnTimer = 0
        chestRespawnTimer = 0
        timeUntilNextChest = Self.initialChestDeadline
        chestTimerAccumulator.elapsed = 0
        isChestDeadlineActive = true
        outcome = nil
        hasStarted = true
        isPlaying = true
    }

    private var canStartGame: Bool {
        Self.freePlayForTesting || app.snakeRewardStatus.ticketCount > 0
    }

    private func activateBoost() {
        guard isPlaying, boostCooldown <= 0 else { return }
        boostRemaining = 0.85
        boostCooldown = 2.6
    }

    private func makeRivalPlan(
        for rival: SnakeRival,
        among rivals: [SnakeRival],
        playerSegments: [CGPoint],
        playerDirection: CGVector,
        orbs: [SnakeOrb]
    ) -> SnakeAIPlan {
        guard let head = rival.segments.first else {
            return SnakeAIPlan(tactic: .foraging, direction: rival.direction, targetID: nil, targetsPlayer: false)
        }

        var targets = [SnakeAITarget(id: nil, isPlayer: true, segments: playerSegments, direction: playerDirection)]
        targets.append(contentsOf: rivals.compactMap { other in
            guard other.id != rival.id, !other.segments.isEmpty else { return nil }
            return SnakeAITarget(id: other.id, isPlayer: false, segments: other.segments, direction: other.direction)
        })

        let targetScore: (SnakeAITarget) -> CGFloat = { target in
            let isCurrentTarget = target.isPlayer
                ? rival.targetsPlayer && rival.targetRivalID == nil
                : !rival.targetsPlayer && rival.targetRivalID == target.id
            return distance(head, target.segments[0]) * (isCurrentTarget ? 0.78 : 1)
        }
        if let target = targets
            .filter({ distance(head, $0.segments[0]) < 18 })
            .min(by: { targetScore($0) < targetScore($1) }),
           let targetHead = target.segments.first {
            let targetDistance = distance(head, targetHead)
            let lengthDifference = rival.segments.count - target.segments.count
            let destination: CGPoint
            let tactic: SnakeTactic

            if lengthDifference <= -3 && targetDistance < 18 {
                tactic = .tailing
                let tail = target.segments.last ?? targetHead
                destination = CGPoint(x: tail.x - target.direction.dx * 1.8, y: tail.y - target.direction.dy * 1.8)
            } else if lengthDifference >= 3 && targetDistance < 16 {
                tactic = .encircling
                let angleToRival = atan2(head.y - targetHead.y, head.x - targetHead.x)
                let orbitAngle = angleToRival + rival.orbitDirection * 1.05
                let orbitRadius = max(1.9, min(4.8, targetDistance * 0.82) - rival.tacticDuration * 0.16)
                destination = CGPoint(x: targetHead.x + cos(orbitAngle) * orbitRadius, y: targetHead.y + sin(orbitAngle) * orbitRadius)
            } else if targetDistance < 13 {
                tactic = .overtaking
                let side = rival.orbitDirection
                let perpendicular = CGVector(dx: -target.direction.dy, dy: target.direction.dx)
                destination = CGPoint(
                    x: targetHead.x + target.direction.dx * 2.4 + perpendicular.dx * side * 1.35,
                    y: targetHead.y + target.direction.dy * 2.4 + perpendicular.dy * side * 1.35
                )
            } else {
                tactic = .foraging
                let orb = bestOrb(for: rival, among: orbs)
                let targetPoint = orb?.point ?? randomWanderPoint(from: head, direction: rival.direction)
                return SnakeAIPlan(tactic: tactic, direction: normalized(CGVector(dx: targetPoint.x - head.x, dy: targetPoint.y - head.y)), targetID: nil, targetsPlayer: false)
            }

            return SnakeAIPlan(
                tactic: tactic,
                direction: normalized(CGVector(dx: destination.x - head.x, dy: destination.y - head.y)),
                targetID: target.id,
                targetsPlayer: target.isPlayer
            )
        }

        let orb = bestOrb(for: rival, among: orbs)
        let targetPoint = orb?.point ?? randomWanderPoint(from: head, direction: rival.direction)
        return SnakeAIPlan(tactic: .foraging, direction: normalized(CGVector(dx: targetPoint.x - head.x, dy: targetPoint.y - head.y)), targetID: nil, targetsPlayer: false)
    }

    private func bestOrb(for rival: SnakeRival, among orbs: [SnakeOrb]) -> SnakeOrb? {
        guard let head = rival.segments.first else { return nil }
        return orbs.min { first, second in
            distance(head, first.point) / sqrt(CGFloat(first.growth)) < distance(head, second.point) / sqrt(CGFloat(second.growth))
        }
    }

    private func randomWanderPoint(from head: CGPoint, direction: CGVector) -> CGPoint {
        let angle = atan2(direction.dy, direction.dx) + CGFloat.random(in: -1.2...1.2)
        return CGPoint(x: head.x + cos(angle) * 8, y: head.y + sin(angle) * 8)
    }

    private func moveSnake(deltaTime: CGFloat) {
        guard let head = snake.first else { return }
        if isChestDeadlineActive {
            chestTimerAccumulator.elapsed += deltaTime
            if chestTimerAccumulator.elapsed >= 1 {
                let elapsedSeconds = floor(chestTimerAccumulator.elapsed)
                chestTimerAccumulator.elapsed -= elapsedSeconds
                timeUntilNextChest = max(0, timeUntilNextChest - elapsedSeconds)
            }
            if timeUntilNextChest <= 0 {
                finish("时限内没有吃到下一个字母宝箱，挑战失败", died: true)
                return
            }
        }
        crawlPhase = (crawlPhase + deltaTime * 8).truncatingRemainder(dividingBy: 2 * .pi)
        boostRemaining = max(0, boostRemaining - deltaTime)
        boostCooldown = max(0, boostCooldown - deltaTime)
        directionVector = turnedDirection(from: directionVector, toward: steering.targetDirection, deltaTime: deltaTime)
        var updatedSnake = advance(snake, direction: directionVector, speed: currentSpeed, deltaTime: deltaTime)
        guard let nextHead = updatedSnake.first else { return }

        guard !hitsBody(nextHead, body: snake, ignoringFirst: 5) else {
            finish("撞到自己的身体啦", died: true)
            return
        }

        var updatedOrbs = orbs
        var updatedChests = letterChests
        var updatedRivals = rivals
        var deadRivalIDs = Set<UUID>()

        for index in updatedRivals.indices {
            var rival = updatedRivals[index]
            guard !rival.segments.isEmpty else { continue }
            rival.turnTimer -= deltaTime
            if rival.turnTimer <= 0 {
                let plan = makeRivalPlan(for: rival, among: updatedRivals, playerSegments: updatedSnake, playerDirection: directionVector, orbs: updatedOrbs)
                if rival.tactic != plan.tactic {
                    rival.tacticDuration = 0
                }
                rival.tactic = plan.tactic
                rival.targetRivalID = plan.targetID
                rival.targetsPlayer = plan.targetsPlayer
                rival.targetDirection = plan.direction
                if plan.tactic == .overtaking && rival.boostCooldown <= 0 {
                    rival.boostRemaining = 0.7
                    rival.boostCooldown = 2.8
                }
                rival.turnTimer = CGFloat.random(in: 0.55...0.9)
            }
            rival.tacticDuration += deltaTime
            rival.boostRemaining = max(0, rival.boostRemaining - deltaTime)
            rival.boostCooldown = max(0, rival.boostCooldown - deltaTime)
            rival.direction = turnedDirection(from: rival.direction, toward: rival.targetDirection, deltaTime: deltaTime)
            let rivalBaseSpeed: CGFloat = rival.boostRemaining > 0 ? 5.6 : 3.7
            let rivalLengthBonus = min(0.65, CGFloat(max(0, rival.segments.count - 8)) * 0.01)
            let rivalSpeed = rivalBaseSpeed + rivalLengthBonus
            rival.segments = advance(rival.segments, direction: rival.direction, speed: rivalSpeed, deltaTime: deltaTime)
            advanceGrowth(&rival.segments, pendingGrowth: &rival.pendingGrowth, progress: &rival.growthProgress, deltaTime: deltaTime)
            guard let movedHead = rival.segments.first else { continue }

            let rivalHitSelf = hitsBody(movedHead, body: rival.segments, ignoringFirst: 5)
            let rivalHitPlayer = touchesSnake(movedHead, body: updatedSnake)
            let rivalHitRival = updatedRivals.enumerated().contains { otherIndex, other in
                otherIndex != index && hitsBody(movedHead, body: other.segments, ignoringFirst: 3)
            }
            updatedRivals[index] = rival
            if rivalHitSelf || rivalHitPlayer || rivalHitRival {
                updatedOrbs.append(contentsOf: droppedOrbs(from: rival.segments, avoiding: updatedOrbs.map(\.point)))
                deadRivalIDs.insert(rival.id)
            }
        }

        let playerHitRival = updatedRivals.contains { rival in
            touchesSnake(nextHead, body: rival.segments)
        }
        if playerHitRival {
            orbs = updatedOrbs
            snake = updatedSnake
            rivals = updatedRivals.filter { !deadRivalIDs.contains($0.id) }
            finish("撞到其他蛇的身体啦", died: true)
            return
        }
        updatedRivals.removeAll { deadRivalIDs.contains($0.id) }

        if let chestIndex = updatedChests.firstIndex(where: { distance(nextHead, $0.point) < 1.4 }) {
            let chest = updatedChests.remove(at: chestIndex)
            pendingGrowth += 3
            if let letter = AlphabetCatalog.all.first(where: { $0.id == String(chest.letter) }) {
                collectedLetters.insert(letter.id)
                rewardLetter = letter
                rewardLetterNameTapCount = 0
                rewardLetterExampleTapCount = 0
                app.recordAlphabetStudy(letter: letter.id)
                isPlaying = false
            }
        }

        for index in updatedRivals.indices {
            guard let rivalHead = updatedRivals[index].segments.first else { continue }
            var rivalChestCount = 0
            updatedChests.removeAll { chest in
                guard distance(rivalHead, chest.point) < 1.4 else { return false }
                rivalChestCount += 1
                return true
            }
            updatedRivals[index].pendingGrowth += rivalChestCount * 3
        }

        var collectedGrowth = 0
        updatedOrbs.removeAll { orb in
            guard distance(nextHead, orb.point) < (orb.growth >= 8 ? 0.82 : 0.62) else { return false }
            collectedGrowth += orb.growth
            return true
        }
        if collectedGrowth > 0 {
            pendingGrowth += collectedGrowth
        }

        for index in updatedRivals.indices {
            guard let rivalHead = updatedRivals[index].segments.first else { continue }
            var rivalGrowth = 0
            updatedOrbs.removeAll { orb in
                guard distance(rivalHead, orb.point) < (orb.growth >= 8 ? 0.82 : 0.62) else { return false }
                rivalGrowth += orb.growth
                return true
            }
            if rivalGrowth > 0 {
                updatedRivals[index].pendingGrowth += rivalGrowth
            }
        }

        // Keep food and rival snakes in the camera's nearby play area.
        if let playerHead = updatedSnake.first {
            updatedOrbs.removeAll { distance($0.point, playerHead) > 44 }
            updatedChests.removeAll { distance($0.point, playerHead) > 42 }
            updatedRivals.removeAll { rival in
                guard let rivalHead = rival.segments.first else { return true }
                return distance(rivalHead, playerHead) > 22
            }
        }

        orbRefillTimer -= deltaTime
        if updatedOrbs.count < Self.targetOrbCount && orbRefillTimer <= 0 {
            var occupiedPoints = updatedSnake + updatedRivals.flatMap(\.segments) + updatedOrbs.map(\.point)
            let refillCount = min(Self.orbRefillBatchSize, Self.targetOrbCount - updatedOrbs.count)
            for _ in 0..<refillCount {
                let roll = Int.random(in: 0..<100)
                let growth = roll < 4 ? 8 : (roll < 28 ? 3 : 1)
                let point = randomFoodPoint(avoiding: occupiedPoints, around: updatedSnake.first ?? .zero, radius: 30)
                occupiedPoints.append(point)
                updatedOrbs.append(SnakeOrb(
                    point: point,
                    growth: growth
                ))
            }
            orbRefillTimer = 0.5
        }
        if updatedRivals.count < Self.targetRivalCount {
            rivalRespawnTimer += deltaTime
            if rivalRespawnTimer >= 1.8 {
                updatedRivals.append(makeRival(colorIndex: Int.random(in: 0..<5), avoiding: updatedSnake + updatedRivals.flatMap(\.segments)))
                rivalRespawnTimer = 0
            }
        } else {
            rivalRespawnTimer = 0
        }

        if updatedChests.count < Self.targetLetterChestCount {
            chestRespawnTimer += deltaTime
            if chestRespawnTimer >= 2.0 {
                let occupiedPoints = updatedSnake + updatedRivals.flatMap(\.segments) + updatedOrbs.map(\.point) + updatedChests.map(\.point)
                let availableColors = (0..<Self.chestPaletteCount).filter { colorIndex in
                    !updatedChests.contains { $0.colorIndex == colorIndex }
                }
                let colorIndex = availableColors.randomElement() ?? Int.random(in: 0..<Self.chestPaletteCount)
                let activeLetters = Set(updatedChests.map(\.letter))
                if let letter = uncollectedChestLetters(excluding: activeLetters).randomElement() {
                    updatedChests.append(makeLetterChest(letter: letter, avoiding: occupiedPoints, around: updatedSnake.first ?? .zero, radius: 22, colorIndex: colorIndex))
                }
                chestRespawnTimer = 0
            }
        } else {
            chestRespawnTimer = 0
        }

        advanceGrowth(&updatedSnake, pendingGrowth: &pendingGrowth, progress: &growthProgress, deltaTime: deltaTime)

        snake = updatedSnake
        rivals = updatedRivals
        orbs = updatedOrbs
        letterChests = updatedChests
    }

    private func makeStartingRivals() -> [SnakeRival] {
        (0..<Self.targetRivalCount).map { index in
            let angle = CGFloat(index) * (2 * .pi / CGFloat(Self.targetRivalCount)) + CGFloat.random(in: -0.18...0.18)
            let radius = CGFloat.random(in: 9...13)
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            let center = CGPoint.zero
            let direction = normalized(CGVector(dx: center.x - point.x, dy: center.y - point.y))
            return SnakeRival(
                segments: makeSegments(start: point, direction: direction, count: Int.random(in: 7...10)),
                direction: direction,
                targetDirection: direction,
                turnTimer: CGFloat.random(in: 0.4...1.2),
                colorIndex: index,
                orbitDirection: Bool.random() ? 1 : -1
            )
        }
    }

    private func makeRival(colorIndex: Int, avoiding occupied: [CGPoint]) -> SnakeRival {
        let center = snake.first ?? .zero
        var point = randomPoint(avoiding: occupied, around: center, radius: 13)
        for _ in 0..<25 where occupied.contains(where: { distance(point, $0) < 4 }) {
            point = randomPoint(avoiding: occupied, around: center, radius: 13)
        }
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        return SnakeRival(segments: makeSegments(start: point, direction: direction, count: Int.random(in: 6...9)), direction: direction, targetDirection: direction, turnTimer: 1, colorIndex: colorIndex, orbitDirection: Bool.random() ? 1 : -1)
    }

    private func makeSegments(start: CGPoint, direction: CGVector, count: Int) -> [CGPoint] {
        (0..<count).map { index in
            CGPoint(x: start.x - direction.dx * Self.segmentSpacing * CGFloat(index), y: start.y - direction.dy * Self.segmentSpacing * CGFloat(index))
        }
    }

    private func makeStartingOrbs(avoiding occupied: [CGPoint]) -> [SnakeOrb] {
        var result: [SnakeOrb] = []
        for _ in 0..<Self.targetOrbCount {
            let roll = Int.random(in: 0..<100)
            let growth = roll < 7 ? 8 : (roll < 27 ? 3 : 1)
            result.append(SnakeOrb(point: randomFoodPoint(avoiding: occupied + result.map(\.point), around: .zero, radius: 30), growth: growth))
        }
        return result
    }

    private func randomFoodPoint(avoiding occupied: [CGPoint], around center: CGPoint, radius: CGFloat) -> CGPoint {
        var bestPoint = CGPoint(x: center.x + CGFloat.random(in: -radius...radius), y: center.y + CGFloat.random(in: -radius...radius))
        var bestClearance: CGFloat = -1

        for _ in 0..<40 {
            let candidate = CGPoint(x: center.x + CGFloat.random(in: -radius...radius), y: center.y + CGFloat.random(in: -radius...radius))
            let clearance = occupied.map { distance(candidate, $0) }.min() ?? .greatestFiniteMagnitude
            if clearance >= 1.9 { return candidate }
            if clearance > bestClearance {
                bestPoint = candidate
                bestClearance = clearance
            }
        }

        return bestPoint
    }

    private func makeStartingLetterChests(avoiding occupied: [CGPoint]) -> [SnakeLetterChest] {
        var result: [SnakeLetterChest] = []
        for _ in 0..<Self.targetLetterChestCount {
            let activeLetters = Set(result.map(\.letter))
            guard let letter = uncollectedChestLetters(excluding: activeLetters).randomElement() else { break }
            result.append(makeLetterChest(letter: letter, avoiding: occupied + result.map(\.point), around: .zero, radius: 20, colorIndex: result.count))
        }
        return result
    }

    private func uncollectedChestLetters(excluding activeLetters: Set<Character>) -> [Character] {
        AlphabetCatalog.all.compactMap { letter in
            guard let character = letter.id.first,
                  !collectedLetters.contains(letter.id),
                  !activeLetters.contains(character) else { return nil }
            return character
        }
    }

    private func makeLetterChest(letter: Character, avoiding occupied: [CGPoint], around center: CGPoint, radius: CGFloat, colorIndex: Int) -> SnakeLetterChest {
        let point = randomPoint(avoiding: occupied, around: center, radius: radius)
        return SnakeLetterChest(point: point, letter: letter, colorIndex: colorIndex)
    }

    private func randomPoint(avoiding occupied: [CGPoint], around center: CGPoint, radius: CGFloat) -> CGPoint {
        for _ in 0..<80 {
            let point = CGPoint(x: center.x + CGFloat.random(in: -radius...radius), y: center.y + CGFloat.random(in: -radius...radius))
            if occupied.allSatisfy({ distance(point, $0) > 0.8 }) { return point }
        }
        return CGPoint(x: center.x + CGFloat.random(in: -radius...radius), y: center.y + CGFloat.random(in: -radius...radius))
    }

    private func droppedOrbs(from segments: [CGPoint], avoiding occupied: [CGPoint] = []) -> [SnakeOrb] {
        guard !segments.isEmpty else { return [] }
        let count = max(10, min(36, segments.count * 2))
        var placedPoints = occupied
        var result: [SnakeOrb] = []
        for index in 0..<count {
            let source = segments[index % segments.count]
            var bestPoint = source
            var bestClearance: CGFloat = -.infinity
            for _ in 0..<18 {
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let radius = CGFloat.random(in: 0.9...2.4)
                let candidate = CGPoint(x: source.x + cos(angle) * radius, y: source.y + sin(angle) * radius)
                let clearance = placedPoints.map { distance(candidate, $0) }.min() ?? .greatestFiniteMagnitude
                if clearance > bestClearance {
                    bestPoint = candidate
                    bestClearance = clearance
                }
                if clearance >= 0.9 {
                    bestPoint = candidate
                    break
                }
            }
            placedPoints.append(bestPoint)
            let growth = index.isMultiple(of: 11) ? 8 : (index.isMultiple(of: 3) ? 3 : 1)
            result.append(SnakeOrb(point: bestPoint, growth: growth))
        }
        return result
    }

    private func advance(_ segments: [CGPoint], direction: CGVector, speed: CGFloat, deltaTime: CGFloat) -> [CGPoint] {
        guard let head = segments.first else { return segments }
        var updated = segments
        updated[0] = CGPoint(x: head.x + direction.dx * speed * deltaTime, y: head.y + direction.dy * speed * deltaTime)
        for index in 1..<updated.count {
            let leader = updated[index - 1]
            let follower = updated[index]
            let dx = follower.x - leader.x
            let dy = follower.y - leader.y
            let gap = sqrt(dx * dx + dy * dy)
            guard gap > 0.0001 else { continue }
            updated[index] = CGPoint(x: leader.x + dx / gap * Self.segmentSpacing, y: leader.y + dy / gap * Self.segmentSpacing)
        }
        return updated
    }

    private func grow(_ segments: inout [CGPoint], by amount: Int) {
        guard let tail = segments.last, segments.count > 1 else { return }
        let previous = segments[segments.count - 2]
        let tailDirection = normalized(CGVector(dx: tail.x - previous.x, dy: tail.y - previous.y))
        for index in 0..<amount {
            let offset = Self.segmentSpacing * CGFloat(index + 1)
            segments.append(CGPoint(x: tail.x + tailDirection.dx * offset, y: tail.y + tailDirection.dy * offset))
        }
    }

    private func renderedSegments(_ segments: [CGPoint], pendingGrowth: Int, progress: CGFloat) -> [CGPoint] {
        guard pendingGrowth > 0, progress > 0, let tail = segments.last, segments.count > 1 else { return segments }
        let previous = segments[segments.count - 2]
        let tailDirection = normalized(CGVector(dx: tail.x - previous.x, dy: tail.y - previous.y))
        let extensionDistance = Self.segmentSpacing * min(progress, 1)
        return segments + [CGPoint(x: tail.x + tailDirection.dx * extensionDistance, y: tail.y + tailDirection.dy * extensionDistance)]
    }

    private func advanceGrowth(_ segments: inout [CGPoint], pendingGrowth: inout Int, progress: inout CGFloat, deltaTime: CGFloat) {
        guard pendingGrowth > 0 else {
            progress = 0
            return
        }
        progress += deltaTime * 3
        let completedSegments = min(pendingGrowth, Int(progress))
        guard completedSegments > 0 else { return }
        grow(&segments, by: completedSegments)
        pendingGrowth -= completedSegments
        progress -= CGFloat(completedSegments)
        if pendingGrowth == 0 {
            progress = 0
        }
    }

    private func turnedDirection(from current: CGVector, toward target: CGVector, deltaTime: CGFloat) -> CGVector {
        let currentAngle = atan2(current.dy, current.dx)
        let targetAngle = atan2(target.dy, target.dx)
        var angleDifference = targetAngle - currentAngle
        while angleDifference > .pi { angleDifference -= 2 * .pi }
        while angleDifference < -.pi { angleDifference += 2 * .pi }
        let maximumTurn = Self.maximumTurnRate * deltaTime
        let turnAmount = min(max(angleDifference, -maximumTurn), maximumTurn)
        let angle = currentAngle + turnAmount
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    private func hitsBody(_ point: CGPoint, body: [CGPoint], ignoringFirst count: Int) -> Bool {
        body.dropFirst(min(count, body.count)).contains { distance(point, $0) < 0.52 }
    }

    private func touchesSnake(_ point: CGPoint, body: [CGPoint]) -> Bool {
        guard !body.isEmpty else { return false }
        let collisionRadius: CGFloat = 0.82
        if body.contains(where: { distance(point, $0) < collisionRadius }) {
            return true
        }
        guard body.count > 1 else { return false }
        for index in 0..<(body.count - 1) {
            if distance(point, toSegmentFrom: body[index], to: body[index + 1]) < collisionRadius {
                return true
            }
        }
        return false
    }

    private func distance(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let segmentX = end.x - start.x
        let segmentY = end.y - start.y
        let lengthSquared = segmentX * segmentX + segmentY * segmentY
        guard lengthSquared > 0.0001 else { return distance(point, start) }
        let projection = ((point.x - start.x) * segmentX + (point.y - start.y) * segmentY) / lengthSquared
        let progress = min(max(projection, 0), 1)
        let nearestPoint = CGPoint(x: start.x + segmentX * progress, y: start.y + segmentY * progress)
        return distance(point, nearestPoint)
    }

    private func finish(_ message: String, died: Bool = false) {
        outcome = message
        finalLength = snake.count
        finalRank = playerRank
        if died {
            orbs.append(contentsOf: droppedOrbs(from: snake, avoiding: orbs.map(\.point)))
            snake = []
        }
        isPlaying = false
    }
}
