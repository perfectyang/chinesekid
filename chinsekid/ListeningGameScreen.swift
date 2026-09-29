import SwiftUI

private enum GamePalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let paper = KidsTheme.paper
    static let orange = KidsTheme.orange
    static let yellow = KidsTheme.yellow
    static let mint = KidsTheme.mint
    static let lilac = KidsTheme.lilac
    static let blue = KidsTheme.blue
    static let wrong = KidsTheme.red
    static let answerTiles = [
        KidsTheme.peach, KidsTheme.yellow, KidsTheme.mint, KidsTheme.blue
    ]
    static let tileOutline = Color.white.opacity(0.82)
    static let correctTile = Color(red: 0.42, green: 0.77, blue: 0.53)
    static let correctInk = Color(red: 0.13, green: 0.34, blue: 0.20)
}

private struct ActivePracticeSet: Identifiable {
    let id: String
    let name: String
    let characters: [LearningCharacter]
}

private struct PracticeSetEditorRequest: Identifiable {
    let id = UUID()
    let set: PracticeCharacterSet?
}

struct ListeningGameFlowScreen: View {
    let app: AppModel
    let onCollect: () -> Void
    @State private var activeSet: ActivePracticeSet?

    var body: some View {
        Group {
            if let activeSet {
                ListeningGameScreen(app: app, initialCharacters: activeSet.characters, setName: activeSet.name, onCollect: onCollect)
                    .id(activeSet.id)
            } else {
                PracticeSetPickerScreen(app: app, onCollect: onCollect) { name, characters in
                    activeSet = ActivePracticeSet(id: UUID().uuidString, name: name, characters: characters)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: activeSet?.id)
    }
}

private struct PracticeSetPickerScreen: View {
    let app: AppModel
    let onCollect: () -> Void
    let onChoose: (String, [LearningCharacter]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editorRequest: PracticeSetEditorRequest?
    @State private var setPendingDeletion: PracticeCharacterSet?

    private var charactersByGlyph: [String: LearningCharacter] {
        Dictionary(uniqueKeysWithValues: app.characters.map { ($0.glyph, $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今天想练哪一组？")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(GamePalette.ink)
                        Text("选一组生字开始听音找字，也可以为今天新建一组。")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(GamePalette.muted)
                    }
                    .padding(.top, 8)

                    if app.characters.count < 4 {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("字库至少需要 4 个字才能开始游戏", systemImage: "lightbulb.fill")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(GamePalette.ink)
                            Button(action: onCollect) {
                                Label("去收集生字", systemImage: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(GamePalette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(GamePalette.yellow, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("快捷练习", symbol: "sparkles")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            let recent = Array(app.characters.prefix(10))
                            practiceCard(title: "全部生字", subtitle: "整本图鉴都练一遍", characters: app.characters, symbol: "character.book.closed.fill", color: GamePalette.mint)
                            practiceCard(title: "最近收集", subtitle: "最近加入的 10 个字", characters: recent, symbol: "sun.max.fill", color: GamePalette.yellow)
                            practiceCard(title: "错字再练", subtitle: "以前听错过的字", characters: app.listeningMistakes, symbol: "arrow.counterclockwise", color: GamePalette.lilac)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionTitle("我的题组", symbol: "square.stack.3d.up.fill")
                            Spacer()
                            Button {
                                editorRequest = PracticeSetEditorRequest(set: nil)
                            } label: {
                                Label("新建", systemImage: "plus")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(GamePalette.ink)
                                    .padding(.horizontal, 14).frame(height: 38)
                                    .background(GamePalette.yellow, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if app.practiceSets.isEmpty {
                            Text("还没有自选题组，点“新建”挑一些今天想练的字吧。")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(GamePalette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
                        } else {
                            ForEach(app.practiceSets) { set in
                                HStack(spacing: 10) {
                                    Button {
                                        let selected = set.glyphs.compactMap { charactersByGlyph[$0] }
                                        onChoose(set.name, selected)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(set.name)
                                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                                .foregroundStyle(GamePalette.ink)
                                            Text("\(set.glyphs.count) 个字 · \(set.glyphs.prefix(8).joined(separator: "  "))")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(GamePalette.muted)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(set.glyphs.isEmpty || app.characters.count < 4)

                                    Button {
                                        editorRequest = PracticeSetEditorRequest(set: set)
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(GamePalette.ink)
                                            .frame(width: 42, height: 46)
                                            .background(GamePalette.yellow.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
                                    }
                                    .buttonStyle(.plain)
                                    Button(role: .destructive) {
                                        setPendingDeletion = set
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(GamePalette.wrong)
                                            .frame(width: 42, height: 46)
                                            .background(GamePalette.wrong.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle("选择练习题组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .sheet(item: $editorRequest) { request in
            PracticeSetEditorScreen(app: app, set: request.set)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(item: $setPendingDeletion) { set in
            Alert(
                title: Text("删除题组“\(set.name)”？"),
                message: Text("只会删除这个自选题组，不会删除图鉴里的生字。"),
                primaryButton: .destructive(Text("删除题组")) { app.deletePracticeSet(set) },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(GamePalette.ink)
    }

    private func practiceCard(title: String, subtitle: String, characters: [LearningCharacter], symbol: String, color: Color) -> some View {
        Button {
            onChoose(title, characters)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .bold))
                    Spacer(minLength: 4)
                    Text("\(characters.count) 字")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.white.opacity(0.55), in: Capsule())
                }
                Text(title)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.75)
                    .lineLimit(1)
            }
            .foregroundStyle(GamePalette.ink)
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .disabled(characters.isEmpty || app.characters.count < 4)
        .opacity(characters.isEmpty || app.characters.count < 4 ? 0.52 : 1)
    }
}

private struct PracticeSetEditorScreen: View {
    let app: AppModel
    let set: PracticeCharacterSet?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var name: String
    @State private var selectedGlyphs: Set<String>

    init(app: AppModel, set: PracticeCharacterSet?) {
        self.app = app
        self.set = set
        _name = State(initialValue: set?.name ?? "")
        _selectedGlyphs = State(initialValue: Set(set?.glyphs ?? []))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundStyle(GamePalette.orange)
                    TextField("给这组字起个名字", text: $name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .focused($nameFocused)
                        .onChange(of: name) { _, value in
                            if value.count > 24 { name = String(value.prefix(24)) }
                        }
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))

                HStack {
                    Text("选出想练的生字")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(GamePalette.ink)
                    Spacer()
                    Text("已选 \(selectedGlyphs.count) 个")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(GamePalette.muted)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(app.characters.enumerated()), id: \.element.glyph) { index, item in
                            let selected = selectedGlyphs.contains(item.glyph)
                            Button {
                                if selected { selectedGlyphs.remove(item.glyph) }
                                else { selectedGlyphs.insert(item.glyph) }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Text(item.glyph)
                                        .font(.system(size: 29, weight: .bold, design: .serif))
                                        .foregroundStyle(GamePalette.ink)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                        .background(selected ? GamePalette.mint : [GamePalette.yellow, GamePalette.lilac, GamePalette.blue, GamePalette.mint][index % 4].opacity(0.58), in: RoundedRectangle(cornerRadius: 15))
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(GamePalette.ink)
                                            .padding(4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(18)
            .background { StorybookBackground() }
            .navigationTitle(set == nil ? "新建题组" : "编辑题组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if app.savePracticeSet(id: set?.id, name: trimmedName, glyphs: Array(selectedGlyphs)) != nil {
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(trimmedName.isEmpty || selectedGlyphs.isEmpty)
                }
            }
        }
        .onAppear { if set == nil { nameFocused = true } }
    }
}

struct ListeningGameScreen: View {
    let app: AppModel
    let initialCharacters: [LearningCharacter]
    let setName: String
    let onCollect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var speech = SpeechPlayer()
    @State private var wordPool: [LearningCharacter] = []
    @State private var targetQueue: [LearningCharacter] = []
    @State private var answerPositionQueue: [Int] = []
    @State private var missedCharacters: [LearningCharacter] = []
    @State private var target: LearningCharacter?
    @State private var options: [LearningCharacter] = []
    @State private var selectedGlyph: String?
    @State private var questionIndex = 0
    @State private var correctCount = 0
    @State private var isFinished = false
    @State private var showingScore = false
    @State private var isRetryingMistakes = false
    @State private var firstRoundCorrectCount = 0
    @State private var firstRoundQuestionCount = 0
    @State private var answerAdvanceTask: Task<Void, Never>?

    private var questionCount: Int { wordPool.count }
    private var isAnswered: Bool { selectedGlyph != nil }
    private var answeredCorrectly: Bool { selectedGlyph != nil && selectedGlyph == target?.glyph }

    var body: some View {
        ZStack {
            StorybookBackground()

            if app.characters.count < 4 {
                notEnoughWords
            } else if showingScore {
                roundScoreScreen
            } else if isFinished {
                resultScreen
            } else {
                questionScreen
            }

        }
        .task {
            wordPool = initialCharacters.shuffled()
            if !wordPool.isEmpty && app.characters.count >= 4 {
                answerPositionQueue = makeAnswerPositionQueue(count: wordPool.count)
                startQuestion()
            }
        }
        .onDisappear {
            answerAdvanceTask?.cancel()
            speech.stop()
        }
    }

    private var questionScreen: some View {
        VStack(spacing: 20) {
            HStack {
                Button { speech.stop(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(GamePalette.ink)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 2) {
                    Text("听音找字")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(GamePalette.ink)
                    Text("第 \(questionIndex + 1) 题 / 共 \(questionCount) 题")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GamePalette.muted)
                    Text(setName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(GamePalette.orange)
                }
                Spacer()
                Text("⭐️ \(correctCount)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(GamePalette.ink)
                    .frame(width: 64)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(GamePalette.lilac.opacity(0.45))
                    Capsule()
                        .fill(GamePalette.orange)
                        .frame(width: geometry.size.width * CGFloat(questionIndex + 1) / CGFloat(max(questionCount, 1)))
                }
            }
            .frame(height: 8)

            VStack(spacing: 11) {
                Text("仔细听一听，是哪个汉字？")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(GamePalette.ink)
                Button(action: replayTarget) {
                    HStack(spacing: 10) {
                        Image(systemName: speech.isSpeaking ? "waveform" : "speaker.wave.2.fill")
                            .font(.system(size: 23, weight: .bold))
                        Text(speech.isSpeaking ? "正在朗读…" : "再听一次")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(GamePalette.ink)
                    .padding(.horizontal, 22).frame(height: 54)
                    .background(GamePalette.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(target == nil || isAnswered)
                .opacity(isAnswered ? 0.65 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(Array(options.enumerated()), id: \.element.glyph) { index, option in
                    answerCard(option, index: index)
                }
            }
            .frame(maxWidth: 560)

            if isAnswered {
                Color.clear.frame(height: 48)
            } else {
                Text("听不清楚？可以再点一次喇叭")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(GamePalette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 25)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: 760, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }

    private func answerCard(_ item: LearningCharacter, index: Int) -> some View {
        let isSelected = selectedGlyph == item.glyph
        let isCorrectTarget = target?.glyph == item.glyph
        let background: Color = {
            guard isAnswered && isSelected else { return GamePalette.answerTiles[index % GamePalette.answerTiles.count] }
            return isCorrectTarget ? GamePalette.correctTile : GamePalette.wrong
        }()

        return Button {
            choose(item)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(item.glyph)
                        .font(.system(size: 68, weight: .bold, design: .serif))
                        .foregroundStyle(isAnswered && isSelected && !isCorrectTarget ? .white : GamePalette.ink)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 155)
                .background(background, in: RoundedRectangle(cornerRadius: 27))
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(GamePalette.tileOutline, lineWidth: 2)
                }
                .shadow(color: GamePalette.ink.opacity(0.10), radius: 5, x: 0, y: 3)
                if isAnswered && isSelected {
                    Image(systemName: isCorrectTarget ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isCorrectTarget ? GamePalette.correctInk : .white)
                        .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选项 \(index + 1)：\(item.glyph)")
    }

    private var notEnoughWords: some View {
        VStack(spacing: 18) {
            Text("🎧").font(.system(size: 76))
            Text("还差一点点就能开玩啦")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(GamePalette.ink)
            Text("听音找字需要至少 4 个汉字，先去图鉴里收集一些吧。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(GamePalette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button(action: onCollect) {
                Text("去收集汉字")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(GamePalette.ink)
                    .frame(width: 220, height: 56)
                    .background(GamePalette.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
            Button("先回首页") { dismiss() }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(GamePalette.muted)
        }
        .padding(28)
    }

    private var resultScreen: some View {
        VStack(spacing: 19) {
            Text(firstRoundCorrectCount == firstRoundQuestionCount ? "🏆" : "🎉")
                .font(.system(size: 84))
            Text(isRetryingMistakes ? "错字都掌握啦！" : (firstRoundCorrectCount == firstRoundQuestionCount ? "听力小冠军！" : "这一轮完成啦！"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(GamePalette.ink)
            Text("首轮得分：\(firstRoundCorrectCount) / \(firstRoundQuestionCount)")
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(GamePalette.muted)
            HStack(spacing: 8) {
                ForEach(0..<min(firstRoundQuestionCount, 5), id: \.self) { index in
                    Text(index < firstRoundCorrectCount ? "⭐️" : "☆")
                        .font(.system(size: 31, weight: .bold))
                }
            }
            Button("再玩一轮") {
                resetGame()
            }
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(GamePalette.ink)
            .frame(width: 230, height: 56)
            .background(GamePalette.yellow, in: Capsule())
            Button("回到首页") { dismiss() }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(GamePalette.muted)
        }
        .padding(28)
    }

    private var roundScoreScreen: some View {
        VStack(spacing: 20) {
            Text(isRetryingMistakes ? "📝" : "🏅")
                .font(.system(size: 78))
            Text(isRetryingMistakes ? "错字练习完成" : "本轮成绩")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(GamePalette.ink)
            Text(isRetryingMistakes
                 ? "这轮答对 \(correctCount) / \(questionCount) 个，还剩 \(missedCharacters.count) 个字要练习"
                 : "答对 \(firstRoundCorrectCount) / \(firstRoundQuestionCount) 题")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(GamePalette.muted)

            if !missedCharacters.isEmpty {
                Button(isRetryingMistakes ? "继续练习错字（\(missedCharacters.count)）" : "练习错字（\(missedCharacters.count)）") {
                    beginMistakeReview()
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(GamePalette.ink)
                .frame(maxWidth: 300, minHeight: 58)
                .background(GamePalette.yellow, in: Capsule())
                .buttonStyle(.plain)
            } else if isRetryingMistakes {
                Button("查看总成绩") { isFinished = true; showingScore = false }
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(GamePalette.ink)
                    .frame(maxWidth: 300, minHeight: 58)
                    .background(GamePalette.mint, in: Capsule())
                    .buttonStyle(.plain)
            }

            if !isRetryingMistakes {
                Button("结束练习") { isFinished = true; showingScore = false }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GamePalette.muted)
                    .buttonStyle(.plain)
            }
        }
        .padding(28)
    }

    private func startQuestion() {
        guard !wordPool.isEmpty, app.characters.count >= 4 else { return }
        if targetQueue.isEmpty {
            targetQueue = wordPool.shuffled()
            if let previousTarget = target?.glyph,
               targetQueue.first?.glyph == previousTarget,
               targetQueue.count > 1 {
                targetQueue.swapAt(0, 1)
            }
        }
        let nextTarget = targetQueue.removeFirst()
        let distractors = app.characters.filter { $0.glyph != nextTarget.glyph }.shuffled().prefix(3)
        target = nextTarget
        var shuffledOptions = Array(distractors)
        let answerPosition = answerPositionQueue.removeFirst()
        shuffledOptions.insert(nextTarget, at: answerPosition)
        options = shuffledOptions
        selectedGlyph = nil
        speakTarget(nextTarget)
    }

    private func replayTarget() {
        guard let target else { return }
        speakTarget(target)
    }

    private func speakTarget(_ character: LearningCharacter) {
        speech.speak(character.pronunciations.first?.example ?? character.glyph)
    }

    private func choose(_ answer: LearningCharacter) {
        guard selectedGlyph == nil, let target else { return }
        let isCorrect = answer.glyph == target.glyph
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            selectedGlyph = answer.glyph
        }
        speech.stop()
        if isCorrect {
            correctCount += 1
            // speech.speakEncouragement()
        } else {
            missedCharacters.append(target)
        }
        app.recordListeningAnswer(target: target.glyph, answer: answer.glyph, correct: isCorrect)

        answerAdvanceTask?.cancel()
        answerAdvanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        if questionIndex + 1 >= questionCount {
            speech.stop()
            if isRetryingMistakes {
                showingScore = true
            } else {
                firstRoundCorrectCount = correctCount
                firstRoundQuestionCount = questionCount
                if missedCharacters.isEmpty {
                    isFinished = true
                } else {
                    showingScore = true
                }
            }
        } else {
            questionIndex += 1
            startQuestion()
        }
    }

    private func beginMistakeReview() {
        guard !missedCharacters.isEmpty else { return }
        wordPool = missedCharacters.shuffled()
        missedCharacters.removeAll()
        targetQueue.removeAll()
        answerPositionQueue = makeAnswerPositionQueue(count: wordPool.count)
        target = nil
        questionIndex = 0
        correctCount = 0
        isRetryingMistakes = true
        showingScore = false
        startQuestion()
    }

    private func resetGame() {
        wordPool = initialCharacters.shuffled()
        targetQueue.removeAll()
        answerPositionQueue = makeAnswerPositionQueue(count: wordPool.count)
        missedCharacters.removeAll()
        target = nil
        questionIndex = 0
        correctCount = 0
        selectedGlyph = nil
        showingScore = false
        isRetryingMistakes = false
        firstRoundCorrectCount = 0
        firstRoundQuestionCount = 0
        isFinished = false
        if !wordPool.isEmpty && app.characters.count >= 4 { startQuestion() }
    }

    private func makeAnswerPositionQueue(count: Int) -> [Int] {
        var positions: [Int] = []
        var previousPosition: Int?

        while positions.count < count {
            var group = Array(0..<4).shuffled()
            if let previousPosition, group.first == previousPosition {
                group.swapAt(0, 1)
            }
            positions.append(contentsOf: group)
            previousPosition = group.last
        }

        return Array(positions.prefix(count))
    }
}
