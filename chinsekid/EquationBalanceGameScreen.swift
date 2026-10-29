import SwiftUI

private enum BalanceOperation: String, CaseIterable, Identifiable {
    case addition
    case subtraction
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addition: "加法"
        case .subtraction: "减法"
        case .mixed: "加减混合"
        }
    }

    var symbol: String {
        switch self {
        case .addition: "+"
        case .subtraction: "−"
        case .mixed: "+ −"
        }
    }
}

private struct BalanceSide {
    let first: Int
    let operation: String
    let second: Int
    let hiddenFirst: Bool
    let hasBlank: Bool

    func value(replacing hiddenValue: Int? = nil) -> Int {
        let left = hasBlank && hiddenFirst ? (hiddenValue ?? first) : first
        let right = hasBlank && !hiddenFirst ? (hiddenValue ?? second) : second
        return operation == "+" ? left + right : left - right
    }

    func label(replacing hiddenValue: Int? = nil) -> String {
        let left = hasBlank && hiddenFirst ? (hiddenValue.map(String.init) ?? "□") : String(first)
        let right = hasBlank && !hiddenFirst ? (hiddenValue.map(String.init) ?? "□") : String(second)
        return "\(left) \(operation) \(right)"
    }
}

private struct BalanceQuestion: Identifiable {
    let id = UUID()
    let left: BalanceSide
    let right: BalanceSide
    let answer: Int
    let target: Int
    let options: [Int]

    var leftAnswer: Int { left.value(replacing: answer) }
    var rightAnswer: Int { right.value(replacing: answer) }

    static func make(target: Int, operation: BalanceOperation) -> BalanceQuestion {
        let operations: [String]
        switch operation {
        case .addition: operations = ["+", "+"]
        case .subtraction: operations = ["−", "−"]
        case .mixed: operations = Bool.random() ? ["+", "−"] : ["−", "+"]
        }

        let blankLeft = Bool.random()
        let left = makeSide(target: target, operation: operations[0], hasBlank: blankLeft)
        let right = makeSide(target: target, operation: operations[1], hasBlank: !blankLeft)
        let answer = blankLeft ? left.answer : right.answer
        let operandLimit = min(max(max(target + 5, answer + 3), 6), 50)
        var distractors = Set<Int>()
        while distractors.count < 3 {
            let candidate = Int.random(in: 0...operandLimit)
            if candidate != answer { distractors.insert(candidate) }
        }
        return BalanceQuestion(
            left: left.side,
            right: right.side,
            answer: answer,
            target: target,
            options: (Array(distractors) + [answer]).shuffled()
        )
    }

    private static func makeSide(target: Int, operation: String, hasBlank: Bool) -> (side: BalanceSide, answer: Int) {
        if operation == "+" {
            let first = Int.random(in: 0...target)
            let second = target - first
            let hiddenFirst = hasBlank && Bool.random()
            let answer = hiddenFirst ? first : second
            return (
                BalanceSide(
                    first: hasBlank && hiddenFirst ? 0 : first,
                    operation: "+",
                    second: hasBlank && !hiddenFirst ? 0 : second,
                    hiddenFirst: hiddenFirst,
                    hasBlank: hasBlank
                ),
                answer
            )
        }

        let removed = Int.random(in: 0...min(target + 5, 25))
        let first = target + removed
        let hiddenFirst = hasBlank && Bool.random()
        let answer = hiddenFirst ? first : removed
        return (
            BalanceSide(
                first: hasBlank && hiddenFirst ? 0 : first,
                operation: "−",
                second: hasBlank && !hiddenFirst ? 0 : removed,
                hiddenFirst: hiddenFirst,
                hasBlank: hasBlank
            ),
            answer
        )
    }
}

private enum BalancePhase {
    case setup
    case demonstration(Int)
    case playing
    case result
}

