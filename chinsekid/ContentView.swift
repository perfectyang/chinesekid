import SwiftUI

private enum AppPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let paper = KidsTheme.paper
    static let orange = KidsTheme.orange
    static let yellow = KidsTheme.yellow
    static let mint = KidsTheme.mint
    static let lilac = KidsTheme.lilac
    static let blue = KidsTheme.blue
}

private struct StudySession: Identifiable {
    let id = UUID()
    let startingGlyph: String?
    let visibleOrder: [String]
}

private enum ContentSheet: String, Identifiable {
    case importCharacters
    case manualEntry
    case profiles
    case homeModules

    var id: String { rawValue }

    var detents: Set<PresentationDetent> {
        switch self {
        case .importCharacters, .manualEntry:
            [.large]
        case .profiles:
            [.medium, .large]
        case .homeModules:
            [.medium]
        }
    }
}

struct ContentView: View {
    @StateObject private var app = AppModel()
    @State private var selectedTab = 0
    @State private var studySession: StudySession?
    @State private var showingListeningGame = false
    @State private var showingArithmeticGame = false
    @State private var showingEquationBalanceGame = false
    @State private var showingPinyinModule = false
    @State private var showingHanziDecomposition = false
    @State private var showingAlphabetModule = false
    @State private var showingSnakeGame = false
    @State private var showingFishGame = false
    @State private var showingSnakeTicketPractice = false
    @State private var showingParentFishSettings = false
    @State private var activeSheet: ContentSheet?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            StorybookBackground()
            Group {
                if selectedTab == 0 {
                    HomeScreen(
                        app: app,
                        startStudy: { beginStudy() },
                        openCharacter: { glyph, visibleOrder in
                            beginStudy(startingWith: glyph, visibleOrder: visibleOrder)
                        },
                        startListeningGame: { showingListeningGame = true },
                        startArithmeticGame: { showingArithmeticGame = true },
                        startEquationBalanceGame: { showingEquationBalanceGame = true },
                        startPinyinModule: { showingPinyinModule = true },
                        startHanziDecomposition: { showingHanziDecomposition = true },
                        startAlphabetModule: { showingAlphabetModule = true },
                        startSnakeGame: {
                            app.refreshSnakeRewardStatus()
                            if app.snakeRewardStatus.hasTicket {
                                showingSnakeGame = true
                            } else {
                                showingSnakeTicketPractice = true
                            }
                        },
                        startFishGame: {
                            app.refreshSnakeRewardStatus()
                            showingFishGame = true
                        },
                        openHomeModuleSettings: { activeSheet = .homeModules },
                        showLibrary: { selectedTab = 1 },
                        importWords: { activeSheet = .importCharacters },
                        manualEntry: { activeSheet = .manualEntry },
                        chooseProfile: { activeSheet = .profiles },
                        openParentFishSettings: { showingParentFishSettings = true }
                    )
                } else {
                    LibraryScreen(app: app, startStudy: { glyph, visibleOrder in
                        beginStudy(startingWith: glyph, visibleOrder: visibleOrder)
                    })
                }
            }
        }
        .tint(AppPalette.orange)
        // The app uses a fixed light palette; keep system text controls readable
        // when the iPad itself is set to Dark Mode.
        .preferredColorScheme(.light)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigation(selectedTab: $selectedTab)
        }
        .fullScreenCover(item: $studySession) { session in
            StudyScreen(app: app, initialGlyph: session.startingGlyph, visibleOrder: session.visibleOrder)
                .id(session.id)
        }
        .fullScreenCover(isPresented: $showingListeningGame) {
            ListeningGameFlowScreen(app: app) {
                showingListeningGame = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    activeSheet = .importCharacters
                }
            }
        }
        .fullScreenCover(isPresented: $showingArithmeticGame) {
            ArithmeticGameScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingEquationBalanceGame) {
            EquationBalanceGameScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingPinyinModule) {
            PinyinModuleScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingHanziDecomposition) {
            HanziDecompositionModuleScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingAlphabetModule) {
            AlphabetModuleScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingSnakeGame) {
            SnakeGameScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingFishGame) {
            FishGameScreen(app: app)
        }
        .fullScreenCover(isPresented: $showingSnakeTicketPractice) {
            AlphabetModuleScreen(
                app: app,
                snakeTicketPractice: true,
                onSnakeTicketEarned: {
                    showingSnakeTicketPractice = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showingSnakeGame = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingParentFishSettings) {
            ParentFishSettingsScreen(app: app)
        }
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .importCharacters:
                    OCRImportScreen(app: app)
                case .manualEntry:
                    ManualCharacterEntryScreen(app: app)
                case .profiles:
                    ProfileScreen(app: app)
                case .homeModules:
                    HomeModuleSettingsSheet(app: app)
                }
            }
            .presentationDetents(sheet.detents)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .alert("暂时打不开小字典", isPresented: Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.errorMessage = nil } }
        )) {
            Button("知道啦", role: .cancel) { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "请稍后再试。")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { app.refreshSnakeRewardStatus() }
        }
    }

    private func beginStudy(startingWith glyph: String? = nil, visibleOrder: [String] = []) {
        studySession = StudySession(startingGlyph: glyph, visibleOrder: visibleOrder)
    }

}

