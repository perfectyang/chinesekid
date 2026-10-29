import SwiftUI

private enum ManualEntryPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let paper = KidsTheme.paper
    static let mint = KidsTheme.mint
    static let yellow = KidsTheme.yellow
    static let red = KidsTheme.red
}

struct ManualCharacterEntryScreen: View {
    let app: AppModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var inputText = ""
    @State private var excludedGlyphs = Set<String>()
    @State private var feedback: EntryFeedback?

    private let columns = [GridItem(.adaptive(minimum: 58), spacing: 10)]

    private var detectedGlyphs: [String] {
        var seen = Set<String>()
        return inputText
            .filter(isHanCharacter)
            .map(String.init)
            .filter { seen.insert($0).inserted }
    }

    private var newGlyphs: [String] {
        detectedGlyphs.filter { !app.contains($0) }
    }

    private var selectedGlyphs: [String] {
        newGlyphs.filter { !excludedGlyphs.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("✏️  一次收集好多字")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(ManualEntryPalette.ink)
                        Text("输入或粘贴一串文字，我们会帮你找出里面的汉字。")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(ManualEntryPalette.muted)
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.white)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(ManualEntryPalette.mint, lineWidth: 2))
                        if inputText.isEmpty {
                            Text("例如：春天来了，花儿开了")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(ManualEntryPalette.muted.opacity(0.7))
                                .padding(.horizontal, 16).padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $inputText)
                            .font(.system(size: 23, weight: .medium, design: .serif))
                            .foregroundStyle(ManualEntryPalette.ink)
                            .tint(ManualEntryPalette.ink)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($inputFocused)
                            .padding(10)
                            .frame(minHeight: 112, maxHeight: 150)
                    }

                    HStack {
                        Label("找到 \(detectedGlyphs.count) 个不同的汉字", systemImage: "sparkles")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(ManualEntryPalette.ink)
                        Spacer()
                        if !inputText.isEmpty {
                            Button("清空") {
                                inputFocused = false
                                inputText = ""
                                excludedGlyphs.removeAll()
                                feedback = nil
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ManualEntryPalette.muted)
                        }
                    }

                    if detectedGlyphs.isEmpty {
                        HStack(spacing: 12) {
                            Text("🪄").font(.system(size: 29))
                            Text("写几个汉字试试看吧")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(ManualEntryPalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("选择要加入图鉴的字")
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                                        .foregroundStyle(ManualEntryPalette.ink)
                                    Text("已收录的字会自动跳过")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(ManualEntryPalette.muted)
                                }
                                Spacer()
                                Button(excludedGlyphs.isEmpty ? "取消全选" : "选中全部新字") {
                                    inputFocused = false
                                    if excludedGlyphs.isEmpty {
                                        excludedGlyphs = Set(newGlyphs)
                                    } else {
                                        excludedGlyphs.removeAll()
                                    }
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .disabled(newGlyphs.isEmpty)
                            }

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(Array(detectedGlyphs.enumerated()), id: \.element) { index, glyph in
                                    characterChip(glyph, index: index)
                                }
                            }
                        }
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 23))
                    }

                    if let feedback {
                        HStack(spacing: 9) {
                            Image(systemName: feedback.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            Text(feedback.message)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(feedback.isSuccess ? ManualEntryPalette.ink : ManualEntryPalette.red)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(feedback.isSuccess ? ManualEntryPalette.mint : ManualEntryPalette.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(20)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                StorybookBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { inputFocused = false }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: saveCharacters) {
                    HStack {
                        Text("加入我的图鉴")
                        Spacer()
                        Text("\(selectedGlyphs.count) 个字")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(ManualEntryPalette.ink)
                    .padding(.horizontal, 21)
                    .frame(maxWidth: 700).frame(height: 58)
                    .background(ManualEntryPalette.yellow, in: Capsule())
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.regularMaterial)
                }
                .buttonStyle(.plain)
                .disabled(selectedGlyphs.isEmpty)
                .opacity(selectedGlyphs.isEmpty ? 0.55 : 1)
            }
            .navigationTitle("手动录入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        inputFocused = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        inputFocused = false
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .keyboardDismissToolbar { inputFocused = false }
            .onChange(of: inputText) { _, _ in
                excludedGlyphs = excludedGlyphs.intersection(newGlyphs)
                withAnimation(.easeInOut(duration: 0.18)) { feedback = nil }
            }
        }
    }

    private func characterChip(_ glyph: String, index: Int) -> some View {
        let alreadyAdded = app.contains(glyph)
        let selected = !alreadyAdded && !excludedGlyphs.contains(glyph)
        let colors = [ManualEntryPalette.mint, ManualEntryPalette.yellow, KidsTheme.lilac, KidsTheme.blue]

        return Button {
            inputFocused = false
            guard !alreadyAdded else { return }
            if selected { excludedGlyphs.insert(glyph) }
            else { excludedGlyphs.remove(glyph) }
        } label: {
            VStack(spacing: 3) {
                Text(glyph)
                    .font(.system(size: 31, weight: .bold, design: .serif))
                    .foregroundStyle(ManualEntryPalette.ink)
                Text(alreadyAdded ? "已收录" : (selected ? "已选" : "点选"))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(ManualEntryPalette.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity).frame(height: 67)
            .background(alreadyAdded ? ManualEntryPalette.paper : (selected ? colors[index % colors.count] : colors[index % colors.count].opacity(0.35)), in: RoundedRectangle(cornerRadius: 17))
            .shadow(color: ManualEntryPalette.ink.opacity(selected ? 0.10 : 0.03), radius: 6, x: 0, y: 3)
            .overlay(alignment: .topTrailing) {
                if !alreadyAdded {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManualEntryPalette.ink.opacity(0.7))
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded)
        .accessibilityLabel(alreadyAdded ? "\(glyph)，已收录" : "\(glyph)，\(selected ? "已选中" : "未选中")")
    }

    private func saveCharacters() {
        inputFocused = false
        let selected = selectedGlyphs
        guard !selected.isEmpty else { return }
        let alreadyPresent = detectedGlyphs.filter(app.contains).count
        let result = app.importCharacters(selected)
        guard result.added > 0 else {
            withAnimation {
                feedback = EntryFeedback(message: "这些字已经在你的图鉴里啦", isSuccess: false)
            }
            return
        }
        excludedGlyphs.formUnion(selected)
        withAnimation {
            feedback = EntryFeedback(
                message: "收集成功！新增 \(result.added) 个字\(alreadyPresent > 0 ? "，\(alreadyPresent) 个已收录" : "")",
                isSuccess: true
            )
        }
    }

    private func isHanCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else { return false }
        let code = scalar.value
        return (0x3400...0x4DBF).contains(code)
            || (0x4E00...0x9FFF).contains(code)
            || (0xF900...0xFAFF).contains(code)
    }
}

private struct EntryFeedback {
    let message: String
    let isSuccess: Bool
}
