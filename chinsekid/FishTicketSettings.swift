import Security
import SwiftUI

enum FishTicketQuestionType: String, CaseIterable, Codable, Identifiable {
    case alphabet, alphabetDictation, dictation, listening, humanDictation, englishWordDictation

    var id: String { rawValue }
    var title: String {
        switch self {
        case .alphabet: "26 个英文字母"
        case .alphabetDictation: "26 个英文字母听写"
        case .dictation: "拼音听写"
        case .listening: "拼音听音闯关"
        case .humanDictation: "真人听写"
        case .englishWordDictation: "英语单词听写"
        }
    }
}

enum AlphabetOptionDisplay: String, CaseIterable, Codable, Identifiable {
    case both, lowercase, uppercase

    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "大小写选项"
        case .lowercase: "纯小写选项"
        case .uppercase: "纯大写选项"
        }
    }

    var dictationTitle: String {
        switch self {
        case .both: "大小写都可以"
        case .lowercase: "只写小写"
        case .uppercase: "只写大写"
        }
    }
}

enum FishGameDifficulty: String, CaseIterable, Codable, Identifiable {
    case beginner, easy, standard, hard, challenge

    var id: String { rawValue }
    var title: String {
        switch self {
        case .beginner: "入门"
        case .easy: "轻松"
        case .standard: "标准"
        case .hard: "困难"
        case .challenge: "挑战"
        }
    }

    var explanation: String {
        switch self {
        case .beginner: "少量高等级鱼，最多 1 条追击，预警和休息时间更长。"
        case .easy: "较少高等级鱼，最多 1 条追击。"
        case .standard: "保持当前节奏，最多 2 条追击。"
        case .hard: "高等级鱼稍多，最多 2 条追击，冷却更短。"
        case .challenge: "高等级鱼更多，最多 3 条追击，海胆更频繁。"
        }
    }

    var threatCount: Int {
        switch self {
        case .beginner: 2
        case .easy: 3
        case .standard: 4
        case .hard: 5
        case .challenge: 6
        }
    }

    var maxChasers: Int {
        switch self {
        case .beginner, .easy: 1
        case .standard, .hard: 2
        case .challenge: 3
        }
    }

    var chaseDuration: ClosedRange<CGFloat> {
        switch self {
        case .beginner: 3...4
        case .easy: 3.5...5
        case .standard: 4...6
        case .hard: 4.5...6.5
        case .challenge: 5...7
        }
    }

    var chaseWindup: CGFloat {
        switch self {
        case .beginner: 1.2
        case .easy: 0.85
        case .standard: 0.52
        case .hard: 0.42
        case .challenge: 0.32
        }
    }

    var chaseCooldown: ClosedRange<CGFloat> {
        switch self {
        case .beginner: 14...18
        case .easy: 11...15
        case .standard: 8...12
        case .hard: 7...10
        case .challenge: 6...9
        }
    }

    var mineInterval: ClosedRange<CGFloat> {
        switch self {
        case .beginner: 32...42
        case .easy: 27...36
        case .standard: 22...31
        case .hard: 19...27
        case .challenge: 16...23
        }
    }

    var maxMines: Int {
        switch self {
        case .beginner: 1
        case .easy: 2
        case .standard, .hard: 3
        case .challenge: 4
        }
    }
}

