import SwiftUI

private enum DecompositionPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let paper = KidsTheme.paper
    static let orange = KidsTheme.orange
    static let yellow = KidsTheme.yellow
    static let mint = KidsTheme.mint
    static let lilac = KidsTheme.lilac
    static let blue = KidsTheme.blue
}

private enum HanziLearningSource: String, CaseIterable, Identifiable {
    case textbook
    case collection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .textbook: "课本字库"
        case .collection: "我的图鉴"
        }
    }
}

private struct HanziTextbook: Decodable, Identifiable {
    let version: Int
    let id: String
    let title: String
    let sourceLabel: String
    let entries: [HanziTextbookEntry]
}

private struct HanziTextbookEntry: Decodable, Identifiable {
    let id: String
    let character: String
    let pinyin: String
    let structure: String
    let components: [String]
    let words: [String]
    let verified: Bool
}

private struct HanziLearningItem: Identifiable {
    let glyph: String
    let entry: HanziTextbookEntry?
    let graphCharacter: LearningCharacter?

    var id: String { glyph }
    var pinyin: String {
        if let value = graphCharacter?.pinyin, !value.isEmpty { return value }
        return entry?.pinyin ?? ""
    }
    var meaning: String { graphCharacter?.meaning ?? "" }
    var words: [String] {
        if let entry, !entry.words.isEmpty { return entry.words }
        return graphCharacter?.pronunciations.map(\.example) ?? []
    }
}

private enum HanziStructure: String, CaseIterable, Identifiable {
    case leftRight = "left-right"
    case topBottom = "top-bottom"
    case leftCenterRight = "left-center-right"
    case topCenterBottom = "top-center-bottom"
    case semiEnclosure = "semi-enclosure"
    case fullEnclosure = "full-enclosure"
    case tripartite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftRight: "左右结构"
        case .topBottom: "上下结构"
        case .leftCenterRight: "左中右结构"
        case .topCenterBottom: "上中下结构"
        case .semiEnclosure: "半包围结构"
        case .fullEnclosure: "全包围结构"
        case .tripartite: "其他三部分结构"
        }
    }
}

private enum HanziTextbookCatalog {
    private static let resources: [(name: String, title: String)] = [
        ("一年级上册", "一年级上册"), ("一年级下册", "一年级下册"),
        ("二年级上册", "二年级上册"), ("二年级下册", "二年级下册"),
        ("三年级上册", "三年级上册"), ("三年级下册", "三年级下册"),
        ("四年级上册", "四年级上册"), ("四年级下册", "四年级下册"),
        ("五年级上册", "五年级上册"), ("五年级下册", "五年级下册"),
        ("六年级上册", "六年级上册"), ("六年级下册", "六年级下册")
    ]

    static func load(bundle: Bundle = .main) -> [HanziTextbook] {
        resources.compactMap { resource in
            let url = bundle.url(forResource: resource.name, withExtension: "json", subdirectory: "Resources/hanzi")
                ?? bundle.url(forResource: resource.name, withExtension: "json", subdirectory: "hanzi")
                ?? bundle.url(forResource: resource.name, withExtension: "json")
            guard let url,
                  let data = try? Data(contentsOf: url),
                  let textbook = try? JSONDecoder().decode(HanziTextbook.self, from: data) else { return nil }
            return textbook
        }
    }
}

struct HanziDecompositionModuleScreen: View {
    @ObservedObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var textbooks = HanziTextbookCatalog.load()
    @State private var source: HanziLearningSource = .textbook
    @State private var selectedGrade = 1
    @State private var selectedVolume = 1
    @State private var selectedStructure: String?
    @State private var selectedGlyph: String?
    @StateObject private var speech = SpeechPlayer()

    private var selectedTextbook: HanziTextbook? {
        textbooks.first { $0.title == textbookTitle(grade: selectedGrade, volume: selectedVolume) }
    }