private enum BalancePalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let orange = KidsTheme.orange
    static let yellow = KidsTheme.yellow
    static let mint = KidsTheme.mint
    static let blue = KidsTheme.blue
    static let red = KidsTheme.red
    static let lilac = KidsTheme.lilac
}

struct EquationBalanceGameScreen: View {
    let app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var target = 4
    @State private var operation: BalanceOperation = .mixed
    @State private var phase: BalancePhase = .setup
    @State private var questions: [BalanceQuestion] = []
    @State private var mistakes: [BalanceQuestion] = []
    @State private var reviewMistakes: [BalanceQuestion] = []
    @State private var isReviewRound = false
    @State private var index = 0
    @State private var selectedAnswer: Int?
    @State private var isCorrect: Bool?
    @State private var correctCount = 0
    @State private var answeredCount = 0

    private var currentQuestion: BalanceQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var body: some View {
        ZStack {
            StorybookBackground()
            VStack(spacing: 14) {
                header
                Group {
                    switch phase {
                    case .setup: setupContent
                    case .demonstration(let step): demonstrationContent(step: step)
                    case .playing: gameContent
                    case .result: resultContent
                    }
                }
                .frame(maxWidth: 720, maxHeight: .infinity)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(BalancePalette.ink)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("小小平衡师")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(BalancePalette.ink)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var setupContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("⚖️").font(.system(size: 62))
                Text("让等号两边一样多")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(BalancePalette.ink)
                Text("先算两边，再给天平配平。")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(BalancePalette.muted)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("两边都要等于")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(BalancePalette.muted)
                        Text("目标结果")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(BalancePalette.ink)
                    }
                    Spacer()
                    Stepper(value: $target, in: 0...20) {
                        Text("\(target)")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(BalancePalette.ink)
                            .frame(minWidth: 54)
                    }
                    .fixedSize()
                }

                Text("选择要练习的运算")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(BalancePalette.ink)
                HStack(spacing: 9) {
                    ForEach(BalanceOperation.allCases) { item in
                        Button { operation = item } label: {
                            VStack(spacing: 4) {
                                Text(item.symbol)
                                    .font(.system(size: 21, weight: .black, design: .rounded))
                                Text(item.title)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(BalancePalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(operation == item ? BalancePalette.yellow : Color.white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(operation == item ? BalancePalette.orange : BalancePalette.ink.opacity(0.08), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(BalancePalette.orange)
                    Text("等号像天平：左边和右边的结果一样，天平就平了。")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BalancePalette.muted)
                }
            }
            .padding(18)
            .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 24))

            Button { phase = .demonstration(0) } label: {
                Label("先看天平怎么平衡", systemImage: "play.fill")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(BalancePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(BalancePalette.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }

    private func demonstrationContent(step: Int) -> some View {
        let isAddition = step == 0
        let leftText = isAddition ? "2 + 2" : "5 − 1"
        let rightText = isAddition ? "1 + 3" : "2 + 2"
        let explanation = isAddition
            ? "左边合起来是 4 块，右边合起来也是 4 块。两边一样多，等号就成立。"
            : "左边拿走 1 块后剩 4 块，右边合起来也是 4 块。加法和减法都能让两边结果相等。"

        return VStack(spacing: 18) {
            Text("先看一看")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(BalancePalette.muted)
            HStack(spacing: 12) {
                expressionCard(title: "左边", expression: leftText, color: BalancePalette.blue)
                Text("=")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(BalancePalette.orange)
                expressionCard(title: "右边", expression: rightText, color: BalancePalette.lilac)
            }
            BalanceScaleView(left: 4, right: 4, revealed: true)
                .frame(height: 115)
            HStack(spacing: 8) {
                tokenGroup(count: 4, color: BalancePalette.blue)
                Image(systemName: "equal").font(.system(size: 18, weight: .black)).foregroundStyle(BalancePalette.orange)
                tokenGroup(count: 4, color: BalancePalette.lilac)
            }
            Text(explanation)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(BalancePalette.ink)
                .padding(17)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 20))
            Button {
                if step == 0 {
                    phase = .demonstration(1)
                } else {
                    beginGame()
                }
            } label: {
                Label(step == 0 ? "再看一个减法例子" : "我懂了，开始配平", systemImage: "arrow.right")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(BalancePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(BalancePalette.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var gameContent: some View {
        VStack(spacing: 14) {
            HStack {
                Label("第 \(index + 1) / \(questions.count) 题", systemImage: "star.fill")
                Spacer()
                Text(isReviewRound ? "错题复习" : "答对 \(correctCount) 题")
            }
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(BalancePalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.white.opacity(0.9), in: Capsule())

            if let question = currentQuestion {
                Text("两边都要等于 \(question.target)，选出空格里的数字。")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(BalancePalette.muted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    expressionCard(title: "左边", expression: question.left.label(replacing: selectedAnswer), color: BalancePalette.blue)
                    Text("=")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(BalancePalette.orange)
                    expressionCard(title: "右边", expression: question.right.label(replacing: selectedAnswer), color: BalancePalette.lilac)
                }
                .frame(maxWidth: .infinity)

                BalanceScaleView(
                    left: isCorrect == true ? question.target : (isCorrect == false ? question.left.value(replacing: selectedAnswer) : nil),
                    right: isCorrect == true ? question.target : (isCorrect == false ? question.right.value(replacing: selectedAnswer) : nil),
                    revealed: isCorrect != nil
                )
                .frame(height: 100)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(question.options, id: \.self) { option in
                        Button { choose(option) } label: {
                            Text(String(option))
                                .font(.system(size: 31, weight: .black, design: .rounded))
                                .foregroundStyle(optionForeground(option, answer: question.answer))
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(optionColor(option, answer: question.answer), in: RoundedRectangle(cornerRadius: 17))
                                .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.9), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .disabled(isCorrect != nil)
                    }
                }

                if let isCorrect {
                    VStack(spacing: 8) {
                        Text(isCorrect ? "配平成功！兩边都是 \(question.target) 🎉" : balanceFeedback(question: question))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(isCorrect ? BalancePalette.ink : BalancePalette.red)
                            .multilineTextAlignment(.center)
                        Text("\(question.left.label(replacing: question.answer)) = \(question.right.label(replacing: question.answer))")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(BalancePalette.muted)
                        Button(action: nextQuestion) {
                            Label(index + 1 == questions.count ? "看看闯关结果" : "继续下一题", systemImage: "arrow.right")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(BalancePalette.ink)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(BalancePalette.yellow, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("先算出两边，再选一个数字放进空格。")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BalancePalette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var resultContent: some View {
        VStack(spacing: 17) {
            Text(mistakes.isEmpty ? "🏆" : "🌟")
                .font(.system(size: 76))
            Text(isReviewRound ? (mistakes.isEmpty ? "错题全通关！" : "再试一次错题吧") : "闯关完成！")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(BalancePalette.ink)
            Text(isReviewRound ? "这次又配平了 \(correctCount) 题" : "你答对了 \(correctCount) / \(answeredCount) 题")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(BalancePalette.muted)
            Text("目标结果：\(target) · \(operation.title)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(BalancePalette.muted)

            if !mistakes.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("再看看这些等式")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(BalancePalette.ink)
                    ForEach(Array(mistakes.prefix(3).enumerated()), id: \.offset) { _, question in
                        Text("\(question.left.label(replacing: question.answer)) = \(question.right.label(replacing: question.answer))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(BalancePalette.ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 18))
            }

            if !mistakes.isEmpty {
                Button(action: startReview) {
                    Label("重新玩错题", systemImage: "arrow.clockwise")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(BalancePalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(BalancePalette.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Button(action: beginGame) {
                Label("再玩一局", systemImage: "play.fill")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(BalancePalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            Button("回到首页") { dismiss() }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(BalancePalette.muted)
        }
        .padding(.vertical, 8)
    }

    private func expressionCard(title: String, expression: String, color: Color) -> some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(BalancePalette.muted)
            Text(expression)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(BalancePalette.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(color.opacity(0.42), in: RoundedRectangle(cornerRadius: 15))
        }
        .frame(maxWidth: .infinity)
    }

    private func tokenGroup(count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                Circle().fill(color).frame(width: 14, height: 14)
            }
        }
        .accessibilityLabel("\(count) 块积木")
    }

    private func optionColor(_ option: Int, answer: Int) -> Color {
        guard let selectedAnswer else { return .white }
        if option == answer { return BalancePalette.mint }
        if option == selectedAnswer { return BalancePalette.red.opacity(0.82) }
        return .white.opacity(0.7)
    }

    private func optionForeground(_ option: Int, answer: Int) -> Color {
        guard let selectedAnswer, option == selectedAnswer, option != answer else { return BalancePalette.ink }
        return .white
    }

    private func balanceFeedback(question: BalanceQuestion) -> String {
        let left = question.left.value(replacing: selectedAnswer)
        let right = question.right.value(replacing: selectedAnswer)
        if left == right { return "这次选错了，答案是 \(question.answer)，两边都等于 \(question.target)。" }
        return left > right ? "左边多了 \(left - right)，再看看正确答案。" : "右边多了 \(right - left)，再看看正确答案。"
    }

    private func choose(_ answer: Int) {
        guard isCorrect == nil, let question = currentQuestion else { return }
        selectedAnswer = answer
        let correct = answer == question.answer
        isCorrect = correct
        answeredCount += 1
        if correct {
            correctCount += 1
        } else if isReviewRound {
            reviewMistakes.append(question)
        } else {
            mistakes.append(question)
        }
    }

    private func nextQuestion() {
        guard index + 1 < questions.count else {
            phase = .result
            return
        }
        index += 1
        selectedAnswer = nil
        isCorrect = nil
    }

    private func beginGame() {
        questions = (0..<5).map { _ in BalanceQuestion.make(target: target, operation: operation) }
        mistakes = []
        isReviewRound = false
        correctCount = 0
        answeredCount = 0
        startPlaying()
    }

    private func startReview() {
        questions = mistakes
        reviewMistakes = []
        isReviewRound = true
        correctCount = 0
        answeredCount = 0
        startPlaying()
    }

    private func startPlaying() {
        index = 0
        selectedAnswer = nil
        isCorrect = nil
        phase = .playing
    }
}

private struct BalanceScaleView: View {
    let left: Int?
    let right: Int?
    let revealed: Bool

    private var tilt: Double {
        guard revealed, let left, let right, left != right else { return 0 }
        return left > right ? 8 : -8
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.72, 390)
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BalancePalette.orange)
                        .frame(width: width, height: 12)
                    HStack {
                        pan(label: left.map(String.init) ?? "？", color: BalancePalette.blue)
                        Spacer()
                        pan(label: right.map(String.init) ?? "？", color: BalancePalette.lilac)
                    }
                    .frame(width: width - 18)
                    .padding(.top, 19)
                }
                .frame(height: 73)
                .rotationEffect(.degrees(tilt))
                Image(systemName: "triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(BalancePalette.yellow)
                    .offset(y: -2)
                Capsule()
                    .fill(BalancePalette.ink.opacity(0.22))
                    .frame(width: 95, height: 8)
                    .offset(y: -5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(revealed ? "天平左边 \(left ?? 0)，右边 \(right ?? 0)" : "待配平的天平")
    }

    private func pan(label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Capsule().fill(color.opacity(0.85)).frame(width: 42, height: 3)
            Text(label)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(BalancePalette.ink)
                .frame(width: 48, height: 34)
                .background(color.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