struct FishTicketSettings: Codable, Equatable {
    var questionType: FishTicketQuestionType = .alphabet
    var alphabetOptionDisplay: AlphabetOptionDisplay = .lowercase
    var ticketsPerGame = 2
    var difficulty: FishGameDifficulty = .standard
    var dictationIDs = Set(PinyinCatalog.categories.flatMap(\.items).map(\.id))
    var listeningIDs = Set(PinyinCatalog.categories.flatMap(\.items).map(\.id))
    var humanDictationWorksheetID: String?
    var humanDictationQuestionCount = 0
    var englishWordWorksheetID: String?
    var englishWordQuestionCount = 0
    var allowsTemporaryTrial = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case questionType, alphabetOptionDisplay, ticketsPerGame, difficulty, dictationIDs, listeningIDs, humanDictationWorksheetID, humanDictationQuestionCount, englishWordWorksheetID, englishWordQuestionCount, allowsTemporaryTrial
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        questionType = try values.decodeIfPresent(FishTicketQuestionType.self, forKey: .questionType) ?? .alphabet
        alphabetOptionDisplay = try values.decodeIfPresent(AlphabetOptionDisplay.self, forKey: .alphabetOptionDisplay) ?? .lowercase
        ticketsPerGame = try values.decodeIfPresent(Int.self, forKey: .ticketsPerGame) ?? 2
        difficulty = try values.decodeIfPresent(FishGameDifficulty.self, forKey: .difficulty) ?? .standard
        dictationIDs = try values.decodeIfPresent(Set<String>.self, forKey: .dictationIDs)
            ?? Set(PinyinCatalog.categories.flatMap(\.items).map(\.id))
        listeningIDs = try values.decodeIfPresent(Set<String>.self, forKey: .listeningIDs)
            ?? Set(PinyinCatalog.categories.flatMap(\.items).map(\.id))
        humanDictationWorksheetID = try values.decodeIfPresent(String.self, forKey: .humanDictationWorksheetID)
        humanDictationQuestionCount = try values.decodeIfPresent(Int.self, forKey: .humanDictationQuestionCount) ?? 0
        englishWordWorksheetID = try values.decodeIfPresent(String.self, forKey: .englishWordWorksheetID)
        englishWordQuestionCount = try values.decodeIfPresent(Int.self, forKey: .englishWordQuestionCount) ?? 0
        allowsTemporaryTrial = try values.decodeIfPresent(Bool.self, forKey: .allowsTemporaryTrial) ?? false
    }

    func items(for type: FishTicketQuestionType) -> [PinyinUnit] {
        guard type == .dictation || type == .listening else { return [] }
        let ids = type == .dictation ? dictationIDs : listeningIDs
        return PinyinCatalog.categories.flatMap(\.items).filter { ids.contains($0.id) }
    }

    var questionCount: Int {
        switch questionType {
        case .alphabet, .alphabetDictation: 26
        case .dictation, .listening: items(for: questionType).count
        case .humanDictation: humanDictationQuestionCount
        case .englishWordDictation: englishWordQuestionCount
        }
    }

    var practiceHint: String {
        switch questionType {
        case .alphabet:
            "听字母选答案（\(alphabetOptionDisplay.title)）· 26 题全对赢 1 张券"
        case .alphabetDictation:
            "听写英文字母（\(alphabetOptionDisplay.dictationTitle)）· 26 题全对赢 1 张券"
        case .dictation:
            "拼音听写 · \(questionCount) 题全对赢 1 张券"
        case .listening:
            "听音选拼音 · \(questionCount) 题全对赢 1 张券"
        case .humanDictation:
            "真人听写 · 使用家长选择的听写单，全部答对赢 1 张券"
        case .englishWordDictation:
            "英语单词听写 · 答错立即重开，全部答对赢 1 张券"
        }
    }
}

private enum ParentPIN {
    private static let service = "perfectyang.chinsekid.fish-parent-pin"
    private static let account = "parent"

    static var isConfigured: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ pin: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(pin.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}

struct ParentFishSettingsScreen: View {
    @ObservedObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false
    @State private var pin = ""
    @State private var repeatPIN = ""
    @State private var message: String?
    @State private var failedAttempts = 0
    @State private var lockedUntil: Date?
    @State private var settings = FishTicketSettings()
    @State private var availableDictationSheets: [PinyinWorksheet] = []
    @State private var availableEnglishWorksheets: [EnglishWordDictation] = []
    @State private var showingSkinResetConfirmation = false
    @State private var skinResetDone = false

