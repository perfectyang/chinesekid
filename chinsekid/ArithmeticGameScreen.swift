import SwiftUI

private struct ArithmeticQuestion {
    let left: Int
    let operation: String
    let right: Int
    let answer: Int
    let options: [Int]

    static func make(upperBound: Int) -> ArithmeticQuestion {
        if Bool.random() {
            let left = Int.random(in: 1..<upperBound)
            let right = Int.random(in: 1...(upperBound - left))
            return make(left: left, operation: "+", right: right, answer: left + right, upperBound: upperBound)
        }

        let left = Int.random(in: 2...upperBound)
        let right = Int.random(in: 1..<left)
        return make(left: left, operation: "−", right: right, answer: left - right, upperBound: upperBound)
    }

    private static func make(left: Int, operation: String, right: Int, answer: Int, upperBound: Int) -> ArithmeticQuestion {
        let choices = Array(1...upperBound).filter { $0 != answer }.shuffled().prefix(3)
        return ArithmeticQuestion(
            left: left,
            operation: operation,
            right: right,
            answer: answer,
            options: (Array(choices) + [answer]).shuffled()
        )
    }
}

private enum ArithmeticPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let orange = KidsTheme.orange
    static let yellow = KidsTheme.yellow
    static let mint = KidsTheme.mint
    static let blue = KidsTheme.blue
    static let peach = KidsTheme.peach
    static let red = KidsTheme.red
}