    private var allItems: [HanziLearningItem] {
        switch source {
        case .textbook:
            return (selectedTextbook?.entries ?? []).map { entry in
                HanziLearningItem(
                    glyph: entry.character,
                    entry: entry,
                    graphCharacter: app.characters.first { $0.glyph == entry.character }
                )
            }
        case .collection:
            return app.characters.map { character in
                HanziLearningItem(
                    glyph: character.glyph,
                    entry: textbooks.lazy.flatMap(\.entries).first { $0.character == character.glyph },
                    graphCharacter: character
                )
            }
        }
    }

    private var visibleItems: [HanziLearningItem] {
        guard let selectedStructure else { return allItems }
        if selectedStructure == "missing" { return allItems.filter { $0.entry == nil } }
        return allItems.filter { $0.entry?.structure == selectedStructure }
    }

    private var selectedItem: HanziLearningItem? {
        visibleItems.first { $0.glyph == selectedGlyph } ?? visibleItems.first
    }

    private var structureOptions: [(id: String?, title: String, count: Int)] {
        var options: [(id: String?, title: String, count: Int)] = [(nil, "全部", allItems.count)]
        options += HanziStructure.allCases
            .filter { structure in
                structure != .tripartite || allItems.contains { $0.entry?.structure == structure.rawValue }
            }
            .map { structure in
                (Optional(structure.rawValue), structure.title, allItems.filter { $0.entry?.structure == structure.rawValue }.count)
            }
        if source == .collection {
            let missingCount = allItems.filter { $0.entry == nil }.count
            if missingCount > 0 { options.append(("missing", "待补资料", missingCount)) }
        }
        return options
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        pageHeading
                        sourcePicker

                        if geometry.size.width >= 1050 {
                            HStack(alignment: .top, spacing: 20) {
                                if source == .textbook {
                                    textbookSidebar
                                        .frame(width: 285)
                                }
                                VStack(alignment: .leading, spacing: 18) {
                                    structureFilters
                                    lessonAndGrid(
                                        contentWidth: geometry.size.width - (source == .textbook ? 305 : 0),
                                        availableHeight: geometry.size.height
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        } else {
                            if source == .textbook { compactTextbookPicker }
                            structureFilters
                            lessonAndGrid(contentWidth: geometry.size.width, availableHeight: geometry.size.height)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 1900)
                    .frame(maxWidth: .infinity)
                }
            }
            .background { StorybookBackground() }
            .navigationTitle("汉字拆解")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        speech.stop()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear { selectFirstVisibleItem() }
        .onChange(of: source) { _, _ in
            selectedStructure = nil
            selectFirstVisibleItem()
        }
        .onChange(of: selectedGrade) { _, _ in
            selectedStructure = nil
            selectFirstVisibleItem()
        }
        .onChange(of: selectedVolume) { _, _ in
            selectedStructure = nil
            selectFirstVisibleItem()
        }
        .onChange(of: app.characters.map(\.glyph)) { _, _ in
            if source == .collection { selectFirstVisibleItem() }
        }
    }

    private var pageHeading: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(source == .textbook ? selectedTextbook?.title ?? "课本结构字库" : "我的图鉴")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(DecompositionPalette.muted)
                Text("看结构、听字音、连词义")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(DecompositionPalette.ink)
            }
            Spacer()
            Text("\(selectedIndex + 1) / \(max(visibleItems.count, 1))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(DecompositionPalette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.78), in: Capsule())
        }
    }

    private var selectedIndex: Int {
        visibleItems.firstIndex { $0.glyph == selectedItem?.glyph } ?? 0
    }

    private var selectionProgress: String {
        visibleItems.isEmpty ? "0 / 0" : "\(selectedIndex + 1) / \(visibleItems.count)"
    }

    private var sourcePicker: some View {
        HStack(spacing: 5) {
            ForEach(HanziLearningSource.allCases) { option in
                Button {
                    source = option
                } label: {
                    Label(option.title, systemImage: option == .textbook ? "book.closed" : "character.book.closed")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(source == option ? DecompositionPalette.ink : DecompositionPalette.muted)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(source == option ? DecompositionPalette.mint : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(5)
        .background(.white.opacity(0.72), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var textbookSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("选择年级与册次", systemImage: "book.closed.fill")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(DecompositionPalette.ink)

            VStack(spacing: 10) {
                ForEach(1...6, id: \.self) { grade in
                    HStack(spacing: 8) {
                        Text("\(grade)年级")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedGrade == grade ? .white : DecompositionPalette.muted)
                            .frame(width: 66, height: 38)
                            .background(selectedGrade == grade ? DecompositionPalette.ink : DecompositionPalette.paper, in: Capsule())
                        ForEach(1...2, id: \.self) { volume in
                            textbookButton(grade: grade, volume: volume)
                        }
                    }
                }
            }

            Text("字数按每册课本字库统计。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(DecompositionPalette.muted)
        }
        .padding(18)
        .background(.white.opacity(0.83), in: RoundedRectangle(cornerRadius: 24))
    }

    private var compactTextbookPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(1...6, id: \.self) { grade in
                        Button("\(grade)年级") { selectedGrade = grade }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedGrade == grade ? .white : DecompositionPalette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(selectedGrade == grade ? DecompositionPalette.ink : .white.opacity(0.8), in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 10) {
                ForEach(1...2, id: \.self) { volume in
                    textbookButton(grade: selectedGrade, volume: volume)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
    }

    private func textbookButton(grade: Int, volume: Int) -> some View {
        let isSelected = selectedGrade == grade && selectedVolume == volume
        let count = textbook(grade: grade, volume: volume)?.entries.count ?? 0
        return Button {
            selectedGrade = grade
            selectedVolume = volume
        } label: {
            VStack(spacing: 2) {
                Text(volume == 1 ? "上册" : "下册")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("\(count) 字")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? DecompositionPalette.ink : DecompositionPalette.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? DecompositionPalette.mint.opacity(0.48) : .white.opacity(0.65), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? DecompositionPalette.ink.opacity(0.7) : DecompositionPalette.muted.opacity(0.2), lineWidth: 1.3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(grade)年级\(volume == 1 ? "上册" : "下册")，\(count)个汉字")
    }

    private var structureFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按结构筛选")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DecompositionPalette.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(structureOptions.enumerated()), id: \.offset) { _, option in
                        let isSelected = selectedStructure == option.id
                        Button {
                            applyFilter(option.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(option.title)
                                Text("(\(option.count))")
                                    .fontWeight(.medium)
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : DecompositionPalette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? DecompositionPalette.ink : .white.opacity(0.82), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(option.count == 0)
                        .opacity(option.count == 0 ? 0.48 : 1)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(15)
        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))
    }

    private var lessonCard: some View {
        Group {
            if let item = selectedItem {
                VStack(spacing: 15) {
                    HStack {
                        Text(source == .textbook ? selectedTextbook?.title ?? "课本字库" : "我的图鉴")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(DecompositionPalette.muted)
                        Spacer()
                        if let entry = item.entry {
                            Label(entry.verified ? "已校验字库" : "待校验", systemImage: entry.verified ? "checkmark.seal.fill" : "questionmark.circle")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(entry.verified ? Color(red: 0.1, green: 0.48, blue: 0.34) : DecompositionPalette.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(DecompositionPalette.mint.opacity(0.35), in: Capsule())
                        }
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Button { speech.speak(item.glyph) } label: {
                            ZStack(alignment: .bottomTrailing) {
                                Text(item.glyph)
                                    .font(.system(size: 148, weight: .medium, design: .serif))
                                    .foregroundStyle(DecompositionPalette.ink)
                                    .frame(width: 220, height: 220)
                                    .background(DecompositionPalette.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 34))
                                    .overlay(RoundedRectangle(cornerRadius: 34).strokeBorder(DecompositionPalette.muted.opacity(0.18), lineWidth: 2))
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(DecompositionPalette.ink)
                                    .padding(12)
                                    .background(.white.opacity(0.9), in: Circle())
                                    .padding(12)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("播放汉字\(item.glyph)")

                        VStack(alignment: .leading, spacing: 9) {
                            Text(item.pinyin.isEmpty ? "暂无拼音" : item.pinyin)
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(DecompositionPalette.orange)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(item.entry.map { HanziStructure(rawValue: $0.structure)?.title ?? "其他结构" } ?? "结构资料暂未收录")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(DecompositionPalette.muted)
                            if !item.meaning.isEmpty {
                                Text(item.meaning)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(DecompositionPalette.ink.opacity(0.82))
                                    .lineLimit(3)
                            }
                            characterNavigation
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let entry = item.entry, !entry.components.isEmpty {
                        componentEquation(entry.components, result: item.glyph)
                    } else if item.entry == nil {
                        Text("这个字目前没有对应的结构拆分资料，仍可在图鉴中保留。")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(DecompositionPalette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(DecompositionPalette.paper, in: RoundedRectangle(cornerRadius: 15))
                    }

                    if !item.words.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("读一读这些词语")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(DecompositionPalette.muted)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 8)], spacing: 8) {
                                ForEach(Array(item.words.enumerated()), id: \.offset) { _, word in
                                    Button { speech.speak(word) } label: {
                                        Label(word, systemImage: "speaker.wave.2")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(DecompositionPalette.ink)
                                            .frame(maxWidth: .infinity, minHeight: 42)
                                            .padding(.horizontal, 8)
                                            .background(.white.opacity(0.86), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 26))
            } else {
                VStack(spacing: 12) {
                    Text(source == .collection ? "图鉴里还没有汉字" : "这册字库暂时没有加载")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundStyle(DecompositionPalette.ink)
                    Text(source == .collection ? "先从首页拍照或手动收集生字。" : "请检查 Resources/hanzi 中的课本 JSON 文件。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(DecompositionPalette.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .padding(20)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 26))
            }
        }
    }

    private func componentEquation(_ components: [String], result: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("看看字形怎么组成")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(DecompositionPalette.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        componentTile(component)
                            .background(index.isMultiple(of: 2) ? DecompositionPalette.lilac.opacity(0.45) : DecompositionPalette.mint.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))
                        if index < components.count - 1 {
                            Text("+")
                                .font(.system(size: 27, weight: .medium, design: .rounded))
                                .foregroundStyle(DecompositionPalette.muted)
                        }
                    }
                    Text("=")
                        .font(.system(size: 27, weight: .medium, design: .rounded))
                        .foregroundStyle(DecompositionPalette.muted)
                    Text(result)
                        .font(.system(size: 62, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .frame(width: 112, height: 112)
                        .background(DecompositionPalette.ink, in: RoundedRectangle(cornerRadius: 22))
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func componentTile(_ component: String) -> some View {
        if Self.customStrokeComponents.contains(component) {
            GeometryReader { geometry in
                customStrokePath(component, in: CGRect(origin: .zero, size: geometry.size))
                    .stroke(DecompositionPalette.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 112, height: 112)
            .accessibilityLabel("笔画部件")
        } else {
            Text(component == "㇒" ? "丿" : component)
                .font(.system(size: 62, weight: .medium, design: .serif))
                .foregroundStyle(DecompositionPalette.ink)
                .frame(width: 112, height: 112)
        }
    }

    private static let customStrokeComponents: Set<String> = [
        "㇂", "㇃", "㇆", "㇇", "㇈", "㇉", "㇎", "㇏", "㇖", "㇗", "㇙", "㇛", "㇝", "㇠"
    ]

    private func customStrokePath(_ component: String, in rect: CGRect) -> Path {
        let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        return Path { path in
            switch component {
            case "㇂": // 横斜钩
                path.move(to: point(0.18, 0.25))
                path.addQuadCurve(to: point(0.76, 0.28), control: point(0.49, 0.12))
                path.addLine(to: point(0.56, 0.68))
                path.addQuadCurve(to: point(0.35, 0.78), control: point(0.48, 0.86))
            case "㇃": // 弯钩
                path.move(to: point(0.48, 0.16))
                path.addLine(to: point(0.48, 0.62))
                path.addQuadCurve(to: point(0.76, 0.73), control: point(0.50, 0.88))
                path.addQuadCurve(to: point(0.58, 0.83), control: point(0.78, 0.87))
            case "㇆": // 横折钩
                path.move(to: point(0.18, 0.22))
                path.addLine(to: point(0.82, 0.22))
                path.addLine(to: point(0.82, 0.70))
                path.addQuadCurve(to: point(0.59, 0.82), control: point(0.81, 0.89))
            case "㇇": // 横撇
                path.move(to: point(0.18, 0.26))
                path.addLine(to: point(0.82, 0.26))
                path.addLine(to: point(0.43, 0.78))
            case "㇈": // 横折弯钩
                path.move(to: point(0.18, 0.22))
                path.addLine(to: point(0.78, 0.22))
                path.addLine(to: point(0.78, 0.61))
                path.addQuadCurve(to: point(0.53, 0.76), control: point(0.78, 0.89))
                path.addQuadCurve(to: point(0.33, 0.68), control: point(0.40, 0.78))
            case "㇉": // 竖折折钩
                path.move(to: point(0.28, 0.14))
                path.addLine(to: point(0.28, 0.56))
                path.addLine(to: point(0.68, 0.56))
                path.addLine(to: point(0.68, 0.75))
                path.addQuadCurve(to: point(0.48, 0.82), control: point(0.68, 0.91))
            case "㇎": // 横折折折
                path.move(to: point(0.16, 0.20))
                path.addLine(to: point(0.80, 0.20))
                path.addLine(to: point(0.80, 0.43))
                path.addLine(to: point(0.42, 0.43))
                path.addLine(to: point(0.42, 0.68))
                path.addLine(to: point(0.72, 0.68))
            case "㇏": // 捺
                path.move(to: point(0.22, 0.24))
                path.addQuadCurve(to: point(0.80, 0.78), control: point(0.43, 0.55))
            case "㇖": // 横钩
                path.move(to: point(0.18, 0.30))
                path.addLine(to: point(0.80, 0.30))
                path.addQuadCurve(to: point(0.64, 0.50), control: point(0.84, 0.43))
            case "㇗": // 竖折
                path.move(to: point(0.28, 0.16))
                path.addLine(to: point(0.28, 0.72))
                path.addLine(to: point(0.78, 0.72))
            case "㇙": // 竖提
                path.move(to: point(0.28, 0.16))
                path.addLine(to: point(0.28, 0.76))
                path.addLine(to: point(0.78, 0.62))
            case "㇛": // 撇点
                path.move(to: point(0.75, 0.18))
                path.addQuadCurve(to: point(0.28, 0.70), control: point(0.53, 0.50))
                path.addQuadCurve(to: point(0.76, 0.82), control: point(0.44, 0.90))
            case "㇝": // 横撇弯钩
                path.move(to: point(0.16, 0.24))
                path.addLine(to: point(0.80, 0.24))
                path.addLine(to: point(0.48, 0.52))
                path.addQuadCurve(to: point(0.62, 0.82), control: point(0.28, 0.75))
                path.addQuadCurve(to: point(0.78, 0.73), control: point(0.76, 0.88))
            case "㇠": // 横斜弯钩
                path.move(to: point(0.16, 0.24))
                path.addQuadCurve(to: point(0.78, 0.30), control: point(0.48, 0.14))
                path.addLine(to: point(0.55, 0.60))
                path.addQuadCurve(to: point(0.77, 0.78), control: point(0.49, 0.82))
                path.addQuadCurve(to: point(0.84, 0.64), control: point(0.87, 0.79))
            default:
                break
            }
        }
    }

    private var characterNavigation: some View {
        HStack(spacing: 10) {
            navigationButton(title: "上一个字", symbol: "chevron.left", enabled: selectedIndex > 0) {
                moveSelection(by: -1)
            }
            Text(selectionProgress)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(DecompositionPalette.muted)
                .monospacedDigit()
            navigationButton(title: "下一个字", symbol: "chevron.right", enabled: selectedIndex + 1 < visibleItems.count) {
                moveSelection(by: 1)
            }
        }
        .padding(.top, 4)
    }

    private func navigationButton(title: String, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(DecompositionPalette.ink)
                .frame(width: 58, height: 58)
                .background(DecompositionPalette.mint.opacity(0.72), in: Circle())
                .overlay(Circle().strokeBorder(DecompositionPalette.ink.opacity(0.22), lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(title)
    }

    private func moveSelection(by offset: Int) {
        guard let index = visibleItems.firstIndex(where: { $0.glyph == selectedItem?.glyph }) else { return }
        let targetIndex = index + offset
        guard visibleItems.indices.contains(targetIndex) else { return }
        selectedGlyph = visibleItems[targetIndex].glyph
    }

    @ViewBuilder
    private func lessonAndGrid(contentWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let shouldSplit = horizontalSizeClass == .regular && contentWidth >= 720
        let gridWidth = min(max(contentWidth * 0.36, 285), 350)
        let gridHeight = min(max(availableHeight * 0.68, 420), 760)

        if shouldSplit {
            HStack(alignment: .top, spacing: 16) {
                lessonCard
                    .frame(maxWidth: .infinity)
                characterGrid(height: gridHeight)
                    .frame(width: gridWidth)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                lessonCard
                characterGrid(height: min(max(availableHeight * 0.5, 340), 560))
            }
        }
    }

    private func characterGrid(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(source == .textbook ? "本册汉字" : "我的汉字")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(DecompositionPalette.ink)
                Spacer()
                Text("\(visibleItems.count) 字")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DecompositionPalette.muted)
            }
            if source == .collection && allItems.isEmpty {
                Text("拍照或手动添加的汉字会显示在这里。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(DecompositionPalette.muted)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.glyph) { index, item in
                            Button {
                                selectedGlyph = item.glyph
                            } label: {
                                VStack(spacing: 3) {
                                    Text(item.glyph)
                                        .font(.system(size: 39, weight: .medium, design: .serif))
                                        .foregroundStyle(DecompositionPalette.ink)
                                    Text(item.pinyin.isEmpty ? " " : item.pinyin)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(DecompositionPalette.muted)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                }
                                .frame(maxWidth: .infinity, minHeight: 82)
                                .background(selectedGlyph == item.glyph ? DecompositionPalette.mint.opacity(0.72) : .white.opacity(0.84), in: RoundedRectangle(cornerRadius: 17))
                                .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(selectedGlyph == item.glyph ? DecompositionPalette.ink.opacity(0.75) : DecompositionPalette.muted.opacity(0.12), lineWidth: selectedGlyph == item.glyph ? 1.5 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("第\(index + 1)个，\(item.glyph)，\(item.pinyin)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(18)
        .frame(height: height)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 24))
    }

    private func applyFilter(_ structure: String?) {
        selectedStructure = structure
        selectedGlyph = items(matching: structure).first?.glyph
    }

    private func items(matching structure: String?) -> [HanziLearningItem] {
        guard let structure else { return allItems }
        if structure == "missing" { return allItems.filter { $0.entry == nil } }
        return allItems.filter { $0.entry?.structure == structure }
    }

    private func selectFirstVisibleItem() {
        selectedGlyph = visibleItems.first?.glyph
    }

    private func textbook(grade: Int, volume: Int) -> HanziTextbook? {
        textbooks.first { $0.title == textbookTitle(grade: grade, volume: volume) }
    }

    private func textbookTitle(grade: Int, volume: Int) -> String {
        "\(gradeChinese(grade))年级\(volume == 1 ? "上册" : "下册")"
    }

    private func gradeChinese(_ grade: Int) -> String {
        let numerals = ["", "一", "二", "三", "四", "五", "六"]
        guard (1...6).contains(grade) else { return "一" }
        return numerals[grade]
    }
}
