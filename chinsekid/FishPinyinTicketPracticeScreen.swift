import SwiftUI

struct FishPinyinTicketPracticeScreen: View {
    @ObservedObject var app: AppModel
    let type: FishTicketQuestionType
    let items: [PinyinUnit]
    let onTicketEarned: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var audio = PinyinAudioPlayer()
    @State private var questions: [PinyinUnit] = []
    @State private var questionIndex = 0
    @State private var choices: [PinyinUnit] = []
    @State private var selectedChoiceID: String?
    @State private var answer = ""
    @State private var slowPlayback = false
    @State private var restartMessage = false
    @State private var awarded = false
    @State private var roundID = UUID().uuidString
    @FocusState private var answerFocused: Bool

    private var target: PinyinUnit? {
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
            .navigationTitle("\(type.title) · 赢游戏券")
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
    }

    private func questionView(_ target: PinyinUnit) -> some View {
        VStack(spacing: 18) {
            Text("第 \(questionIndex + 1) / \(questions.count) 题")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            ProgressView(value: Double(questionIndex), total: Double(max(questions.count, 1)))
                .tint(KidsTheme.orange)
            Text("每个拼音考一次，全部答对获得 1 张游戏券")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(KidsTheme.muted)
            if restartMessage {
                Text("答错了，已重新打乱题目，从第 1 题开始。")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KidsTheme.red)
            }

            VStack(spacing: 15) {
                Text(type == .dictation ? "听清楚后写出拼音" : "听一听，选出正确拼音")
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
                if type == .dictation {
                    Button(slowPlayback ? "慢速已开启 · 恢复正常" : "切换慢速播放") {
                        slowPlayback.toggle()
                        play(target)
                    }
                    .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))

            if type == .dictation {
                TextField("写下听到的拼音", text: $answer)
                    .font(.system(size: 27, weight: .bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($answerFocused)
                    .onSubmit(submitDictation)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(answerFocused ? KidsTheme.orange : .clear, lineWidth: 3)
                    }
                    .animation(.easeOut(duration: 0.15), value: answerFocused)
                Button("检查答案") { submitDictation() }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(KidsTheme.mint, in: Capsule())
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(choices) { choice in
                        Button { select(choice, for: target) } label: {
                            HStack(spacing: 8) {
                                Text(choice.symbol)
                                if selectedChoiceID == choice.id {
                                    Image(systemName: choice.id == target.id ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(KidsTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .background(choiceFill(for: choice, target: target), in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(choiceBorder(for: choice, target: target), lineWidth: 3)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedChoiceID != nil)
                    }
                }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 70))
                .foregroundStyle(KidsTheme.orange)
            Text("全部答对，获得 1 张游戏券！")
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

    private func submitDictation() {
        guard let target else { return }
        let normalized = answer.lowercased()
            .filter { $0.isLetter }
            .replacingOccurrences(of: "ü", with: "v")
        guard !normalized.isEmpty else { return }
        let expected = target.symbol.replacingOccurrences(of: "ü", with: "v")
        answerFocused = false
        submit(normalized == expected)
    }

    private func submit(_ isCorrect: Bool) {
        guard !awarded else { return }
        if !isCorrect {
            startRound(previousFirstID: questions.first?.id)
            restartMessage = true
            return
        }
        restartMessage = false
        if questionIndex + 1 == questions.count {
            awarded = app.awardFishPracticeTicket(roundID: roundID)
            return
        }
        questionIndex += 1
        answer = ""
        prepareQuestion()
    }

    private func select(_ choice: PinyinUnit, for target: PinyinUnit) {
        guard selectedChoiceID == nil else { return }
        selectedChoiceID = choice.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard self.target?.id == target.id else { return }
            selectedChoiceID = nil
            submit(choice.id == target.id)
        }
    }

    private func choiceFill(for choice: PinyinUnit, target: PinyinUnit) -> Color {
        guard selectedChoiceID == choice.id else { return .white }
        return choice.id == target.id ? KidsTheme.mint.opacity(0.65) : KidsTheme.red.opacity(0.16)
    }

    private func choiceBorder(for choice: PinyinUnit, target: PinyinUnit) -> Color {
        guard selectedChoiceID == choice.id else { return .clear }
        return choice.id == target.id ? KidsTheme.mint : KidsTheme.red
    }

    private func startRound(previousFirstID: String?) {
        guard !items.isEmpty else { return }
        var newOrder = items.shuffled()
        if newOrder.count > 1, newOrder.first?.id == previousFirstID {
            newOrder.swapAt(0, 1)
        }
        questions = newOrder
        questionIndex = 0
        selectedChoiceID = nil
        roundID = UUID().uuidString
        answer = ""
        restartMessage = false
        prepareQuestion()
    }

    private func prepareQuestion() {
        guard let target else { return }
        let distractors = PinyinCatalog.categories.flatMap(\.items)
            .filter { $0.id != target.id && $0.symbol != target.symbol }
            .shuffled()
            .prefix(3)
        choices = ([target] + Array(distractors)).shuffled()
        selectedChoiceID = nil
        play(target)
    }

    private func play(_ target: PinyinUnit) {
        _ = audio.play(target, rate: slowPlayback ? 0.75 : 1)
    }
}