private struct HomeScreen: View {
    @ObservedObject var app: AppModel
    let startStudy: () -> Void
    let openCharacter: (String, [String]) -> Void
    let startListeningGame: () -> Void
    let startArithmeticGame: () -> Void
    let startEquationBalanceGame: () -> Void
    let startPinyinModule: () -> Void
    let startHanziDecomposition: () -> Void
    let startAlphabetModule: () -> Void
    let startSnakeGame: () -> Void
    let startFishGame: () -> Void
    let openHomeModuleSettings: () -> Void
    let showLibrary: () -> Void
    let importWords: () -> Void
    let manualEntry: () -> Void
    let chooseProfile: () -> Void
    let openParentFishSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("嗨，\(app.currentUser.name)！")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                        Text("今天也来发现汉字宝藏吧")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppPalette.muted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: openHomeModuleSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppPalette.ink)
                                .frame(width: 46, height: 46)
                                .background(.white.opacity(0.82), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("首页模块设置")
                        ProfileAvatarView(user: app.currentUser, size: 48)
                            .frame(width: 52, height: 52)
                            .contentShape(Circle())
                            .onTapGesture(perform: chooseProfile)
                            .onLongPressGesture(minimumDuration: 3, perform: openParentFishSettings)
                            .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("切换小朋友档案")
                    }
                }

                if app.isHomeModuleVisible(.hanziExploration) {
                    AdventureBanner(startStudy: startStudy)
                }

                if app.isHomeModuleVisible(.listening) {
                    ListeningGameBanner(action: startListeningGame)
                }
                if app.isHomeModuleVisible(.arithmetic) {
                    ArithmeticGameBanner(action: startArithmeticGame)
                }
                if app.isHomeModuleVisible(.equationBalance) {
                    EquationBalanceGameBanner(action: startEquationBalanceGame)
                }
                if app.isHomeModuleVisible(.pinyin) {
                    PinyinModuleBanner(action: startPinyinModule)
                }
                if app.isHomeModuleVisible(.hanziDecomposition) {
                    HanziDecompositionBanner(action: startHanziDecomposition)
                }
                if app.isHomeModuleVisible(.alphabet) {
                    AlphabetModuleBanner(action: startAlphabetModule, studiedCount: app.studiedAlphabetLetters.count)
                }
                if app.isHomeModuleVisible(.snake) {
                    SnakeGameBanner(status: app.snakeRewardStatus, action: startSnakeGame)
                }
                if app.isHomeModuleVisible(.fish) {
                    FishGameBanner(status: app.snakeRewardStatus, cost: app.fishTicketSettings.ticketsPerGame, action: startFishGame)
                }

                if app.isHomeModuleVisible(.hanziExploration) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("去收集新汉字")
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppPalette.ink)
                            Spacer()
                            Text("拍一拍，找一找")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppPalette.muted)
                        }
                        Button(action: importWords) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.7))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "camera.macro")
                                        .font(.system(size: 23, weight: .bold))
                                        .foregroundStyle(AppPalette.ink)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("拍下身边的字")
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    Text("从绘本、路牌里发现汉字")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 24))
                            }
                            .foregroundStyle(AppPalette.ink)
                            .padding(13)
                            .background(AppPalette.yellow, in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        Button(action: manualEntry) {
                            HStack(spacing: 9) {
                                Image(systemName: "keyboard")
                                Text("也可以手动输入一个生字")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.ink.opacity(0.82))
                            .padding(.horizontal, 15).frame(height: 44)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("我的汉字图鉴")
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                                .foregroundStyle(AppPalette.ink)
                            Spacer()
                            Button(action: showLibrary) {
                                HStack(spacing: 5) {
                                    Text("\(app.characters.count) 个")
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .heavy))
                                }
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AppPalette.muted)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("打开汉字图鉴，共 \(app.characters.count) 个字")
                        }
                        if app.characters.isEmpty {
                            EmptyCollectionCard(importWords: importWords)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                                ForEach(Array(app.characters.prefix(8).enumerated()), id: \.element.glyph) { index, item in
                                    CharacterTile(item: item, color: tileColor(index)) {
                                        openCharacter(item.glyph, Array(app.characters.prefix(8)).map(\.glyph))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func tileColor(_ index: Int) -> Color {
        [AppPalette.mint, AppPalette.yellow, AppPalette.lilac, AppPalette.blue][index % 4]
    }
}

private struct HomeModuleSettingsSheet: View {
    @ObservedObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(HomeModule.allCases) { module in
                        Toggle(module.title, isOn: Binding(
                            get: { app.isHomeModuleVisible(module) },
                            set: { app.setHomeModule(module, isVisible: $0) }
                        ))
                        .tint(AppPalette.orange)
                    }
                } footer: {
                    Text("这些显示设置只应用于\(app.currentUser.name)的首页。")
                }
            }
            .scrollContentBackground(.hidden)
            .background { StorybookBackground() }
            .navigationTitle("首页模块")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
}

