import AVFoundation
import SwiftUI

private struct PhonicsChunk: Identifiable {
    let spelling: String
    let ipa: String
    let hint: String
    let isSilent: Bool
    var id: String { "\(spelling)-\(ipa)" }
}

private struct PhonicsWordResult {
    let word: String
    let chunks: [PhonicsChunk]
    let note: String?
    let isCurated: Bool
    var ipa: String { chunks.map(\.ipa).joined() }
}

/// A small, transparent first-pass grapheme-to-phoneme decoder. Curated words take
/// precedence; unknown words use longest-match spelling rules and are labelled as estimates.
private enum EnglishPhonicsDecoder {
    private static let curated: [String: [PhonicsChunk]] = [
        "ship": [.init(spelling: "sh", ipa: "ʃ", hint: "sh 常见发音", isSilent: false), .init(spelling: "i", ipa: "ɪ", hint: "短元音 i", isSilent: false), .init(spelling: "p", ipa: "p", hint: "辅音 p", isSilent: false)],
        "shop": [.init(spelling: "sh", ipa: "ʃ", hint: "sh 常见发音", isSilent: false), .init(spelling: "o", ipa: "ɑ", hint: "短元音 o（美式）", isSilent: false), .init(spelling: "p", ipa: "p", hint: "辅音 p", isSilent: false)],
        "chat": [.init(spelling: "ch", ipa: "tʃ", hint: "ch 常见发音", isSilent: false), .init(spelling: "a", ipa: "æ", hint: "短元音 a", isSilent: false), .init(spelling: "t", ipa: "t", hint: "辅音 t", isSilent: false)],
        "thin": [.init(spelling: "th", ipa: "θ", hint: "清辅音 th", isSilent: false), .init(spelling: "i", ipa: "ɪ", hint: "短元音 i", isSilent: false), .init(spelling: "n", ipa: "n", hint: "辅音 n", isSilent: false)],
        "this": [.init(spelling: "th", ipa: "ð", hint: "浊辅音 th", isSilent: false), .init(spelling: "i", ipa: "ɪ", hint: "短元音 i", isSilent: false), .init(spelling: "s", ipa: "s", hint: "辅音 s", isSilent: false)],
        "make": [.init(spelling: "m", ipa: "m", hint: "辅音 m", isSilent: false), .init(spelling: "a", ipa: "eɪ", hint: "a_e：不发音的 e 帮助前面的 a 发长音", isSilent: false), .init(spelling: "k", ipa: "k", hint: "辅音 k", isSilent: false), .init(spelling: "e", ipa: "", hint: "末尾 e 不发音", isSilent: true)],
        "time": [.init(spelling: "t", ipa: "t", hint: "辅音 t", isSilent: false), .init(spelling: "i", ipa: "aɪ", hint: "i_e：不发音的 e 帮助前面的 i 发长音", isSilent: false), .init(spelling: "m", ipa: "m", hint: "辅音 m", isSilent: false), .init(spelling: "e", ipa: "", hint: "末尾 e 不发音", isSilent: true)],
        "home": [.init(spelling: "h", ipa: "h", hint: "辅音 h", isSilent: false), .init(spelling: "o", ipa: "oʊ", hint: "o_e：不发音的 e 帮助前面的 o 发长音", isSilent: false), .init(spelling: "m", ipa: "m", hint: "辅音 m", isSilent: false), .init(spelling: "e", ipa: "", hint: "末尾 e 不发音", isSilent: true)],
        "rain": [.init(spelling: "r", ipa: "r", hint: "辅音 r", isSilent: false), .init(spelling: "ai", ipa: "eɪ", hint: "元音组合 ai", isSilent: false), .init(spelling: "n", ipa: "n", hint: "辅音 n", isSilent: false)],
        "boat": [.init(spelling: "b", ipa: "b", hint: "辅音 b", isSilent: false), .init(spelling: "oa", ipa: "oʊ", hint: "元音组合 oa", isSilent: false), .init(spelling: "t", ipa: "t", hint: "辅音 t", isSilent: false)],
        "seed": [.init(spelling: "s", ipa: "s", hint: "辅音 s", isSilent: false), .init(spelling: "ee", ipa: "iː", hint: "元音组合 ee", isSilent: false), .init(spelling: "d", ipa: "d", hint: "辅音 d", isSilent: false)],
        "book": [.init(spelling: "b", ipa: "b", hint: "辅音 b", isSilent: false), .init(spelling: "oo", ipa: "ʊ", hint: "oo 在 book 中发 /ʊ/", isSilent: false), .init(spelling: "k", ipa: "k", hint: "ck 发 /k/", isSilent: false)],
        "moon": [.init(spelling: "m", ipa: "m", hint: "辅音 m", isSilent: false), .init(spelling: "oo", ipa: "uː", hint: "oo 在 moon 中发 /uː/", isSilent: false), .init(spelling: "n", ipa: "n", hint: "辅音 n", isSilent: false)],
        "cow": [.init(spelling: "c", ipa: "k", hint: "c 在这里发 /k/", isSilent: false), .init(spelling: "ow", ipa: "aʊ", hint: "ow 在 cow 中发 /aʊ/", isSilent: false)],
        "snow": [.init(spelling: "s", ipa: "s", hint: "辅音 s", isSilent: false), .init(spelling: "n", ipa: "n", hint: "辅音 n", isSilent: false), .init(spelling: "ow", ipa: "oʊ", hint: "ow 在 snow 中发 /oʊ/", isSilent: false)],
        "coin": [.init(spelling: "c", ipa: "k", hint: "辅音 c", isSilent: false), .init(spelling: "oi", ipa: "ɔɪ", hint: "元音组合 oi", isSilent: false), .init(spelling: "n", ipa: "n", hint: "辅音 n", isSilent: false)],
        "car": [.init(spelling: "c", ipa: "k", hint: "辅音 c", isSilent: false), .init(spelling: "ar", ipa: "ɑr", hint: "r 控制元音 ar（美式）", isSilent: false)],
        "bird": [.init(spelling: "b", ipa: "b", hint: "辅音 b", isSilent: false), .init(spelling: "ir", ipa: "ɝ", hint: "r 控制元音 ir（美式）", isSilent: false), .init(spelling: "d", ipa: "d", hint: "辅音 d", isSilent: false)],
        "cake": [.init(spelling: "c", ipa: "k", hint: "辅音 c", isSilent: false), .init(spelling: "a", ipa: "eɪ", hint: "a_e：不发音的 e 帮助前面的 a 发长音", isSilent: false), .init(spelling: "k", ipa: "k", hint: "辅音 k", isSilent: false), .init(spelling: "e", ipa: "", hint: "末尾 e 不发音", isSilent: true)],
        "night": [.init(spelling: "n", ipa: "n", hint: "辅音 n", isSilent: false), .init(spelling: "igh", ipa: "aɪ", hint: "常见组合 igh", isSilent: false), .init(spelling: "t", ipa: "t", hint: "辅音 t", isSilent: false)],
        "teacher": [.init(spelling: "t", ipa: "t", hint: "辅音 t", isSilent: false), .init(spelling: "ea", ipa: "iː", hint: "元音组合 ea", isSilent: false), .init(spelling: "ch", ipa: "tʃ", hint: "ch 常见发音", isSilent: false), .init(spelling: "er", ipa: "ər", hint: "非重读 er", isSilent: false)],
        "rabbit": [.init(spelling: "r", ipa: "r", hint: "辅音 r", isSilent: false), .init(spelling: "a", ipa: "æ", hint: "短元音 a", isSilent: false), .init(spelling: "b", ipa: "b", hint: "辅音 b", isSilent: false), .init(spelling: "b", ipa: "b", hint: "双写辅音，发一个 /b/", isSilent: false), .init(spelling: "i", ipa: "ɪ", hint: "短元音 i", isSilent: false), .init(spelling: "t", ipa: "t", hint: "辅音 t", isSilent: false)]
    ]

