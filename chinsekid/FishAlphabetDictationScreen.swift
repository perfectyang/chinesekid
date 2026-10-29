import SwiftUI

struct FishAlphabetDictationScreen: View {
    @ObservedObject var app: AppModel
    let letterForm: AlphabetOptionDisplay
    let onTicketEarned: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var speech = AlphabetSpeech()
    @State private var questions: [AlphabetLetter] = []
    @State private var questionIndex = 0
    @State private var answer = ""
    @State private var slowPlayback = false
    @State private var restartMessage = false
    @State private var inputMessage: String?
    @State private var awarded = false
    @State private var roundID = UUID().uuidString
    @FocusState private var answerFocused: Bool

    private var target: AlphabetLetter? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if awarded { successView }
                    else if let target { questionView(target) }
                    else { ProgressView() }
                }
                .padding(22)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle("英文字母听写 · 赢游戏券")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if questions.isEmpty { startRound(previousFirstID: nil) }
        }
        .onDisappear { speech.stop() }
    }

    private func questionView(_ target: AlphabetLetter) -> some View {
        VStack(spacing: 18) {
            Text("第 \(questionIndex + 1) / 26 题")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            ProgressView(value: Double(questionIndex), total: 26)
                .tint(KidsTheme.orange)
            Text("26 个字母各考一次，全部答对获得 1 张游戏券")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(KidsTheme.muted)
            Text("本轮：\(letterForm.dictationTitle)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(KidsTheme.ink)
            if restartMessage {
                Text("答错了，已重新打乱题目，从第 1 题开始。")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KidsTheme.red)
            }

            VStack(spacing: 15) {
                Text("听清楚后写出英文字母")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink)
                Button { play(target) } label: {
                    Label("再听一次", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(KidsTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(KidsTheme.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                Button(slowPlayback ? "慢速已开启 · 恢复正常" : "切换慢速播放") {
                    slowPlayback.toggle()
                    play(target)
                }
                .font(.system(size: 14, weight: .bold))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))

            TextField(letterForm == .uppercase ? "写下听到的字母，例如 A" : "写下听到的字母，例如 a", text: $answer)
                .font(.system(size: 27, weight: .bold))
                .textInputAutocapitalization(letterForm == .uppercase ? .characters : .never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($answerFocused)
                .onSubmit(checkAnswer)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(answerFocused ? KidsTheme.orange : .clear, lineWidth: 3)
                }
                .animation(.easeOut(duration: 0.15), value: answerFocused)
            if let inputMessage {
                Text(inputMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KidsTheme.red)
            }
            Button("检查答案") { checkAnswer() }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(KidsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(KidsTheme.mint, in: Capsule())
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 70))
                .foregroundStyle(KidsTheme.orange)
            Text("26 个字母全部答对，获得 1 张游戏券！")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("现在共有 \(app.snakeRewardStatus.ticketCount) 张游戏券")
                .font(.system(size: 17, weight: .bold))
            Button("返回海底大冒险") { onTicketEarned() }
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(KidsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(KidsTheme.yellow, in: Capsule())
            Button("再赢一张") {
                awarded = false
                startRound(previousFirstID: questions.first?.id)
            }
            .font(.system(size: 16, weight: .bold))
        }
        .foregroundStyle(KidsTheme.ink)
        .padding(.top, 90)
    }

    private func checkAnswer() {
        guard let target, !awarded else { return }
        let entered = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entered.count == 1,
              entered.uppercased().first.map({ $0 >= "A" && $0 <= "Z" }) == true else {
            inputMessage = "请输入一个英文字母。"
            return
        }
        let matchesCase: Bool
        switch letterForm {
        case .both: matchesCase = true
        case .lowercase: matchesCase = entered == entered.lowercased()
        case .uppercase: matchesCase = entered == entered.uppercased()
        }
        answerFocused = false
        inputMessage = nil
        if !matchesCase || entered.uppercased() != target.upper {
            startRound(previousFirstID: questions.first?.id)
            restartMessage = true
            return
        }
        restartMessage = false
        app.recordAlphabetStudy(letter: target.upper)
        if questionIndex + 1 == questions.count {
            speech.stop()
            awarded = app.awardFishPracticeTicket(roundID: roundID)
            return
        }
        questionIndex += 1
        answer = ""
        if let next = self.target { play(next) }
    }

    private func startRound(previousFirstID: String?) {
        var newOrder = AlphabetCatalog.all.shuffled()
        if newOrder.first?.id == previousFirstID {
            newOrder.swapAt(0, 1)
        }
        questions = newOrder
        questionIndex = 0
        roundID = UUID().uuidString
        answer = ""
        inputMessage = nil
        restartMessage = false
        if let first = newOrder.first { play(first) }
    }

    private func play(_ letter: AlphabetLetter) {
        _ = speech.play("name_\(letter.lower)", rate: slowPlayback ? 0.75 : 1)
    }
}