private struct PinyinModuleBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.7))
                        .frame(width: 48, height: 48)
                    Text("拼")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("拼音乐园")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("认识声母韵母，动手拼读音节")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.blue.opacity(0.72), in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.blue.opacity(0.18), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct HanziDecompositionBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.72))
                        .frame(width: 48, height: 48)
                    Text("拆")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("汉字拆解")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("按课本册次学结构，也可拆解图鉴生字")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.mint.opacity(0.82), in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.mint.opacity(0.16), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct AlphabetModuleBanner: View {
    let action: () -> Void
    let studiedCount: Int

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.72))
                        .frame(width: 48, height: 48)
                    Text("Aa")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("英文字母岛")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("听字母、认大小写、玩听音挑战 · \(studiedCount)/26")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer(minLength: 4)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.blue.opacity(0.68), in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.blue.opacity(0.18), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("英文字母岛，已认识 \(studiedCount) 个字母，共 26 个")
    }
}

private struct SnakeGameBanner: View {
    let status: SnakeRewardStatus
    let action: () -> Void

    private var subtitle: String {
        if status.hasTicket { return "已攒 \(status.ticketCount) 张游戏券，可以连续玩几局" }
        if status.hasPlayed { return "游戏券已用完，再练字母就能获得新券" }
        return "答对 26 个字母练习，获得一张游戏券"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.72))
                        .frame(width: 48, height: 48)
                    Text("🐍")
                        .font(.system(size: 27))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("小蛇闯关")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer(minLength: 4)
                Image(systemName: status.hasTicket ? "play.circle.fill" : "lock.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.yellow.opacity(0.82), in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.yellow.opacity(0.2), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("小蛇闯关，\(subtitle)")
    }
}