    private struct Rule { let text: String; let ipa: String; let hint: String }
    private static let rules: [Rule] = [
        .init(text: "tch", ipa: "tʃ", hint: "tch 常见发音"), .init(text: "igh", ipa: "aɪ", hint: "igh 常见发音"),
        .init(text: "dge", ipa: "dʒ", hint: "dge 常见发音"), .init(text: "sh", ipa: "ʃ", hint: "sh 常见发音"),
        .init(text: "ch", ipa: "tʃ", hint: "ch 常见发音"), .init(text: "th", ipa: "θ", hint: "th 可能发 /θ/ 或 /ð/，此处按常见清辅音估读"),
        .init(text: "ph", ipa: "f", hint: "ph 常见发音"), .init(text: "wh", ipa: "w", hint: "wh 常见发音"),
        .init(text: "ck", ipa: "k", hint: "ck 发 /k/"), .init(text: "ng", ipa: "ŋ", hint: "ng 常见发音"),
        .init(text: "ai", ipa: "eɪ", hint: "ai 常见发音"), .init(text: "ay", ipa: "eɪ", hint: "ay 常见发音"),
        .init(text: "ee", ipa: "iː", hint: "ee 常见发音"), .init(text: "ea", ipa: "iː", hint: "ea 常见读音之一"),
        .init(text: "oa", ipa: "oʊ", hint: "oa 常见发音"), .init(text: "igh", ipa: "aɪ", hint: "igh 常见发音"),
        .init(text: "oi", ipa: "ɔɪ", hint: "oi 常见发音"), .init(text: "oy", ipa: "ɔɪ", hint: "oy 常见发音"),
        .init(text: "oo", ipa: "uː", hint: "oo 有多种读音，暂按 /uː/ 估读"), .init(text: "ow", ipa: "aʊ", hint: "ow 可能读 /aʊ/ 或 /oʊ/，暂按 /aʊ/ 估读"),
        .init(text: "ou", ipa: "aʊ", hint: "ou 有多种读音，暂按 /aʊ/ 估读"), .init(text: "ar", ipa: "ɑr", hint: "r 控制元音 ar（美式）"),
        .init(text: "or", ipa: "ɔr", hint: "r 控制元音 or（美式）"), .init(text: "er", ipa: "ɝ", hint: "r 控制元音 er（美式）"),
        .init(text: "ir", ipa: "ɝ", hint: "r 控制元音 ir（美式）"), .init(text: "ur", ipa: "ɝ", hint: "r 控制元音 ur（美式）"),
        .init(text: "ue", ipa: "uː", hint: "ue 常见读音之一"), .init(text: "ew", ipa: "uː", hint: "ew 有多种读音，暂按 /uː/ 估读"),
        .init(text: "qu", ipa: "kw", hint: "qu 常见发音")
    ]