struct ArithmeticGameScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var upperBoundInput = "5"
    @State private var upperBound = 5
    @State private var durationInput = "30"
    @State private var gameDuration = 30
    @State private var question: ArithmeticQuestion?
    @State private var selectedAnswer: Int?
    @State private var remainingSeconds = 30
    @State private var correctCount = 0
    @State private var answeredCount = 0
    @State private var hasStarted = false
    @State private var isPlaying = false
    @State private var feedback: Bool?

    var body: some View {
        ZStack {
            StorybookBackground()
            VStack(spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(ArithmeticPalette.ink)
                            .frame(width: 46, height: 46)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("闪电口算王")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.ink)
                    Spacer()
                    Color.clear.frame(width: 46, height: 46)
                }

                if !hasStarted {
                    setupContent
                } else if isPlaying {
                    gameContent
                } else {
                    resultContent
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled && remainingSeconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                remainingSeconds -= 1
            }
            if !Task.isCancelled, remainingSeconds == 0 {
                isPlaying = false
            }
        }
    }

    private var setupContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("⚡️")
                    .font(.system(size: 68))
                Text("准备好迎接挑战了吗？")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(ArithmeticPalette.ink)
                Text("算出结果，点选答案，看看时间到前能答对几题！")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(ArithmeticPalette.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 15)

            VStack(alignment: .leading, spacing: 13) {
                Text("设置口算范围")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(ArithmeticPalette.ink)
                HStack(spacing: 12) {
                    Text("算到")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.ink)
                    TextField("5", text: $upperBoundInput)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(width: 100, height: 58)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: upperBoundInput) { _, value in
                            upperBoundInput = String(value.filter(\.isNumber).prefix(3))
                        }
                    Text("以内")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.ink)
                    Spacer()
                    Label("加法 + 减法", systemImage: "shuffle")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(ArithmeticPalette.mint.opacity(0.65), in: Capsule())
                }
                Text("请输入 2–999；题目中的数字和答案都不含 0。")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ArithmeticPalette.muted)
                HStack(spacing: 12) {
                    Text("挑战时间")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.ink)
                    TextField("30", text: $durationInput)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(width: 100, height: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .onChange(of: durationInput) { _, value in
                            durationInput = String(value.filter(\.isNumber).prefix(4))
                        }
                    Text("秒")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.ink)
                    Spacer()
                    Text("默认 30 秒")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.muted)
                }
            }
            .padding(20)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24))

            Button(action: startGame) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("开始 \(durationInput.isEmpty ? "30" : durationInput) 秒挑战")
                }
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(ArithmeticPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 66)
                .background(ArithmeticPalette.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
    }

    private var gameContent: some View {
        VStack(spacing: 20) {
            HStack {
                Label("\(remainingSeconds) 秒", systemImage: "timer")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(remainingSeconds <= 10 ? ArithmeticPalette.red : ArithmeticPalette.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                Spacer()
                Label("\(correctCount) 分", systemImage: "star.fill")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(ArithmeticPalette.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(ArithmeticPalette.yellow, in: Capsule())
            }

            VStack(spacing: 18) {
                Text("\(question?.left ?? 0)  \(question?.operation ?? "+")  \(question?.right ?? 0)  =  ?")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .foregroundStyle(ArithmeticPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 140)
                answerChoices
                if let feedback {
                    Text(feedback ? "答对啦！继续加油 ⭐️" : "再接再厉，下一题！")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(feedback ? ArithmeticPalette.ink : ArithmeticPalette.red)
                        .frame(height: 26)
                } else {
                    Text("已完成 \(answeredCount) 题")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ArithmeticPalette.muted)
                        .frame(height: 26)
                }
            }
            .padding(18)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))

        }
        .padding(.top, 8)
    }

    private var answerChoices: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(question?.options ?? [], id: \.self) { option in
                Button { choose(option) } label: {
                    Text(String(option))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(optionForeground(option))
                        .frame(maxWidth: .infinity, minHeight: 82)
                        .background(optionColor(option), in: RoundedRectangle(cornerRadius: 21))
                        .overlay {
                            RoundedRectangle(cornerRadius: 21)
                                .stroke(.white.opacity(0.85), lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .disabled(feedback != nil)
            }
        }
    }

    private var resultContent: some View {
        VStack(spacing: 20) {
            Text(correctCount >= 15 ? "🏆" : correctCount >= 8 ? "🌟" : "🎉")
                .font(.system(size: 90))
            Text("挑战结束！")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(ArithmeticPalette.ink)
            Text("你在 \(gameDuration) 秒内答对了")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(ArithmeticPalette.muted)
            Text("\(correctCount) 题")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(ArithmeticPalette.orange)
            Text("完成 \(answeredCount) 题 · 口算范围：\(upperBound) 以内")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ArithmeticPalette.muted)
            Button(action: startGame) {
                Label("再挑战一次", systemImage: "arrow.clockwise")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(ArithmeticPalette.ink)
                    .frame(maxWidth: 320, minHeight: 60)
                    .background(ArithmeticPalette.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
            Button("回到首页") { dismiss() }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ArithmeticPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private func optionColor(_ option: Int) -> Color {
        guard let selectedAnswer, let feedback else { return .white }
        guard selectedAnswer == option else { return .white.opacity(0.72) }
        return feedback ? ArithmeticPalette.mint : ArithmeticPalette.red.opacity(0.78)
    }

    private func optionForeground(_ option: Int) -> Color {
        guard let selectedAnswer, selectedAnswer == option, let feedback, !feedback else {
            return ArithmeticPalette.ink
        }
        return .white
    }

    private func startGame() {
        let parsedLimit = Int(upperBoundInput) ?? 5
        upperBound = min(max(parsedLimit, 2), 999)
        upperBoundInput = String(upperBound)
        let parsedDuration = Int(durationInput) ?? 30
        gameDuration = min(max(parsedDuration, 1), 9_999)
        durationInput = String(gameDuration)
        remainingSeconds = gameDuration
        correctCount = 0
        answeredCount = 0
        selectedAnswer = nil
        feedback = nil
        question = .make(upperBound: upperBound)
        hasStarted = true
        isPlaying = true
    }

    private func choose(_ answer: Int) {
        guard isPlaying, feedback == nil, let currentQuestion = question else { return }
        selectedAnswer = answer
        let isCorrect = answer == currentQuestion.answer
        answeredCount += 1
        if isCorrect { correctCount += 1 }
        feedback = isCorrect

        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }
            guard isPlaying else { return }
            question = .make(upperBound: upperBound)
            selectedAnswer = nil
            feedback = nil
        }
    }
}