private struct FishGameBanner: View {
    let status: SnakeRewardStatus
    let cost: Int
    let action: () -> Void

    private var subtitle: String {
        if cost == 0 { return "当前 \(status.ticketCount) 张游戏券 · 本局免费" }
        if status.ticketCount >= cost { return "当前 \(status.ticketCount) 张游戏券 · 每局需 \(cost) 张" }
        return "当前 \(status.ticketCount) 张游戏券 · 还差 \(cost - status.ticketCount) 张"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.72))
                        .frame(width: 48, height: 48)
                    Text("🐠").font(.system(size: 27))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("海底大冒险")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer(minLength: 4)
                Image(systemName: status.ticketCount >= cost ? "play.circle.fill" : "lock.circle.fill").font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.blue.opacity(0.68), in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.blue.opacity(0.18), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("海底大冒险，\(subtitle)")
    }
}

private struct ArithmeticGameBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.7))
                        .frame(width: 48, height: 48)
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("口算挑战")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("加减混合，看看你能答对几题！")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.mint, in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.mint.opacity(0.24), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct EquationBalanceGameBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.72))
                        .frame(width: 48, height: 48)
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("等式平衡")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("玩天平配平，学习加减法和等号")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.yellow.opacity(0.9), in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.yellow.opacity(0.2), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct ListeningGameBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.68))
                        .frame(width: 48, height: 48)
                    Image(systemName: "ear.badge.waveform")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("听音找字")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("听听读音，找到正确的汉字")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.76)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(12)
            .background(AppPalette.lilac, in: RoundedRectangle(cornerRadius: 21))
            .shadow(color: AppPalette.lilac.opacity(0.24), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct AdventureBanner: View {
    let startStudy: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30).fill(AppPalette.orange)
            Circle().fill(.white.opacity(0.17)).frame(width: 145, height: 145).offset(x: 28, y: -54)
            Circle().stroke(.white.opacity(0.28), lineWidth: 2).frame(width: 104, height: 104).offset(x: -45, y: 91)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("汉字探险队")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.white.opacity(0.25), in: Capsule())
                    Text("出发去\n认识新朋友！")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .lineSpacing(1)
                    Button(action: startStudy) {
                        HStack(spacing: 8) {
                            Text("开始闯关")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(.white.opacity(0.2)).frame(width: 112, height: 112)
                    Text("🦊").font(.system(size: 70))
                        .rotationEffect(.degrees(-7))
                    Text("✦").font(.system(size: 22, weight: .black)).offset(x: 42, y: -37)
                    Text("✦").font(.system(size: 16, weight: .black)).offset(x: -43, y: 39)
                }
                .accessibilityHidden(true)
            }
            .padding(18)
        }
        .frame(height: 198)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .shadow(color: AppPalette.orange.opacity(0.22), radius: 12, x: 0, y: 6)
    }
}

private struct ProgressTile: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 23, weight: .black, design: .rounded))
                Text(label).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppPalette.ink.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: AppPalette.ink.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private struct CharacterTile: View {
    let item: LearningCharacter
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Text(item.glyph)
                    .font(.system(size: 39, weight: .bold, design: .serif))
                    .foregroundStyle(AppPalette.ink)
                Text(item.pinyin.isEmpty ? item.status.label : item.pinyin)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 91)
            .background(color.opacity(0.76), in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: AppPalette.ink.opacity(0.08), radius: 7, x: 0, y: 4)
            .overlay(alignment: .topTrailing) {
                if item.status == .mastered {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15)).foregroundStyle(.white)
                        .padding(7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("学习汉字：\(item.glyph)")
    }
}