    static func decode(_ input: String) -> PhonicsWordResult? {
        let word = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !word.isEmpty, word.count <= 24,
              word.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz").contains($0) }) else { return nil }
        if let known = curated[word] { return .init(word: word, chunks: known, note: nil, isCurated: true) }

        var letters = Array(word)
        var silentFinalE = false
        if letters.count >= 4, letters.last == "e",
           "aeiou".contains(letters[letters.count - 3]),
           !"aeiou".contains(letters[letters.count - 2]),
           !word.hasSuffix("le"), !word.hasSuffix("ee"), !word.hasSuffix("ye") {
            silentFinalE = true
            letters.removeLast()
            let vowelIndex = letters.count - 2
            let vowel = letters[vowelIndex]
            let longIPA: [Character: String] = ["a": "eɪ", "e": "iː", "i": "aɪ", "o": "oʊ", "u": "juː"]
            if longIPA[vowel] != nil {
                // Mark the vowel for the CVCe rule; the final e is added below as silent.
                letters[vowelIndex] = Character(String(vowel).uppercased())
            }
        }

        let singles: [Character: (String, String)] = [
            "a": ("æ", "短元音 a 的常见读音"), "e": ("ɛ", "短元音 e 的常见读音"),
            "i": ("ɪ", "短元音 i 的常见读音"), "o": ("ɑ", "短元音 o（美式）的常见读音"),
            "u": ("ʌ", "短元音 u 的常见读音"), "b": ("b", "辅音 b"), "c": ("k", "c 暂按 /k/ 估读"),
            "d": ("d", "辅音 d"), "f": ("f", "辅音 f"), "g": ("g", "g 暂按 /g/ 估读"),
            "h": ("h", "辅音 h"), "j": ("dʒ", "辅音 j"), "k": ("k", "辅音 k"), "l": ("l", "辅音 l"),
            "m": ("m", "辅音 m"), "n": ("n", "辅音 n"), "p": ("p", "辅音 p"), "r": ("r", "辅音 r（美式）"),
            "s": ("s", "辅音 s"), "t": ("t", "辅音 t"), "v": ("v", "辅音 v"), "w": ("w", "辅音 w"),
            "x": ("ks", "x 常见发音"), "y": ("j", "词首 y 常见发音"), "z": ("z", "辅音 z")
        ]
        let longVowels: [Character: String] = ["a": "eɪ", "e": "iː", "i": "aɪ", "o": "oʊ", "u": "juː"]
        var result: [PhonicsChunk] = []
        var index = 0
        var uncertainty = false
        while index < letters.count {
            let tail = String(letters[index...]).lowercased()
            if let rule = rules.first(where: { tail.hasPrefix($0.text) }) {
                result.append(.init(spelling: rule.text, ipa: rule.ipa, hint: rule.hint, isSilent: false))
                if rule.hint.contains("多种") || rule.hint.contains("可能") { uncertainty = true }
                index += rule.text.count
                continue
            }
            let letter = letters[index]
            if letter.isUppercase, let ipa = longVowels[Character(String(letter).lowercased())] {
                result.append(.init(spelling: String(letter).lowercased(), ipa: ipa, hint: "CVCe 长元音规则", isSilent: false))
            } else if letter == "y", index == letters.count - 1 {
                result.append(.init(spelling: "y", ipa: "i", hint: "词尾 y 常读 /i/", isSilent: false))
            } else if let (ipa, hint) = singles[letter] {
                result.append(.init(spelling: String(letter), ipa: ipa, hint: hint, isSilent: false))
                if ["c", "g", "a", "e", "i", "o", "u"].contains(letter) { uncertainty = true }
            } else {
                result.append(.init(spelling: String(letter), ipa: "", hint: "暂未收录此字母的发音规则", isSilent: false))
                uncertainty = true
            }
            index += 1
        }
        if silentFinalE {
            result.append(.init(spelling: "e", ipa: "", hint: "末尾 e 通常不发音", isSilent: true))
        }
        let note = uncertainty ? "这是按常见规则生成的初步拆分；英语拼写有多种读法，建议结合整词发音核对。" : ""
        return .init(word: word, chunks: result, note: note, isCurated: false)
    }
}

