import AVFoundation
import SwiftUI

struct AlphabetLetter: Identifiable {
    let upper: String
    let lower: String
    let nameSound: String
    let commonSound: String
    let example: String
    let picture: String

    var id: String { upper }
    var examplePhrase: String { "\(upper) is for \(example)." }
}

enum AlphabetCatalog {
    static let all: [AlphabetLetter] = [
        .init(upper: "A", lower: "a", nameSound: "/eɪ/", commonSound: "/æ/", example: "apple", picture: "🍎"),
        .init(upper: "B", lower: "b", nameSound: "/biː/", commonSound: "/b/", example: "banana", picture: "🍌"),
        .init(upper: "C", lower: "c", nameSound: "/siː/", commonSound: "/k/", example: "cat", picture: "🐱"),
        .init(upper: "D", lower: "d", nameSound: "/diː/", commonSound: "/d/", example: "duck", picture: "🦆"),
        .init(upper: "E", lower: "e", nameSound: "/iː/", commonSound: "/ɛ/", example: "egg", picture: "🥚"),
        .init(upper: "F", lower: "f", nameSound: "/ɛf/", commonSound: "/f/", example: "fish", picture: "🐟"),
        .init(upper: "G", lower: "g", nameSound: "/dʒiː/", commonSound: "/g/", example: "gate", picture: "🚪"),
        .init(upper: "H", lower: "h", nameSound: "/eɪtʃ/", commonSound: "/h/", example: "horse", picture: "🐴"),
        .init(upper: "I", lower: "i", nameSound: "/aɪ/", commonSound: "/ɪ/", example: "igloo", picture: "🧊"),
        .init(upper: "J", lower: "j", nameSound: "/dʒeɪ/", commonSound: "/dʒ/", example: "jam", picture: "🍓"),
        .init(upper: "K", lower: "k", nameSound: "/keɪ/", commonSound: "/k/", example: "kangaroo", picture: "🦘"),
        .init(upper: "L", lower: "l", nameSound: "/ɛl/", commonSound: "/l/", example: "lion", picture: "🦁"),
        .init(upper: "M", lower: "m", nameSound: "/ɛm/", commonSound: "/m/", example: "mouse", picture: "🐭"),
        .init(upper: "N", lower: "n", nameSound: "/ɛn/", commonSound: "/n/", example: "nest", picture: "🪺"),
        .init(upper: "O", lower: "o", nameSound: "/oʊ/", commonSound: "/ɑ/", example: "octopus", picture: "🐙"),
        .init(upper: "P", lower: "p", nameSound: "/piː/", commonSound: "/p/", example: "pig", picture: "🐷"),
        .init(upper: "Q", lower: "q", nameSound: "/kjuː/", commonSound: "/kw/", example: "queen", picture: "👑"),
        .init(upper: "R", lower: "r", nameSound: "/ɑr/", commonSound: "/r/", example: "road", picture: "🛣️"),
        .init(upper: "S", lower: "s", nameSound: "/ɛs/", commonSound: "/s/", example: "sun", picture: "☀️"),
        .init(upper: "T", lower: "t", nameSound: "/tiː/", commonSound: "/t/", example: "turtle", picture: "🐢"),
        .init(upper: "U", lower: "u", nameSound: "/juː/", commonSound: "/ʌ/", example: "umbrella", picture: "☂️"),
        .init(upper: "V", lower: "v", nameSound: "/viː/", commonSound: "/v/", example: "volcano", picture: "🌋"),
        .init(upper: "W", lower: "w", nameSound: "/ˈdʌbəl.juː/", commonSound: "/w/", example: "window", picture: "🪟"),
        .init(upper: "X", lower: "x", nameSound: "/ɛks/", commonSound: "/z/", example: "xylophone", picture: "🎼"),
        .init(upper: "Y", lower: "y", nameSound: "/waɪ/", commonSound: "/j/", example: "yoyo", picture: "🪀"),
        .init(upper: "Z", lower: "z", nameSound: "/ziː/", commonSound: "/z/", example: "zebra", picture: "🦓")
    ]
}

