import SwiftUI

private enum PinyinPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let colors = [KidsTheme.mint, KidsTheme.yellow, KidsTheme.lilac, KidsTheme.blue, KidsTheme.peach, Color(red: 0.69, green: 0.82, blue: 0.96)]
}

struct PinyinModuleScreen: View {
    let app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("来认识拼音朋友吧！")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                        Text("点一张卡片听读音，再去拼读台试一试。")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(PinyinPalette.muted)
                        Text("已听学 \(app.studiedPinyinItems.intersection(Set(PinyinCatalog.categories.flatMap(\.items).map(\.id))).count) / \(PinyinCatalog.categories.reduce(0) { $0 + $1.items.count })")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(KidsTheme.yellow, in: Capsule())
                    }
                    .padding(.top, 8)

                    NavigationLink {
                        PinyinSpellingScreen(app: app)
                    } label: {
                        HStack(spacing: 14) {
                            Text("拼")
                                .font(.system(size: 35, weight: .black, design: .rounded))
                                .frame(width: 60, height: 60)
                                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("拼读小火车")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                Text("选声母、韵母和声调，拼成一个音节")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .opacity(0.78)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 28))
                        }
                        .foregroundStyle(PinyinPalette.ink)
                        .padding(16)
                        .background(KidsTheme.orange.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PinyinListeningSetupScreen()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "ear.and.waveform")
                                .font(.system(size: 30, weight: .black))
                                .frame(width: 60, height: 60)
                                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("听音闯关")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                Text("听拼音，在四个选项里找答案")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .opacity(0.78)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                        }
                        .foregroundStyle(PinyinPalette.ink)
                        .padding(16)
                        .background(KidsTheme.mint.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PinyinWorksheetDictationScreen(app: app)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 29, weight: .black))
                                .frame(width: 60, height: 60)
                                .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("拼音听写")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                Text("不限时，可重播和慢速播放，错题再练")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .opacity(0.78)
                            }
                            Spacer(minLength: 2)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 28))
                        }
                        .foregroundStyle(PinyinPalette.ink)
                        .padding(16)
                        .background(KidsTheme.blue.opacity(0.78), in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PinyinTonePracticeScreen()
                    } label: {
                        HStack(spacing: 14) {
                            Text("āáǎà")
                                .font(.system(size: 27, weight: .black, design: .rounded))
                                .frame(width: 76, height: 60)
                                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("单韵母四声")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                Text("点读 a、o、e、i、u、ü 的四个声调")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .opacity(0.78)
                            }
                            Spacer(minLength: 2)
                            Image(systemName: "speaker.wave.2.circle.fill")
                                .font(.system(size: 28))
                        }
                        .foregroundStyle(PinyinPalette.ink)
                        .padding(16)
                        .background(KidsTheme.lilac.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(PinyinCatalog.categories.enumerated()), id: \.element.id) { index, category in
                            NavigationLink {
                                PinyinCategoryScreen(app: app, category: category)
                            } label: {
                                categoryCard(category, color: PinyinPalette.colors[index % PinyinPalette.colors.count])
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 25)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle("拼音乐园")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }

    private func categoryCard(_ category: PinyinCategory, color: Color) -> some View {
        let studiedCount = category.items.filter { app.studiedPinyinItems.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 20))
            }
            Text(category.subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .opacity(0.75)
            Text("\(studiedCount) / \(category.items.count) 已听学")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white.opacity(0.65), in: Capsule())
        }
        .foregroundStyle(PinyinPalette.ink)
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 119, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct PinyinTonePracticeScreen: View {
    @State private var audio = PinyinAudioPlayer()
    @State private var playingID: String?

    private let vowels = ["a", "o", "e", "i", "u", "ü"]
    private let tones = ["一声", "二声", "三声", "四声"]
    private let toneColors = [KidsTheme.mint, KidsTheme.yellow, KidsTheme.lilac, KidsTheme.peach]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("单韵母四声")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    Text("点每个拼音，听它单独的声调读音。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                }

                VStack(spacing: 12) {
                    ForEach(vowels, id: \.self) { vowel in
                        HStack(spacing: 10) {
                            Text(vowel)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(PinyinPalette.ink)
                                .frame(width: 48)

                            ForEach(1...4, id: \.self) { tone in
                                let itemID = "\(vowel)-\(tone)"
                                let isPlaying = playingID == itemID
                                Button {
                                    playingID = itemID
                                    _ = audio.playStandaloneVowel(vowel, tone: tone)
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(PinyinCatalog.syllable(initial: "", final: vowel, tone: tone))
                                            .font(.system(size: 25, weight: .black, design: .rounded))
                                        Text(tones[tone - 1])
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(PinyinPalette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 68)
                                    .background(isPlaying ? toneColors[tone - 1] : .white.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(isPlaying ? PinyinPalette.ink.opacity(0.16) : .clear, lineWidth: 2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(PinyinCatalog.syllable(initial: "", final: vowel, tone: tone))，\(tones[tone - 1])，播放拼音")
                            }
                        }
                    }
                }

                Text("录音来自拼音教学语音素材。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle("单韵母四声")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PinyinDictationSetupScreen: View {
    @State private var selectedCategoryIDs = Set(PinyinCatalog.categories.map(\.id))

    private var selectedItems: [PinyinUnit] {
        PinyinCatalog.categories
            .filter { selectedCategoryIDs.contains($0.id) }
            .flatMap(\.items)
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("选择听写范围")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    Text("每次练习最多 10 个拼音，不限时，可以慢慢听、慢慢写。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                }

                HStack {
                    Text("已选 \(selectedCategoryIDs.count) 类 · \(selectedItems.count) 个拼音")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    Spacer()
                    Button(selectedCategoryIDs.count == PinyinCatalog.categories.count ? "取消全选" : "全选") {
                        if selectedCategoryIDs.count == PinyinCatalog.categories.count {
                            selectedCategoryIDs.removeAll()
                        } else {
                            selectedCategoryIDs = Set(PinyinCatalog.categories.map(\.id))
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(PinyinCatalog.categories.enumerated()), id: \.element.id) { index, category in
                        let isSelected = selectedCategoryIDs.contains(category.id)
                        Button {
                            if isSelected {
                                selectedCategoryIDs.remove(category.id)
                            } else {
                                selectedCategoryIDs.insert(category.id)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(category.title)
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .lineLimit(1).minimumScaleFactor(0.72)
                                    Spacer(minLength: 2)
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19, weight: .bold))
                                }
                                Text("\(category.items.count) 个拼音")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(PinyinPalette.ink)
                            .padding(13)
                            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                            .background(
                                isSelected ? PinyinPalette.colors[index % PinyinPalette.colors.count] : .white.opacity(0.82),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(isSelected ? PinyinPalette.ink.opacity(0.14) : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("听不清就再播放，也可以切换慢速。", systemImage: "speaker.wave.2.fill")
                    Label("写错了会先鼓励重听，之后显示答案并放进错题复习。", systemImage: "heart.fill")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(PinyinPalette.muted)
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 18))

                NavigationLink {
                    PinyinDictationGameScreen(items: selectedItems)
                } label: {
                    Label("开始听写", systemImage: "pencil.and.outline")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(KidsTheme.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedItems.isEmpty)
                .opacity(selectedItems.isEmpty ? 0.45 : 1)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle("拼音听写")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PinyinDictationGameScreen: View {
    let items: [PinyinUnit]
    @Environment(\.dismiss) private var dismiss
    @FocusState private var answerFocused: Bool
    @State private var audio = PinyinAudioPlayer()
    @State private var questions: [PinyinUnit] = []
    @State private var questionIndex = 0
    @State private var answer = ""
    @State private var isSlowPlayback = false
    @State private var attemptCount = 0
    @State private var didSolve = false
    @State private var revealedAnswer = false
    @State private var feedback: String?
    @State private var firstRoundWrongItems: [PinyinUnit] = []
    @State private var roundWrongItems: [PinyinUnit] = []
    @State private var finalWrongItems: [PinyinUnit] = []
    @State private var firstRoundCorrectCount = 0
    @State private var firstRoundQuestionCount = 0
    @State private var isReviewRound = false
    @State private var isFinished = false

    private var currentQuestion: PinyinUnit? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    var body: some View {
        Group {
            if isFinished {
                resultView
            } else if let currentQuestion {
                questionView(for: currentQuestion)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StorybookBackground() }
        .navigationTitle(isReviewRound ? "错题跟读" : "拼音听写")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDismissToolbar { answerFocused = false }
        .onAppear {
            guard questions.isEmpty else { return }
            let firstQuestions = Array(items.shuffled().prefix(10))
            firstRoundQuestionCount = firstQuestions.count
            beginRound(with: firstQuestions, review: false)
        }
    }

    private func questionView(for target: PinyinUnit) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text(isReviewRound ? "错题复习 · \(questionIndex + 1) / \(questions.count)" : "第 \(questionIndex + 1) / \(questions.count) 题")
                    Spacer()
                    Text("首答答对 \(firstRoundCorrectCount) 题")
                }
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.white.opacity(0.86), in: Capsule())

                ProgressView(value: Double(questionIndex + 1), total: Double(max(questions.count, 1)))
                    .tint(KidsTheme.orange)

                VStack(spacing: 12) {
                    Text("听清楚后，把拼音写下来")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)

                    Button {
                        playCurrent()
                    } label: {
                        Label(isSlowPlayback ? "播放拼音 · 慢速" : "播放拼音", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(KidsTheme.yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        isSlowPlayback.toggle()
                        playCurrent()
                    } label: {
                        Label(isSlowPlayback ? "慢速播放已开启 · 点此恢复正常" : "听不清？切换慢速播放", systemImage: isSlowPlayback ? "tortoise.fill" : "hare.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(PinyinPalette.muted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.82), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isSlowPlayback ? "慢速" : "正常速度")
                }
                .padding(18)
                .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 9) {
                    Text("写下你听到的拼音")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                    TextField("例如：zh、ang、zhi", text: $answer)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                        .tint(KidsTheme.orange)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .focused($answerFocused)
                        .onSubmit(checkAnswer)
                        .padding(.horizontal, 15)
                        .frame(height: 64)
                        .background(.white, in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(PinyinPalette.ink.opacity(0.12), lineWidth: 1))

                    Button(action: checkAnswer) {
                        Label("检查答案", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(KidsTheme.mint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || didSolve || revealedAnswer)
                    .opacity(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || didSolve || revealedAnswer ? 0.5 : 1)
                }
                .padding(17)
                .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22))

                if didSolve {
                    Label("答对啦！慢慢听，就能听准。", systemImage: "star.fill")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.17, green: 0.55, blue: 0.34))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(KidsTheme.mint.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                } else if revealedAnswer {
                    VStack(spacing: 8) {
                        Text("正确答案是：\(target.symbol)")
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                        Text("再听一次，跟着读一遍，然后继续。")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PinyinPalette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(KidsTheme.peach.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                } else if let feedback {
                    Label(feedback, systemImage: "ear.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
                }

                if didSolve || revealedAnswer {
                    Button(action: advanceQuestion) {
                        Label(questionIndex + 1 == questions.count ? "完成本轮" : "准备好了，下一题", systemImage: "arrow.right")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(KidsTheme.yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            Image(systemName: finalWrongItems.isEmpty ? "star.circle.fill" : "repeat.circle.fill")
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(finalWrongItems.isEmpty ? KidsTheme.yellow : KidsTheme.blue)
            Text(isReviewRound ? (finalWrongItems.isEmpty ? "错题都听会啦！" : "再跟读一次错题") : (finalWrongItems.isEmpty ? "听写完成！" : "错题复习完成"))
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
            Text("首轮答对 \(firstRoundCorrectCount) / \(firstRoundQuestionCount) 题")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(PinyinPalette.muted)

            if !finalWrongItems.isEmpty {
                Text("还有 \(finalWrongItems.count) 个拼音可以再练。")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
                Button {
                    beginRound(with: finalWrongItems.shuffled(), review: true)
                } label: {
                    Label("再练错题", systemImage: "arrow.clockwise")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                        .frame(maxWidth: 320, minHeight: 52)
                        .background(KidsTheme.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button("返回拼音乐园") { dismiss() }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
                .padding(.horizontal, 24)
                .frame(height: 50)
                .background(.white, in: Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playCurrent() {
        guard let currentQuestion else { return }
        let rate: Float = isSlowPlayback ? 0.75 : 1.0
        _ = audio.play(currentQuestion, rate: rate)
    }

    private func checkAnswer() {
        guard !didSolve, !revealedAnswer, let currentQuestion else { return }
        let submitted = normalize(answer)
        guard !submitted.isEmpty else { return }
        answerFocused = false

        if submitted == normalize(currentQuestion.symbol) {
            didSolve = true
            feedback = nil
            if attemptCount == 0 && !isReviewRound { firstRoundCorrectCount += 1 }
            return
        }

        if isReviewRound {
            appendUnique(currentQuestion, to: &roundWrongItems)
        } else {
            appendUnique(currentQuestion, to: &firstRoundWrongItems)
        }
        attemptCount += 1
        if attemptCount >= 2 {
            revealedAnswer = true
            feedback = nil
        } else {
            feedback = "没关系，再听一次。可以切换慢速，再试试看。"
        }
    }

    private func advanceQuestion() {
        answerFocused = false
        guard questionIndex + 1 < questions.count else {
            if isReviewRound {
                finalWrongItems = roundWrongItems
                isFinished = true
            } else if firstRoundWrongItems.isEmpty {
                finalWrongItems = []
                isFinished = true
            } else {
                beginRound(with: firstRoundWrongItems.shuffled(), review: true)
            }
            return
        }

        questionIndex += 1
        resetQuestionState()
        playCurrent()
    }

    private func beginRound(with newQuestions: [PinyinUnit], review: Bool) {
        questions = newQuestions
        questionIndex = 0
        roundWrongItems = []
        isReviewRound = review
        isFinished = newQuestions.isEmpty
        resetQuestionState()
        playCurrent()
    }

    private func resetQuestionState() {
        answer = ""
        attemptCount = 0
        didSolve = false
        revealedAnswer = false
        feedback = nil
    }

    private func appendUnique(_ item: PinyinUnit, to collection: inout [PinyinUnit]) {
        guard !collection.contains(where: { $0.id == item.id }) else { return }
        collection.append(item)
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter }
            .replacingOccurrences(of: "ü", with: "v")
    }
}

private struct PinyinListeningSetupScreen: View {
    @State private var selectedCategoryIDs = Set(PinyinCatalog.categories.map(\.id))

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var selectedItems: [PinyinUnit] {
        PinyinCatalog.categories
            .filter { selectedCategoryIDs.contains($0.id) }
            .flatMap(\.items)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("选择练习范围")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    Text("可选择一个或多个类别，默认全部练习。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                }

                HStack {
                    Text("已选 \(selectedCategoryIDs.count) 类 · \(selectedItems.count) 个拼音")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    Spacer()
                    Button(selectedCategoryIDs.count == PinyinCatalog.categories.count ? "取消全选" : "全选") {
                        if selectedCategoryIDs.count == PinyinCatalog.categories.count {
                            selectedCategoryIDs.removeAll()
                        } else {
                            selectedCategoryIDs = Set(PinyinCatalog.categories.map(\.id))
                        }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(PinyinCatalog.categories.enumerated()), id: \.element.id) { index, category in
                        let isSelected = selectedCategoryIDs.contains(category.id)
                        Button {
                            if isSelected {
                                selectedCategoryIDs.remove(category.id)
                            } else {
                                selectedCategoryIDs.insert(category.id)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(category.title)
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .lineLimit(1).minimumScaleFactor(0.75)
                                    Spacer(minLength: 3)
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19, weight: .bold))
                                }
                                Text("\(category.items.count) 个拼音")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(PinyinPalette.ink)
                            .padding(13)
                            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                            .background(
                                isSelected ? PinyinPalette.colors[index % PinyinPalette.colors.count] : .white.opacity(0.8),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(isSelected ? PinyinPalette.ink.opacity(0.15) : .clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }

                NavigationLink {
                    PinyinListeningGameScreen(items: selectedItems)
                } label: {
                    Label("开始闯关", systemImage: "play.fill")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(KidsTheme.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedItems.count < 4)
                .opacity(selectedItems.count < 4 ? 0.45 : 1)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle("听音闯关")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PinyinListeningGameScreen: View {
    let items: [PinyinUnit]
    @Environment(\.dismiss) private var dismiss
    @State private var audio = PinyinAudioPlayer()
    @State private var questions: [PinyinUnit] = []
    @State private var questionIndex = 0
    @State private var options: [PinyinUnit] = []
    @State private var selectedAnswerID: String?
    @State private var roundWrongItems: [PinyinUnit] = []
    @State private var finalWrongItems: [PinyinUnit] = []
    @State private var firstRoundQuestionCount = 0
    @State private var firstRoundCorrectCount = 0
    @State private var isReviewRound = false
    @State private var isFinished = false

    private let questionLimit = 10
    private let choiceColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var currentQuestion: PinyinUnit? {
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    var body: some View {
        Group {
            if isFinished {
                resultView
            } else if let currentQuestion {
                questionView(for: currentQuestion)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StorybookBackground() }
        .navigationTitle(isReviewRound ? "错题再挑战" : "听音闯关")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard questions.isEmpty else { return }
            let initialQuestions = Array(items.shuffled().prefix(questionLimit))
            firstRoundQuestionCount = initialQuestions.count
            beginRound(with: initialQuestions, review: false)
        }
    }

    private func questionView(for target: PinyinUnit) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(isReviewRound ? "错题复习 · \(questionIndex + 1) / \(questions.count)" : "第 \(questionIndex + 1) / \(questions.count) 题")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
                ProgressView(value: Double(questionIndex + 1), total: Double(max(questions.count, 1)))
                    .tint(KidsTheme.orange)
            }

            VStack(spacing: 14) {
                Text("听一听，选出你听到的拼音")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(PinyinPalette.ink)
                    .multilineTextAlignment(.center)
                Button {
                    audio.play(target)
                } label: {
                    Label("再听一次", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                        .padding(.horizontal, 25).frame(height: 56)
                        .background(KidsTheme.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 25)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))

            LazyVGrid(columns: choiceColumns, spacing: 12) {
                ForEach(options) { option in
                    Button {
                        choose(option, for: target)
                    } label: {
                        Text(option.symbol)
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.65).lineLimit(1)
                            .foregroundStyle(PinyinPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .background(optionBackground(for: option, target: target), in: RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(optionBorder(for: option, target: target), lineWidth: 3)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAnswerID != nil)
                }
            }

            if let selectedAnswerID {
                let wasCorrect = selectedAnswerID == target.id
                Label(wasCorrect ? "答对了！" : "再听再记，绿色的是正确答案", systemImage: wasCorrect ? "checkmark.circle.fill" : "lightbulb.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(wasCorrect ? Color.green : KidsTheme.red)
                    .frame(minHeight: 24)
            } else {
                Text("选择一个答案")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
                    .frame(minHeight: 24)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if options.isEmpty { makeOptionsAndPlay(for: target) }
        }
    }

    private var resultView: some View {
        VStack(spacing: 18) {
            Image(systemName: finalWrongItems.isEmpty ? "star.circle.fill" : "repeat.circle.fill")
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(finalWrongItems.isEmpty ? KidsTheme.yellow : KidsTheme.blue)
            Text(finalWrongItems.isEmpty ? "全部答对啦！" : "这一轮完成啦！")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
            Text("首轮答对 \(firstRoundCorrectCount) / \(firstRoundQuestionCount) 题")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(PinyinPalette.muted)

            if finalWrongItems.isEmpty {
                Text("拼音听得真准，继续加油！")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
            } else {
                Text("还有 \(finalWrongItems.count) 题可以再练习。")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
                Button("再复习一次") {
                    beginRound(with: finalWrongItems.shuffled(), review: true)
                }
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
                .padding(.horizontal, 24).frame(height: 52)
                .background(KidsTheme.yellow, in: Capsule())
            }

            Button("返回拼音乐园") { dismiss() }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
                .padding(.horizontal, 24).frame(height: 50)
                .background(.white, in: Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func beginRound(with newQuestions: [PinyinUnit], review: Bool) {
        questions = newQuestions
        questionIndex = 0
        roundWrongItems = []
        finalWrongItems = []
        selectedAnswerID = nil
        options = []
        isReviewRound = review
        isFinished = newQuestions.isEmpty
        if let firstQuestion = newQuestions.first {
            makeOptionsAndPlay(for: firstQuestion)
        }
    }

    private func makeOptionsAndPlay(for target: PinyinUnit) {
        let distractors = items
            .filter { $0.id != target.id && $0.symbol != target.symbol }
            .shuffled()
            .prefix(3)
        options = ([target] + Array(distractors)).shuffled()
        audio.play(target)
    }

    private func choose(_ option: PinyinUnit, for target: PinyinUnit) {
        guard selectedAnswerID == nil else { return }
        selectedAnswerID = option.id
        if option.id != target.id {
            roundWrongItems.append(target)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            advanceRound()
        }
    }

    private func advanceRound() {
        if questionIndex + 1 < questions.count {
            questionIndex += 1
            selectedAnswerID = nil
            if let nextQuestion = currentQuestion {
                makeOptionsAndPlay(for: nextQuestion)
            }
            return
        }

        if isReviewRound {
            finalWrongItems = roundWrongItems
            isFinished = true
        } else {
            firstRoundCorrectCount = questions.count - roundWrongItems.count
            if roundWrongItems.isEmpty {
                finalWrongItems = []
                isFinished = true
            } else {
                beginRound(with: roundWrongItems.shuffled(), review: true)
            }
        }
    }

    private func optionBackground(for option: PinyinUnit, target: PinyinUnit) -> Color {
        guard let selectedAnswerID else { return .white.opacity(0.85) }
        if selectedAnswerID == option.id && option.id == target.id { return KidsTheme.mint }
        if selectedAnswerID == option.id { return KidsTheme.red.opacity(0.72) }
        if option.id == target.id { return KidsTheme.mint }
        return .white.opacity(0.85)
    }

    private func optionBorder(for option: PinyinUnit, target: PinyinUnit) -> Color {
        guard let selectedAnswerID else { return .clear }
        if option.id == target.id { return Color.green.opacity(0.8) }
        if option.id == selectedAnswerID { return KidsTheme.red }
        return .clear
    }
}

private struct PinyinCategoryScreen: View {
    let app: AppModel
    let category: PinyinCategory
    @State private var audio = PinyinAudioPlayer()

    private let columns = [GridItem(.adaptive(minimum: 138), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(category.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    Text(category.subtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            app.recordPinyinStudy(itemID: item.id)
                            audio.play(item)
                        } label: {
                            VStack(spacing: 8) {
                                HStack {
                                    Spacer()
                                    Image(systemName: app.studiedPinyinItems.contains(item.id) ? "checkmark.circle.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                Text(item.symbol)
                                    .font(.system(size: item.symbol.count > 2 ? 36 : 44, weight: .black, design: .rounded))
                                    .minimumScaleFactor(0.65).lineLimit(1)
                                Text(item.examplePinyin)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                Text(item.example)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(PinyinPalette.ink)
                            .padding(13)
                            .frame(maxWidth: .infinity, minHeight: 138)
                            .background(PinyinPalette.colors[index % PinyinPalette.colors.count], in: RoundedRectangle(cornerRadius: 21))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.symbol)，示范读音 \(item.examplePinyin)，点击听拼音")
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PinyinSpellingScreen: View {
    let app: AppModel
    @State private var speech = SpeechPlayer()
    @State private var syllableAudio = PinyinAudioPlayer()
    @State private var selectedInitial = "b"
    @State private var selectedFinal = "a"
    @State private var selectedTone = 1

    private let toneMarks = ["一声", "二声", "三声", "四声", "轻声"]
    private let toneColors = [KidsTheme.mint, KidsTheme.yellow, KidsTheme.lilac, KidsTheme.peach, KidsTheme.blue]
    private var availableFinals: [String] { PinyinCatalog.finals(for: selectedInitial) }
    private var displayedSyllable: String { PinyinCatalog.syllable(initial: selectedInitial, final: selectedFinal, tone: selectedTone) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("先选声母，再选韵母和声调。")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(PinyinPalette.muted)
                Text("本档案已练习 \(app.studiedPinyinItems.filter { $0.hasPrefix("spelling:") }.count) 组拼读")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PinyinPalette.ink)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(KidsTheme.mint.opacity(0.65), in: Capsule())

                selectionSection(title: "① 选择声母", values: PinyinCatalog.initials, selection: $selectedInitial, columns: 6)
                    .onChange(of: selectedInitial) { _, newValue in
                        let finals = PinyinCatalog.finals(for: newValue)
                        if !finals.contains(selectedFinal) { selectedFinal = finals.first ?? "a" }
                    }
                selectionSection(title: "② 选择韵母（只显示可拼读组合）", values: availableFinals, selection: $selectedFinal, columns: 6)
                VStack(alignment: .leading, spacing: 10) {
                    Text("③ 选择声调")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(PinyinPalette.ink)
                    HStack(spacing: 8) {
                        ForEach(0..<toneMarks.count, id: \.self) { index in
                            Button { selectedTone = index == 4 ? 0 : index + 1 } label: {
                                Text(toneMarks[index])
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(PinyinPalette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background((selectedTone == (index == 4 ? 0 : index + 1) ? toneColors[index] : .white), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 12) {
                    Text("\(selectedInitial) + \(selectedFinal) = \(displayedSyllable)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.7).lineLimit(1)
                        .foregroundStyle(PinyinPalette.ink)
                    Text(PinyinCatalog.spellingExample(initial: selectedInitial, final: selectedFinal, tone: selectedTone))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PinyinPalette.muted)
                    Button {
                        let itemID = "spelling:\(selectedInitial):\(selectedFinal):\(selectedTone)"
                        app.recordPinyinStudy(itemID: itemID)
                        if !syllableAudio.playSpelling(initial: selectedInitial, final: selectedFinal, tone: selectedTone) {
                            speech.speak(PinyinCatalog.spellingAudio(initial: selectedInitial, final: selectedFinal, tone: selectedTone))
                        }
                    } label: {
                        Label("听拼读", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(PinyinPalette.ink)
                            .padding(.horizontal, 25).frame(height: 54)
                            .background(KidsTheme.yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(23)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 26))
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle("拼读小火车")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectionSection(title: String, values: [String], selection: Binding<String>, columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(PinyinPalette.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: columns), spacing: 8) {
                ForEach(values, id: \.self) { value in
                    let isSelected = selection.wrappedValue == value
                    Button { selection.wrappedValue = value } label: {
                        Text(value)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .foregroundStyle(PinyinPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 43)
                            .background(isSelected ? KidsTheme.yellow : .white, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(15)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
    }
}