@MainActor
private final class PhonicsSpeech {
    private let synthesizer = AVSpeechSynthesizer()

    func speakWord(_ word: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        synthesizer.speak(utterance)
    }

    func speakIPA(_ ipa: String, for spelling: String) {
        guard !ipa.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let text = NSAttributedString(string: spelling, attributes: [NSAttributedString.Key(AVSpeechSynthesisIPANotationAttribute): ipa])
        let utterance = AVSpeechUtterance(attributedString: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.7
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

struct EnglishPhonicsScreen: View {
    @State private var input = "ship"
    @State private var result = EnglishPhonicsDecoder.decode("ship")
    @State private var speech = PhonicsSpeech()
    @FocusState private var inputFocused: Bool
    @State private var message: String?

    private let colors: [Color] = [KidsTheme.mint, KidsTheme.yellow, KidsTheme.lilac, KidsTheme.blue, KidsTheme.peach]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                inputRow
                if let result { resultCard(result) }
                examples
            }
            .padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { StorybookBackground() }
        .navigationTitle("自然拼读拆词")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speech.stop() }
        .alert("暂时无法拆分", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("把字母组合起来，读出单词")
                .font(.system(size: 25, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
            Text("先找字母组合，再听每个声音，最后合起来读。当前使用美式英语发音。")
                .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(KidsTheme.muted)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("输入一个英文单词", text: $input)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.alphabet)
                .submitLabel(.done).focused($inputFocused).onSubmit { decode() }
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .padding(.horizontal, 16).frame(height: 54).background(.white, in: RoundedRectangle(cornerRadius: 16))
            Button(action: decode) {
                Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .black)).foregroundStyle(.white)
                    .frame(width: 54, height: 54).background(KidsTheme.orange, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain).accessibilityLabel("拆分单词")
        }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("试试这些单词").font(.system(size: 16, weight: .black, design: .rounded))
            Text("ship · chat · make · rain · boat · night · teacher · rabbit")
                .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(KidsTheme.muted)
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(KidsTheme.blue.opacity(0.24), in: RoundedRectangle(cornerRadius: 18))
    }