private struct EmptyCollectionCard: View {
    let importWords: () -> Void
    var body: some View {
        Button(action: importWords) {
            HStack(spacing: 14) {
                Text("🪄").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 4) {
                    Text("图鉴还空着呢")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text("拍张照片，把第一个汉字请进来！")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill").font(.system(size: 25))
            }
            .foregroundStyle(AppPalette.ink)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryScreen: View {
    @ObservedObject var app: AppModel
    let startStudy: (String, [String]) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("汉字图鉴")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Text("共 \(app.characters.count) 个字")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.muted)
                }
                Text("每个汉字，都是你发现的小宝藏。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppPalette.muted)
                if app.characters.isEmpty {
                    Text("还没有汉字，回到首页拍照收集吧～")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 14)], spacing: 14) {
                        ForEach(Array(app.characters.enumerated()), id: \.element.glyph) { index, item in
                            Button { startStudy(item.glyph, app.characters.map(\.glyph)) } label: {
                                VStack(spacing: 7) {
                                    Text(item.glyph).font(.system(size: 49, weight: .bold, design: .serif))
                                    Text(item.pinyin.isEmpty ? item.status.label : item.pinyin)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text(item.status.label)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(AppPalette.ink.opacity(0.62))
                                }
                                .foregroundStyle(AppPalette.ink)
                                .frame(maxWidth: .infinity).frame(height: 135)
                                .background([AppPalette.mint, AppPalette.yellow, AppPalette.lilac, AppPalette.blue][index % 4], in: RoundedRectangle(cornerRadius: 25))
                                .shadow(color: AppPalette.ink.opacity(0.08), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24).padding(.top, 20)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
    }
}

private struct BottomNavigation: View {
    @Binding var selectedTab: Int
    var body: some View {
        HStack(spacing: 10) {
            tabButton(0, title: "探险", icon: "map.fill")
            tabButton(1, title: "图鉴", icon: "square.grid.2x2.fill")
        }
        .padding(.horizontal, 20).padding(.top, 9).padding(.bottom, 8)
        .background(AppPalette.paper.opacity(0.98))
    }

    private func tabButton(_ index: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == index
        let restingColor = index == 0 ? AppPalette.mint : AppPalette.lilac
        return Button { selectedTab = index } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(title).font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(AppPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(isSelected ? AppPalette.yellow : restingColor.opacity(0.62), in: RoundedRectangle(cornerRadius: 23))
            .overlay {
                RoundedRectangle(cornerRadius: 23)
                    .strokeBorder(.white.opacity(isSelected ? 0.9 : 0.75), lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 23))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ProfileScreen: View {
    let app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var profilePendingDeletion: ChildProfile?
    @State private var profilePendingRename: ChildProfile?
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("选择小探险家") {
                    ForEach(app.users) { user in
                        HStack(spacing: 12) {
                            ProfileAvatarEditor(user: user) { profile, image in
                                app.updateAvatar(for: profile, image: image)
                            }
                            Button {
                                nameFocused = false
                                app.switchUser(to: user)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                Text(user.name).font(.system(size: 17, weight: .bold, design: .rounded))
                                Spacer()
                                if user.id == app.currentUser.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppPalette.orange)
                                }
                                }
                                .foregroundStyle(AppPalette.ink)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button {
                                nameFocused = false
                                profilePendingRename = user
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(AppPalette.orange)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("修改\(user.name)的名称")
                        }
                        .listRowBackground(Color.white)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if app.users.count > 1 {
                                Button(role: .destructive) {
                                    nameFocused = false
                                    profilePendingDeletion = user
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                Section("新增檔案") {
                    HStack {
                        TextField("小朋友的昵称", text: $newName)
                            .foregroundStyle(AppPalette.ink)
                            .tint(AppPalette.ink)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { nameFocused = false }
                        Button("添加") {
                            nameFocused = false
                            app.addUser(named: newName)
                            dismiss()
                        }
                        .fontWeight(.bold)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background {
                StorybookBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { nameFocused = false }
            }
            .navigationTitle("我的小档案")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppPalette.orange)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        nameFocused = false
                        dismiss()
                    }
                }
            }
        }
        // Sheets have their own presentation environment; keep this screen's
        // fixed paper palette independent of the iPad's system appearance.
        .preferredColorScheme(.light)
        .keyboardDismissToolbar { nameFocused = false }
        .alert(item: $profilePendingDeletion) { user in
            Alert(
                title: Text("删除“\(user.name)”的档案？"),
                message: Text("该档案的生字和学习记录也会一起删除，且无法恢复。"),
                primaryButton: .destructive(Text("确定删除")) {
                    app.deleteUser(user)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .sheet(item: $profilePendingRename) { user in
            ProfileNameEditor(user: user) { newName in
                app.renameUser(user, named: newName)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
    }
}

private struct ProfileNameEditor: View {
    let user: ChildProfile
    let onSave: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var name: String

    init(user: ChildProfile, onSave: @escaping (String) -> Bool) {
        self.user = user
        self.onSave = onSave
        _name = State(initialValue: user.name)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("小朋友昵称") {
                    TextField("请输入昵称", text: $name)
                        .foregroundStyle(AppPalette.ink)
                        .tint(AppPalette.ink)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 12 {
                                name = String(newValue.prefix(12))
                            }
                        }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background {
                StorybookBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { nameFocused = false }
            }
            .navigationTitle("修改名称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        nameFocused = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        nameFocused = false
                        if onSave(trimmedName) { dismiss() }
                    }
                    .fontWeight(.bold)
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .keyboardDismissToolbar { nameFocused = false }
        .onAppear { nameFocused = true }
    }
}

private struct StudyScreen: View {
    let app: AppModel
    let initialGlyph: String?
    let visibleOrder: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [LearningCharacter] = []
    @State private var index = 0
    @State private var completed = 0
    @State private var speech = SpeechPlayer()
    @State private var selectedPronunciation: CharacterPronunciation?
    @State private var strokeOrders = StrokeOrderStore()
    @State private var strokePaths: [String] = []
    @State private var strokeMedians: [[[Double]]] = []
    @State private var strokeReplayID = 0
    @State private var dragTranslationY: CGFloat = 0
    @State private var swipeDirection = 1

    private var current: LearningCharacter? { cards.indices.contains(index) ? cards[index] : nil }

    var body: some View {
        ZStack {
            StorybookBackground()
            VStack(spacing: 20) {
                HStack {
                    Button { speech.stop(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(AppPalette.ink)
                            .frame(width: 44, height: 44).background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("汉字小闯关")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Spacer()
                    Text("\(min(index + 1, max(cards.count, 1)))/\(cards.count)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.muted)
                        .frame(width: 48)
                }
                if let item = current {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 4) {
                                Button { speak(item) } label: {
                                    Text(item.glyph)
                                        .font(.system(size: 146, weight: .medium, design: .serif))
                                        .minimumScaleFactor(0.55)
                                        .lineLimit(1)
                                        .foregroundStyle(AppPalette.ink)
                                        .frame(width: 200, height: 184)
                                }
                                .buttonStyle(.plain)
                                Button { speak(item) } label: {
                                    VStack(spacing: 8) {
                                        HStack(spacing: 7) {
                                            Text(pronunciation(for: item)?.pinyin ?? (item.pinyin.isEmpty ? "暂无拼音" : item.pinyin))
                                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                                .minimumScaleFactor(0.65)
                                                .lineLimit(1)
                                                .foregroundStyle(Color(red: 0.82, green: 0.16, blue: 0.20))
                                        }
                                        if item.pronunciations.count > 1 {
                                            Text("例词：\(pronunciation(for: item)?.example ?? "")")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(AppPalette.muted)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 16)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("播放汉字\(item.glyph)")
                            }
                            HStack(spacing: 10) {
                                if item.pronunciations.count > 1 {
                                    ScrollView(.horizontal) {
                                        HStack(spacing: 7) {
                                            ForEach(item.pronunciations) { option in
                                                let isSelected = pronunciation(for: item)?.pinyin == option.pinyin
                                                Button {
                                                    selectedPronunciation = option
                                                    speech.speak(option.example)
                                                } label: {
                                                    VStack(spacing: 1) {
                                                        Text(option.pinyin)
                                                            .font(.system(size: 17, weight: .black, design: .rounded))
                                                        Text(option.example)
                                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                                            .lineLimit(1)
                                                    }
                                                    .foregroundStyle(isSelected ? AppPalette.ink : AppPalette.ink.opacity(0.78))
                                                    .padding(.horizontal, 11)
                                                    .frame(minWidth: 56, minHeight: 52)
                                                    .background(isSelected ? AppPalette.mint : .white.opacity(0.78), in: Capsule())
                                                    .overlay(Capsule().stroke(.white.opacity(isSelected ? 0.95 : 0.65), lineWidth: 1.5))
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("\(option.pinyin)，例词\(option.example)，\(option.meaning)\(isSelected ? "，当前读音" : "，切换并播放")")
                                            }
                                        }
                                    }
                                    .scrollIndicators(.hidden)

                                    Button { speak(item) } label: {
                                        Image(systemName: speech.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(AppPalette.ink)
                                            .frame(width: 46, height: 46)
                                            .background(.white.opacity(0.85), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("播放\(item.glyph)的当前读音")
                                } else {
                                    Button { speak(item) } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: speech.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                            Text(speech.isSpeaking ? "正在朗读…" : "播放")
                                        }
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppPalette.ink.opacity(0.75))
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(.white.opacity(0.75), in: Capsule())
                                        .contentShape(Capsule())
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("播放\(item.glyph)的读音")
                                }
                            }

                            Rectangle()
                                .fill(AppPalette.ink.opacity(0.1))
                                .frame(height: 1)
                                .padding(.horizontal, 18)

                            HStack(spacing: 8) {
                                Text("笔顺 · \(strokePaths.count) 画")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppPalette.ink)
                                Spacer()
                                if !strokePaths.isEmpty {
                                    Button {
                                        strokeReplayID += 1
                                    } label: {
                                        Label("再看一遍", systemImage: "arrow.clockwise")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppPalette.ink)
                                            .padding(.horizontal, 11).padding(.vertical, 7)
                                            .background(.white.opacity(0.75), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 18)

                            if strokePaths.isEmpty {
                                Text("这个字的笔顺还没收录")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppPalette.muted)
                                    .frame(height: 126)
                            } else {
                                StrokeOrderAnimationView(strokes: strokePaths, medians: strokeMedians, replayID: strokeReplayID)
                                    .frame(maxWidth: 420)
                                    .frame(height: CGFloat((strokePaths.count + 4) / 5) * 100 + 24)
                                    .accessibilityLabel("\(item.glyph)的笔顺动画，共\(strokePaths.count)画")
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(AppPalette.yellow, in: RoundedRectangle(cornerRadius: 32))
                        .contentShape(RoundedRectangle(cornerRadius: 32))
                        .simultaneousGesture(cardSwipeGesture)
                        Text(item.meaning.isEmpty ? "上滑看下一个 · 下滑回顾" : "· \(item.meaning)    上滑下一个 · 下滑回顾")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppPalette.muted)
                    }
                    .id(item.glyph)
                    .transition(cardTransition)
                    .rotation3DEffect(
                        .degrees(Double(-dragTranslationY) * 0.075),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: dragTranslationY < 0 ? .bottom : .top,
                        perspective: 0.62
                    )
                    .offset(y: dragTranslationY * 0.24)
                    .scaleEffect(1 - min(abs(dragTranslationY) / 2200, 0.06))
                    .shadow(color: AppPalette.ink.opacity(min(abs(dragTranslationY) / CGFloat(900), CGFloat(0.18))), radius: 20, y: 12)
                    Spacer(minLength: 0)
                    HStack(spacing: 14) {
                        feedbackButton(title: "再练一次", symbol: "arrow.counterclockwise", color: AppPalette.lilac, knew: false)
                        feedbackButton(title: "我认识！", symbol: "star.fill", color: AppPalette.mint, knew: true)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Text(completed > 0 ? "🎉" : "🧭").font(.system(size: 78))
                        Text(completed > 0 ? "探险完成！" : "图鉴还没有汉字")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                        Text(completed > 0 ? "你刚刚练习了 \(completed) 个汉字，真棒！" : "先去拍照收集一些汉字吧～")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(AppPalette.muted)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    Button("回到探险地图") { dismiss() }
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(AppPalette.yellow, in: Capsule())
                }
            }
            .padding(24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            let studyCards = app.makeStudySet(startingWith: initialGlyph, visibleOrder: visibleOrder)
            cards = studyCards
            index = 0
            if let selectedCard = studyCards.first {
                strokePaths = strokeOrders.strokes(for: selectedCard.glyph)
                strokeMedians = strokeOrders.medians(for: selectedCard.glyph)
            }
        }
        .onChange(of: index) { _, newIndex in
            guard cards.indices.contains(newIndex) else { return }
            selectedPronunciation = nil
            strokePaths = strokeOrders.strokes(for: cards[newIndex].glyph)
            strokeMedians = strokeOrders.medians(for: cards[newIndex].glyph)
            strokeReplayID += 1
        }
        .onDisappear { speech.stop() }
    }

    private func pronunciation(for item: LearningCharacter) -> CharacterPronunciation? {
        selectedPronunciation
            ?? item.pronunciations.first(where: { $0.pinyin == item.pinyin })
            ?? item.pronunciations.first
    }

    private func speak(_ item: LearningCharacter) {
        // An isolated polyphonic character is ambiguous to Apple's Chinese
        // voice, so it falls back to its default reading. Keep the selected
        // reading in context when replaying it from the large character or
        // pinyin area; the pronunciation tag itself also speaks this example.
        if item.pronunciations.count > 1, let option = pronunciation(for: item) {
            speech.speak(option.example)
        } else {
            speech.speak(item.glyph)
        }
    }

    private func feedbackButton(title: String, symbol: String, color: Color, knew: Bool) -> some View {
        Button {
            guard let item = current else { return }
            speech.stop()
            app.recordAnswer(for: item, knew: knew)
            completed += 1
            index += 1
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(AppPalette.ink)
            .frame(maxWidth: .infinity).frame(height: 60)
            .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var cardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragTranslationY = min(max(value.translation.height, -150), 150)
            }
            .onEnded { value in
                let height = value.translation.height
                guard abs(height) > abs(value.translation.width), abs(height) > 50 else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { dragTranslationY = 0 }
                    return
                }

                let direction = height < 0 ? 1 : -1
                guard !cards.isEmpty else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { dragTranslationY = 0 }
                    return
                }
                let nextIndex = (index + direction + cards.count) % cards.count
                swipeDirection = direction
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    index = nextIndex
                    dragTranslationY = 0
                }
            }
    }

    private var cardTransition: AnyTransition {
        let entryEdge: Edge = swipeDirection > 0 ? .bottom : .top
        let exitEdge: Edge = swipeDirection > 0 ? .top : .bottom
        return .asymmetric(
            insertion: .move(edge: entryEdge).combined(with: .scale(scale: 0.92)).combined(with: .opacity),
            removal: .move(edge: exitEdge).combined(with: .scale(scale: 0.97)).combined(with: .opacity)
        )
    }
}