@MainActor
final class AlphabetSpeech {
    private var player: AVAudioPlayer?

    @discardableResult
    func play(_ resourceName: String, rate: Float = 1.0) -> Bool {
        let bundle = Bundle.main
        let extensions = ["mp3", "m4a", "wav", "caf"]
        let letterAudioURL: URL? = {
            guard resourceName.hasPrefix("name_"),
                  let letter = resourceName.split(separator: "_").last,
                  letter.count == 1 else { return nil }
            let filename = "alphabet_v2_\(String(letter).lowercased())"
            return bundle.url(forResource: filename, withExtension: "mp3", subdirectory: "Resources/AlphabetAudio_v2")
                ?? bundle.url(forResource: filename, withExtension: "mp3", subdirectory: "AlphabetAudio_v2")
                ?? bundle.url(forResource: filename, withExtension: "mp3")
        }()
        let url = letterAudioURL ?? extensions.lazy.compactMap { ext in
            bundle.url(forResource: resourceName, withExtension: ext, subdirectory: "Resources/AlphabetAudio")
                ?? bundle.url(forResource: resourceName, withExtension: ext, subdirectory: "AlphabetAudio")
                ?? bundle.url(forResource: resourceName, withExtension: ext)
        }.first
        guard let url else {
            NSLog("Missing bundled alphabet audio: %@", resourceName)
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
            player?.stop()
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = min(max(rate, 0.5), 2.0)
            player?.prepareToPlay()
            return player?.play() ?? false
        } catch {
            player = nil
            NSLog("Unable to play alphabet audio %@: %@", resourceName, error.localizedDescription)
            return false
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

struct AlphabetModuleScreen: View {
    let app: AppModel
    var snakeTicketPractice = false
    var ticketOptionDisplay: AlphabetOptionDisplay? = nil
    var onSnakeTicketEarned: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var speech = AlphabetSpeech()
    @State private var selectedTab = 0

    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !snakeTicketPractice {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("来认识 26 个字母朋友！")
                                .font(.system(size: 27, weight: .black, design: .rounded))
                                .foregroundStyle(KidsTheme.ink)
                            Text("听真人字母名称和示范句，练习认读 26 个字母。")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(KidsTheme.muted)
                            HStack(spacing: 8) {
                                Text("已听学 \(app.studiedAlphabetLetters.count) / 26")
                                Text("·")
                                Text("离线真人录音")
                            }
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(KidsTheme.ink)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(KidsTheme.yellow, in: Capsule())
                        }
                        .padding(.top, 8)

                        NavigationLink {
                            EnglishWordDictationScreen(app: app)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "text.book.closed.fill")
                                    .font(.system(size: 28, weight: .black))
                                    .frame(width: 58, height: 58)
                                    .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("英语单词听写")
                                        .font(.system(size: 19, weight: .black, design: .rounded))
                                    Text("录下单词读音，听音拼写并重练错词")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .opacity(0.78)
                                }
                                Spacer(minLength: 2)
                                Image(systemName: "arrow.right.circle.fill").font(.system(size: 26))
                            }
                            .foregroundStyle(KidsTheme.ink)
                            .padding(14)
                            .background(KidsTheme.mint.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            EnglishPhonicsScreen()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "character.book.closed.fill")
                                    .font(.system(size: 28, weight: .black))
                                    .frame(width: 58, height: 58)
                                    .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 18))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("自然拼读拆词")
                                        .font(.system(size: 19, weight: .black, design: .rounded))
                                    Text("输入单词，看看字母组合怎样拼出读音")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .opacity(0.78)
                                }
                                Spacer(minLength: 2)
                                Image(systemName: "arrow.right.circle.fill").font(.system(size: 26))
                            }
                            .foregroundStyle(KidsTheme.ink)
                            .padding(14)
                            .background(KidsTheme.lilac.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                    }

                    if snakeTicketPractice {
                        VStack(spacing: 8) {
                            Text("答错就从头再来，26 题全部答对即可获得一张游戏券。")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(KidsTheme.ink)
                            AlphabetListeningGame(
                                speech: speech,
                                ticketPractice: true,
                                fixedOptionDisplay: ticketOptionDisplay,
                                onTicketRoundStarted: { ticketPracticeUsesLowercase() },
                                onCorrect: { letter in app.recordAlphabetStudy(letter: letter) },
                                onQuestionAnswered: { correct in
                                    let status = app.recordAlphabetSnakePracticeAnswer(isCorrect: correct)
                                    return status.completedQuestions == SnakeRewardStatus.alphabetRoundQuestionGoal
                                },
                                onTicketEarned: { onSnakeTicketEarned?() }
                            )
                        }
                    } else {
                        Picker("学习方式", selection: $selectedTab) {
                            Text("认识字母").tag(0)
                            Text("听音闯关").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if selectedTab == 0 {
                            lesson
                        } else {
                            AlphabetListeningGame(
                                speech: speech,
                                ticketPractice: false,
                                fixedOptionDisplay: nil,
                                onTicketRoundStarted: { false },
                                onCorrect: { letter in app.recordAlphabetStudy(letter: letter) },
                                onQuestionAnswered: { _ in false },
                                onTicketEarned: {}
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle(snakeTicketPractice ? "答对 26 题赢游戏券" : "英文字母岛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(snakeTicketPractice ? "退出" : "完成") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .tint(KidsTheme.orange)
        .preferredColorScheme(.light)
        .onChange(of: selectedTab) { _, _ in speech.stop() }
        .onAppear {
            if snakeTicketPractice { app.startAlphabetSnakePracticeRound() }
        }
        .onDisappear { speech.stop() }
    }

    private var lesson: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("字母名称和常见发音是两件事", systemImage: "lightbulb.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KidsTheme.yellow.opacity(0.38), in: RoundedRectangle(cornerRadius: 16))

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(AlphabetCatalog.all.enumerated()), id: \.element.id) { index, letter in
                    AlphabetLetterCard(
                        letter: letter,
                        color: [KidsTheme.mint, KidsTheme.yellow, KidsTheme.lilac, KidsTheme.blue, KidsTheme.peach][index % 5],
                        isStudied: app.studiedAlphabetLetters.contains(letter.id),
                        speech: speech
                    ) {
                        app.recordAlphabetStudy(letter: letter.id)
                    }
                }
            }

            Text("元音先练常见短音，辅音听示范词开头的音。X 在 xylophone 中发 /z/，在 box 这类词尾常发 /ks/。字母在不同单词里还可能有其他读法。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Text("字母名称录音来自多位讲者；示范句由同一位讲者录制。逐条来源和授权见应用内录音署名文件。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ticketPracticeUsesLowercase() -> Bool {
        Int.random(in: 0..<10) < 9
    }
}

struct AlphabetLetterCard: View {
    let letter: AlphabetLetter
    let color: Color
    let isStudied: Bool
    let speech: AlphabetSpeech
    let onMarkStudied: () -> Void
    var onManualNamePlayback: () -> Void = {}
    var onManualExamplePlayback: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(letter.upper)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Text(letter.lower)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .opacity(0.75)
                Spacer(minLength: 0)
                if isStudied {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(KidsTheme.ink.opacity(0.7))
                        .accessibilityLabel("已听过")
                }
            }
            .foregroundStyle(KidsTheme.ink)
            .contentShape(Rectangle())
            .onTapGesture {
                speech.play("name_\(letter.lower)")
                onManualNamePlayback()
                onMarkStudied()
            }

            HStack(spacing: 5) {
                Text(letter.picture).font(.system(size: 25))
                Text(letter.example)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                speech.play("example_\(letter.lower)")
                onManualExamplePlayback()
                onMarkStudied()
            }

            HStack(spacing: 5) {
                Text("名称")
                Text(letter.nameSound).fontWeight(.black)
            }
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(KidsTheme.ink)
            .contentShape(Rectangle())
            .onTapGesture {
                speech.play("name_\(letter.lower)")
                onManualNamePlayback()
                onMarkStudied()
            }
            Button {
                speech.play("name_\(letter.lower)")
                onManualNamePlayback()
                onMarkStudied()
            } label: {
                Label("听字母名称", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .accessibilityHint("播放字母名称 \(letter.upper)")

            HStack(spacing: 5) {
                Text("常见音")
                Text(letter.commonSound).fontWeight(.black)
            }
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(KidsTheme.ink)
            .contentShape(Rectangle())
            .onTapGesture {
                speech.play("example_\(letter.lower)")
                onManualExamplePlayback()
                onMarkStudied()
            }
            Button {
                speech.play("example_\(letter.lower)")
                onManualExamplePlayback()
                onMarkStudied()
            } label: {
                Label("听示范句 · \(letter.upper) is for \(letter.example)", systemImage: "waveform")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .accessibilityHint("播放真人示范句：\(letter.examplePhrase)")
        }
        .padding(12)
        .foregroundStyle(KidsTheme.ink)
        .background(color.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}

private struct AlphabetListeningGame: View {
    let speech: AlphabetSpeech
    let ticketPractice: Bool
    let fixedOptionDisplay: AlphabetOptionDisplay?
    let onTicketRoundStarted: () -> Bool
    let onCorrect: (String) -> Void
    let onQuestionAnswered: (Bool) -> Bool
    let onTicketEarned: () -> Void
    @State private var soundMode = 0
    @State private var questions: [AlphabetLetter] = []
    @State private var questionIndex = 0
    @State private var choices: [AlphabetLetter] = []
    @State private var score = 0
    @State private var selectedAnswer: String?
    @State private var hasStarted = false
    @State private var isFinished = false
    @State private var optionDisplay: AlphabetOptionDisplay = .both

    private var current: AlphabetLetter? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    var body: some View {
        VStack(spacing: 16) {
            if !hasStarted {
                setup
            } else if isFinished {
                result
            } else if let current {
                game(current)
            }
        }
        .onDisappear { speech.stop() }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ticketPractice ? "游戏券挑战规则" : "你要听哪种声音？")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            if ticketPractice {
                Text(fixedOptionDisplay.map { "本轮选项显示为\($0.title)。26 题保持同一种方式。" }
                     ?? "每个回合和答错重开时都会重新抽取选项形式。同一回合的 26 题保持同一种方式。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(KidsTheme.muted)
            } else {
                Picker("声音类型", selection: $soundMode) {
                    Text("字母名称").tag(0)
                    Text("听单词音").tag(1)
                }
                .pickerStyle(.segmented)
                Text(soundMode == 0 ? "听字母名称，选出对应的大写和小写字母。" : "听真人示范句，留意例词开头的字母音，再选出对应字母。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(KidsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: startGame) {
                Label("开始 26 题", systemImage: "play.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(KidsTheme.yellow, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
    }

    private func game(_ letter: AlphabetLetter) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(ticketPractice ? "游戏券挑战 · 第 \(questionIndex + 1) / 26 题" : "第 \(questionIndex + 1) / \(questions.count) 题")
                Spacer()
                Label("\(score)", systemImage: "star.fill")
            }
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(KidsTheme.ink)
            Button {
                play(letter)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text("再听一次")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(KidsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 112)
                .background(KidsTheme.yellow.opacity(0.58), in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)

            if ticketPractice {
                Text("本轮：\(optionDisplay.title)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KidsTheme.ink.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(KidsTheme.mint.opacity(0.65), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(choices) { choice in
                    Button {
                        answer(choice, correct: letter)
                    } label: {
                        Group {
                            if optionDisplay == .lowercase {
                                Text(choice.lower)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                            } else if optionDisplay == .uppercase {
                                Text(choice.upper)
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                            } else {
                                HStack(spacing: 6) {
                                    Text(choice.upper).font(.system(size: 37, weight: .black, design: .rounded))
                                    Text(choice.lower).font(.system(size: 28, weight: .bold, design: .rounded))
                                }
                            }
                        }
                        .foregroundStyle(KidsTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .background(choiceColor(choice, correct: letter), in: RoundedRectangle(cornerRadius: 19))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAnswer != nil)
                    .accessibilityLabel(optionDisplay == .lowercase ? "小写 \(choice.lower)" :
                        optionDisplay == .uppercase ? "大写 \(choice.upper)" : "大写 \(choice.upper)，小写 \(choice.lower)")
                }
            }
            if let selectedAnswer {
                Text(selectedAnswer == letter.id ? "答对啦，真棒！" : (ticketPractice ? "答错了，这一轮要重新开始" : "正确答案是 \(letter.upper) \(letter.lower)"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .padding(.vertical, 5)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(16)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
        .task(id: questionIndex) { play(letter) }
    }

    private var result: some View {
        VStack(spacing: 14) {
            Text(score == questions.count ? "🌟" : "🎉")
                .font(.system(size: 72))
            Text(ticketPractice ? "26 个字母全部答对！" : "闯关完成！")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            Text("答对 \(score) / \(questions.count) 题")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
            Button(action: startGame) {
                Label("再玩一次", systemImage: "arrow.clockwise")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(KidsTheme.mint, in: RoundedRectangle(cornerRadius: 17))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
    }

    private func startGame() {
        speech.stop()
        questions = AlphabetCatalog.all.shuffled()
        questionIndex = 0
        score = 0
        selectedAnswer = nil
        choices = []
        hasStarted = true
        isFinished = false
        optionDisplay = roundOptionDisplay()
        prepareChoices()
    }

    private func prepareChoices() {
        guard let current else { return }
        choices = ([current] + Array(AlphabetCatalog.all.filter { $0.id != current.id }.shuffled().prefix(3))).shuffled()
    }

    private func play(_ letter: AlphabetLetter) {
        speech.play(soundMode == 0 ? "name_\(letter.lower)" : "example_\(letter.lower)")
    }

    private func answer(_ choice: AlphabetLetter, correct: AlphabetLetter) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = choice.id
        if choice.id == correct.id {
            score += 1
            onCorrect(correct.id)
        }
        let isCorrect = choice.id == correct.id
        if ticketPractice && !isCorrect {
            _ = onQuestionAnswered(false)
            speech.stop()
            let previousFirstID = questions.first?.id
            var newQuestions = AlphabetCatalog.all.shuffled()
            if newQuestions.count > 1, newQuestions.first?.id == previousFirstID {
                newQuestions.swapAt(0, 1)
            }
            questions = newQuestions
            questionIndex = 0
            score = 0
            selectedAnswer = nil
            optionDisplay = roundOptionDisplay()
            prepareChoices()
            if let firstQuestion = current { play(firstQuestion) }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            if ticketPractice {
                let earnedTicket = onQuestionAnswered(isCorrect)
                if earnedTicket {
                    isFinished = true
                    speech.stop()
                    onTicketEarned()
                    return
                }
            }
            if questionIndex + 1 == questions.count {
                isFinished = true
                speech.stop()
            } else {
                questionIndex += 1
                selectedAnswer = nil
                prepareChoices()
            }
        }
    }

    private func roundOptionDisplay() -> AlphabetOptionDisplay {
        guard ticketPractice else { return .both }
        if let fixedOptionDisplay { return fixedOptionDisplay }
        return onTicketRoundStarted() ? .lowercase : .both
    }

    private func choiceColor(_ choice: AlphabetLetter, correct: AlphabetLetter) -> Color {
        guard let selectedAnswer else { return KidsTheme.blue.opacity(0.42) }
        if choice.id == correct.id { return KidsTheme.mint }
        if choice.id == selectedAnswer { return KidsTheme.peach }
        return KidsTheme.blue.opacity(0.34)
    }
}