    private var isCreatingPIN: Bool { !ParentPIN.isConfigured }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if unlocked { settingsForm } else { pinForm }
                }
                .padding(24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle(unlocked ? "海底大冒险 · 家长设置" : "家长验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            settings = app.fishTicketSettings
            loadAvailableDictationSheets()
        }
        .onChange(of: app.currentUser.id) { _, _ in
            settings = app.fishTicketSettings
            loadAvailableDictationSheets()
        }
        .confirmationDialog(
            "重置 \(app.currentUser.name) 的鱼皮肤解锁进度？",
            isPresented: $showingSkinResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置皮肤进度", role: .destructive) {
                app.resetFishSkinUnlockProgress()
                skinResetDone = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只重置鱼皮肤及其解锁进度；游戏券和学习记录会保留。")
        }
    }

    private var pinForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isCreatingPIN ? "首次设置家长密码" : "请输入家长密码")
                .font(.system(size: 25, weight: .black, design: .rounded))
            Text("请使用独立的 4～6 位数字密码。家长设置仅用于海底大冒险。")
                .foregroundStyle(KidsTheme.muted)
            SecureField("家长密码", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
            if isCreatingPIN {
                SecureField("再输入一次", text: $repeatPIN)
                    .keyboardType(.numberPad)
                    .padding(15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            if let message { Text(message).foregroundStyle(KidsTheme.red) }
            Button(isCreatingPIN ? "设置密码并进入" : "进入家长设置") { unlock() }
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(KidsTheme.yellow, in: Capsule())
                .disabled(lockedUntil.map { Date() < $0 } ?? false)
        }
        .foregroundStyle(KidsTheme.ink)
    }

    private func unlock() {
        guard !(lockedUntil.map { Date() < $0 } ?? false) else { return }
        guard (4...6).contains(pin.count), pin.allSatisfy(\.isNumber) else {
            message = "请输入 4～6 位数字密码。"
            return
        }
        if ParentPIN.isConfigured {
            guard let saved = ParentPIN.read() else {
                message = "暂时无法读取家长密码，请稍后重试。"
                return
            }
            guard saved == pin else {
                failedAttempts += 1
                if failedAttempts >= 5 {
                    lockedUntil = Date().addingTimeInterval(60)
                    failedAttempts = 0
                    message = "密码错误次数过多，请一分钟后再试。"
                } else {
                    message = "密码不正确。"
                }
                pin = ""
                return
            }
        } else {
            guard pin == repeatPIN else { message = "两次输入的密码不同。"; return }
            guard ParentPIN.save(pin) else { message = "密码保存失败，请重试。"; return }
        }
        pin = ""
        repeatPIN = ""
        message = nil
        unlocked = true
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("为 \(app.currentUser.name) 设置")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            Text("选择一种赢券题型，答对完整一轮可获得 1 张游戏券。答错立即重新开始并换题序。")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KidsTheme.muted)

            VStack(alignment: .leading, spacing: 12) {
                Text("赢券题型").font(.headline)
                Picker("题型", selection: $settings.questionType) {
                    ForEach(FishTicketQuestionType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)
                if settings.questionType == .alphabet || settings.questionType == .alphabetDictation {
                    Picker(settings.questionType == .alphabet ? "选项出现形式" : "听写字母形式", selection: $settings.alphabetOptionDisplay) {
                        ForEach(AlphabetOptionDisplay.allCases) { style in
                            Text(settings.questionType == .alphabet ? style.title : style.dictationTitle).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    if settings.questionType == .alphabetDictation {
                        Text("选择纯小写或纯大写时，需要按对应形式输入；选大小写都可以时，两种写法均算正确。")
                            .font(.subheadline)
                            .foregroundStyle(KidsTheme.muted)
                    }
                }
                if settings.questionType == .dictation || settings.questionType == .listening {
                    Text("本轮共 \(settings.questionCount) 题，每个选中的拼音各出一题。")
                        .font(.subheadline)
                    selectionList
                }
                if settings.questionType == .humanDictation {
                    if availableDictationSheets.isEmpty {
                        Text("还没有已保存的听写单。请先到“拼音乐园 → 拼音听写”新建一份。")
                            .font(.subheadline)
                            .foregroundStyle(KidsTheme.muted)
                    } else {
                        Picker("选择听写单", selection: Binding(
                            get: { settings.humanDictationWorksheetID ?? "" },
                            set: { id in
                                settings.humanDictationWorksheetID = id.isEmpty ? nil : id
                                settings.humanDictationQuestionCount = availableDictationSheets.first(where: { $0.id == id })?.items.count ?? 0
                            }
                        )) {
                            Text("请选择听写单").tag("")
                            ForEach(availableDictationSheets) { worksheet in
                                Text("\(worksheet.name) · \(worksheet.items.count) 题").tag(worksheet.id)
                            }
                        }
                        .pickerStyle(.menu)
                        if settings.humanDictationQuestionCount > 0 {
                            Text("使用这份听写单的 \(settings.humanDictationQuestionCount) 道题。")
                                .font(.subheadline)
                                .foregroundStyle(KidsTheme.muted)
                        }
                    }
                }
                if settings.questionType == .englishWordDictation {
                    if availableEnglishWorksheets.isEmpty {
                        Text("还没有已保存的英语听写单。请先到“英文字母岛 → 英语单词听写”新建一份。")
                            .font(.subheadline)
                            .foregroundStyle(KidsTheme.muted)
                    } else {
                        Picker("选择英语听写单", selection: Binding(
                            get: { settings.englishWordWorksheetID ?? "" },
                            set: { id in
                                settings.englishWordWorksheetID = id.isEmpty ? nil : id
                                settings.englishWordQuestionCount = availableEnglishWorksheets.first(where: { $0.id == id })?.items.count ?? 0
                            }
                        )) {
                            Text("请选择英语听写单").tag("")
                            ForEach(availableEnglishWorksheets) { worksheet in
                                Text("\(worksheet.name) · \(worksheet.items.count) 题").tag(worksheet.id)
                            }
                        }
                        .pickerStyle(.menu)
                        if settings.englishWordQuestionCount > 0 {
                            Text("答错后整轮重新开始，共 \(settings.englishWordQuestionCount) 个单词。")
                                .font(.subheadline)
                                .foregroundStyle(KidsTheme.muted)
                        }
                    }
                }
            }
            .padding(18)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 12) {
                Text("海底大冒险难度").font(.headline)
                Picker("游戏难度", selection: $settings.difficulty) {
                    ForEach(FishGameDifficulty.allCases) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
                .pickerStyle(.menu)
                Text(settings.difficulty.explanation)
                    .font(.subheadline)
                    .foregroundStyle(KidsTheme.muted)
                Text("下一局生效；任何难度都只能吃同级或低级鱼。")
                    .font(.subheadline)
                    .foregroundStyle(KidsTheme.muted)
            }
            .padding(18)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 12) {
                Text("每局消耗游戏券").font(.headline)
                Stepper(settings.ticketsPerGame == 0 ? "0 张（免费开始）" : "\(settings.ticketsPerGame) 张", value: $settings.ticketsPerGame, in: 0...10)
                Text("设为 0 张可免费开始正式游戏；改动从下一局生效。")
                    .font(.subheadline)
                    .foregroundStyle(KidsTheme.muted)
            }
            .padding(18)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 12) {
                Toggle("开发测试入口（免券）", isOn: $settings.allowsTemporaryTrial)
                    .font(.headline)
                    .tint(KidsTheme.orange)
                Text("开启后，海底大冒险准备页显示「快速进入」按钮；关闭后隐藏。")
                    .font(.subheadline)
                    .foregroundStyle(KidsTheme.muted)
            }
            .padding(18)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 10) {
                Text("鱼皮肤进度").font(.headline)
                Text("皮肤需同时满足卡片上的等级和吃鱼条件。")
                    .font(.subheadline)
                    .foregroundStyle(KidsTheme.muted)
                Button("重置鱼皮肤解锁进度") { showingSkinResetConfirmation = true }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KidsTheme.red)
                if skinResetDone {
                    Text("已重置鱼皮肤进度，游戏券和学习记录已保留。")
                        .font(.subheadline)
                        .foregroundStyle(KidsTheme.ink)
                }
            }
            .padding(18)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))

            if let message { Text(message).foregroundStyle(KidsTheme.red) }
            Button("保存设置") {
                if settings.questionType == .humanDictation {
                    guard let id = settings.humanDictationWorksheetID,
                          let worksheet = availableDictationSheets.first(where: { $0.id == id }) else {
                        message = "请先选择一份已建好的真人听写单。"
                        return
                    }
                    settings.humanDictationQuestionCount = worksheet.items.count
                }
                if settings.questionType == .englishWordDictation {
                    guard let id = settings.englishWordWorksheetID,
                          let worksheet = availableEnglishWorksheets.first(where: { $0.id == id }) else {
                        message = "请先选择一份已建好的英语听写单。"
                        return
                    }
                    settings.englishWordQuestionCount = worksheet.items.count
                }
                guard settings.questionCount > 0 else {
                    message = "请至少选择一个拼音。"
                    return
                }
                app.saveFishTicketSettings(settings)
                dismiss()
            }
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(KidsTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(KidsTheme.yellow, in: Capsule())
        }
    }

    private var selectionList: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Button("全选") { updateSelection(Set(PinyinCatalog.categories.flatMap(\.items).map(\.id))) }
                Button("清空") { updateSelection([]) }
            }
            .buttonStyle(.bordered)
            ForEach(PinyinCatalog.categories) { category in
                DisclosureGroup("\(category.title) · \(category.items.filter { currentSelection.contains($0.id) }.count)/\(category.items.count)") {
                    Button(currentSelection.isSuperset(of: Set(category.items.map(\.id))) ? "取消本类" : "选择本类") {
                        var ids = currentSelection
                        let categoryIDs = Set(category.items.map(\.id))
                        if ids.isSuperset(of: categoryIDs) { ids.subtract(categoryIDs) }
                        else { ids.formUnion(categoryIDs) }
                        updateSelection(ids)
                    }
                    .font(.subheadline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
                        ForEach(category.items) { item in
                            Button(item.symbol) {
                                var ids = currentSelection
                                if !ids.insert(item.id).inserted { ids.remove(item.id) }
                                updateSelection(ids)
                            }
                            .font(.system(size: 17, weight: .bold))
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(currentSelection.contains(item.id) ? KidsTheme.mint : KidsTheme.paper, in: Capsule())
                        }
                    }
                }
                .tint(KidsTheme.ink)
            }
        }
    }

    private var currentSelection: Set<String> {
        settings.questionType == .dictation ? settings.dictationIDs : settings.listeningIDs
    }

    @MainActor
    private func loadAvailableDictationSheets() {
        availableDictationSheets = (try? PinyinWorksheetStore(userID: app.currentUser.id).all()) ?? []
        availableEnglishWorksheets = (try? EnglishWordDictationStore(userID: app.currentUser.id).all()) ?? []
        if let selectedID = settings.humanDictationWorksheetID,
           let selected = availableDictationSheets.first(where: { $0.id == selectedID }) {
            settings.humanDictationQuestionCount = selected.items.count
        } else if settings.questionType == .humanDictation {
            settings.humanDictationQuestionCount = 0
        }
        if let selectedID = settings.englishWordWorksheetID,
           let selected = availableEnglishWorksheets.first(where: { $0.id == selectedID }) {
            settings.englishWordQuestionCount = selected.items.count
        } else if settings.questionType == .englishWordDictation {
            settings.englishWordQuestionCount = 0
        }
    }

    private func updateSelection(_ ids: Set<String>) {
        if settings.questionType == .dictation { settings.dictationIDs = ids }
        else { settings.listeningIDs = ids }
    }
}