    private func resultCard(_ result: PhonicsWordResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            wordHeading(result)
            Text("/\(result.ipa)/").font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(KidsTheme.orange)
            Text("从左到右拼读").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(KidsTheme.ink)
            chunkGrid(result)
            flow(result)
            resultNotice(result)
        }
        .padding(18).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
    }

    private func wordHeading(_ result: PhonicsWordResult) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(result.word).font(.system(size: 35, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
            Spacer()
            Button { speech.speakWord(result.word) } label: {
                Label("听整词", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10).background(KidsTheme.yellow, in: Capsule())
            }.buttonStyle(.plain)
        }
    }

    private func chunkGrid(_ result: PhonicsWordResult) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 10)], spacing: 10) {
            ForEach(Array(result.chunks.enumerated()), id: \.offset) { index, chunk in
                chunkButton(chunk, color: colors[index % colors.count])
            }
        }
    }

    private func chunkButton(_ chunk: PhonicsChunk, color: Color) -> some View {
        Button { speech.speakIPA(chunk.ipa, for: chunk.spelling) } label: {
            VStack(spacing: 7) {
                Text(chunk.spelling).font(.system(size: 28, weight: .black, design: .rounded))
                    .strikethrough(chunk.isSilent, color: KidsTheme.muted)
                Text(chunk.isSilent ? "不发音" : "/\(chunk.ipa)/").font(.system(size: 15, weight: .bold, design: .rounded))
                Text(chunk.hint).font(.system(size: 10, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(3).frame(height: 36)
            }
            .foregroundStyle(chunk.isSilent ? KidsTheme.muted : KidsTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 118).padding(8)
            .background(color.opacity(chunk.isSilent ? 0.3 : 0.74), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain).disabled(chunk.isSilent || chunk.ipa.isEmpty)
    }

    private func flow(_ result: PhonicsWordResult) -> some View {
        let spokenSounds = result.chunks.filter { !$0.isSilent }.map(\.ipa).joined(separator: " · ")
        return HStack(spacing: 8) {
            Image(systemName: "arrow.right").font(.system(size: 15, weight: .black))
            Text(spokenSounds).font(.system(size: 15, weight: .bold, design: .rounded))
            Image(systemName: "arrow.right").font(.system(size: 15, weight: .black))
            Text(result.word).font(.system(size: 19, weight: .black, design: .rounded))
        }
        .foregroundStyle(KidsTheme.ink).padding(13).frame(maxWidth: .infinity)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 15))
    }

    @ViewBuilder
    private func resultNotice(_ result: PhonicsWordResult) -> some View {
        if let note = result.note, !note.isEmpty {
            Label(note, systemImage: "info.circle.fill").font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(KidsTheme.ink).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(KidsTheme.yellow.opacity(0.45), in: RoundedRectangle(cornerRadius: 15))
        } else if result.isCurated {
            Label("这个词有专门校对过的拆分结果。", systemImage: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(KidsTheme.ink)
        }
    }

    private func decode() {
        inputFocused = false
        guard let decoded = EnglishPhonicsDecoder.decode(input) else {
            message = "请输入 1 到 24 个字母组成的英文单词。"
            return
        }
        result = decoded
    }
}
