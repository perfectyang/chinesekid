import Foundation

struct PinyinUnit: Identifiable, Hashable {
    let categoryID: String
    let symbol: String
    let examplePinyin: String
    let example: String

    var id: String { "\(categoryID):\(symbol)" }
}

struct PinyinCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let items: [PinyinUnit]
}

enum PinyinCatalog {
    private static func category(_ id: String, _ title: String, _ subtitle: String, _ entries: [(String, String, String)]) -> PinyinCategory {
        PinyinCategory(
            id: id,
            title: title,
            subtitle: subtitle,
            items: entries.map { PinyinUnit(categoryID: id, symbol: $0.0, examplePinyin: $0.1, example: $0.2) }
        )
    }

    static let categories: [PinyinCategory] = [
        category("initial", "声母", "找准发音开头", [
            ("b", "bō", "玻璃"), ("p", "píng", "苹果"), ("m", "mā", "妈妈"), ("f", "fēi", "飞机"),
            ("d", "dà", "大树"), ("t", "tài", "太阳"), ("n", "nǎi", "奶奶"), ("l", "lǎo", "老师"),
            ("g", "gē", "哥哥"), ("k", "kāi", "开门"), ("h", "huā", "花朵"), ("j", "jī", "鸡蛋"),
            ("q", "qì", "气球"), ("x", "xī", "西瓜"), ("zh", "zhī", "知道"), ("ch", "chī", "吃饭"),
            ("sh", "shū", "书本"), ("r", "rì", "日出"), ("z", "zǎo", "早晨"), ("c", "cǎo", "草地"),
            ("s", "sān", "三明治"), ("y", "yǔ", "雨伞"), ("w", "wū", "乌龟")
        ]),
        category("simple", "单韵母", "一个韵母，读清楚", [
            ("a", "ā", "阿姨"), ("o", "ō", "哦，原来如此"), ("e", "é", "白鹅"),
            ("i", "yī", "衣服"), ("u", "wū", "乌云"), ("ü", "yú", "小鱼")
        ]),
        category("compound", "复韵母（双韵母）", "认识常见复合韵母", [
            ("ai", "ài", "爱心"), ("ei", "ēi", "诶，来了"), ("ui", "wéi", "围巾"),
            ("ao", "ǎo", "棉袄"), ("ou", "ōu", "海鸥"), ("iu", "yōu", "优秀"),
            ("ie", "yè", "叶子"), ("üe", "yuè", "月亮"), ("er", "ér", "儿童")
        ]),
        category("front_nasal", "前鼻韵母", "舌尖收尾 n", [
            ("an", "ān", "安全"), ("en", "ēn", "恩情"), ("in", "yīn", "音乐"),
            ("un", "wēn", "温暖"), ("ün", "yún", "白云")
        ]),
        category("back_nasal", "后鼻韵母", "舌根收尾 ng", [
            ("ang", "áng", "昂头"), ("eng", "fēng", "风筝"), ("ing", "xīng", "星星"), ("ong", "dōng", "冬天")
        ]),
        category("whole", "整体认读音节", "整体记住，直接读出来", [
            ("zhi", "zhī", "知道"), ("chi", "chī", "吃饭"), ("shi", "shī", "老师"), ("ri", "rī", "一声练习"),
            ("zi", "zī", "滋味"), ("ci", "cī", "呲牙"), ("si", "sī", "丝线"), ("yi", "yī", "衣服"),
            ("wu", "wū", "乌龟"), ("yu", "yū", "淤泥"), ("ye", "yē", "椰子"), ("yue", "yuē", "约定"),
            ("yuan", "yuān", "冤枉"), ("yin", "yīn", "音乐"), ("yun", "yūn", "晕倒"), ("ying", "yīng", "欢迎")
        ])
    ]

    static let initials = ["b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]

    private static let finalsByInitial: [String: [String]] = [
        "b": ["a", "o", "ai", "ei", "ao", "an", "en", "ang", "eng", "i", "ie", "iao", "ian", "in", "ing", "u"],
        "p": ["a", "o", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "i", "ie", "iao", "ian", "in", "ing", "u"],
        "m": ["a", "o", "e", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "i", "ie", "iao", "ian", "in", "ing", "u"],
        "f": ["a", "o", "ei", "ou", "an", "en", "ang", "eng", "u"],
        "d": ["a", "e", "i", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "iao", "ian", "ing", "u", "uo", "ui", "uan", "un"],
        "t": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "iao", "ian", "ing", "u", "uo", "uan", "un"],
        "n": ["a", "e", "i", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "iao", "ie", "ian", "in", "ing", "u", "uo", "uan", "un", "ü", "üe"],
        "l": ["a", "o", "e", "i", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "iao", "ie", "ian", "in", "ing", "u", "uo", "uan", "un", "ü", "üe"],
        "g": ["a", "e", "u", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "ua", "uo", "uai", "ui", "uan", "un", "uang"],
        "k": ["a", "e", "u", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "ua", "uo", "uai", "ui", "uan", "un", "uang"],
        "h": ["a", "e", "u", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "ua", "uo", "uai", "ui", "uan", "un", "uang"],
        "j": ["i", "ia", "ie", "iao", "iu", "ian", "in", "iang", "ing", "iong", "ü", "üe", "üan", "ün"],
        "q": ["i", "ia", "ie", "iao", "iu", "ian", "in", "iang", "ing", "iong", "ü", "üe", "üan", "ün"],
        "x": ["i", "ia", "ie", "iao", "iu", "ian", "in", "iang", "ing", "iong", "ü", "üe", "üan", "ün"],
        "zh": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "ua", "uo", "uai", "ui", "uan", "un", "uang"],
        "ch": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "ua", "uo", "uai", "ui", "uan", "un", "uang"],
        "sh": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "ua", "uo", "uai", "ui", "uan", "un", "uang"],
        "r": ["e", "i", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "uo", "ui", "uan", "un"],
        "z": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "uo", "ui", "uan", "un"],
        "c": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "uo", "ui", "uan", "un"],
        "s": ["a", "e", "i", "ai", "ao", "ou", "an", "en", "ang", "eng", "ong", "u", "uo", "ui", "uan", "un"],
        "y": ["a", "o", "e", "i", "ü", "ao", "ou", "an", "ang", "ong", "in", "ing", "üe", "üan", "ün"],
        "w": ["a", "o", "u", "ai", "ei", "an", "ang", "eng"]
    ]

    static func finals(for initial: String) -> [String] { finalsByInitial[initial] ?? [] }

    static func spellingExample(initial: String, final: String, tone: Int) -> String {
        if tone == 0 {
            return "轻声示范：\(spellingAudio(initial: initial, final: final, tone: tone))"
        }
        let syllable = self.syllable(initial: initial, final: final, tone: tone)
        return "单音节读音：\(syllable) · 第\(tone)声"
    }

    static func spellingAudio(initial: String, final: String, tone: Int) -> String {
        let base = syllable(initial: initial, final: final, tone: 0)
        let key = "\(base):\(tone)"
        let examples: [String: String] = [
            "ba:1": "八个", "ba:2": "拔萝卜", "ba:3": "把手", "ba:4": "爸爸", "ba:0": "爸爸",
            "bo:1": "波浪", "bo:2": "博物馆", "bo:3": "跛脚", "bo:4": "玻璃",
            "ma:1": "妈妈", "ma:2": "麻花", "ma:3": "马路", "ma:4": "骂人", "ma:0": "妈妈",
            "pa:1": "趴下", "pa:2": "爬山", "pa:3": "耙地", "pa:4": "害怕",
            "da:1": "搭积木", "da:2": "回答", "da:3": "打球", "da:4": "大树",
            "ta:1": "他们", "ta:3": "塔楼", "ta:4": "踏步",
            "na:2": "拿来", "na:3": "哪里", "na:4": "那边",
            "la:1": "拉手", "la:2": "喇嘛", "la:3": "喇叭", "la:4": "蜡烛",
            "ji:1": "机器", "ji:2": "急忙", "ji:3": "几只", "ji:4": "记住",
            "qi:1": "七个", "qi:2": "齐全", "qi:3": "起来", "qi:4": "气球",
            "xi:1": "西瓜", "xi:2": "学习", "xi:3": "洗手", "xi:4": "细心",
            "zhi:1": "知道", "zhi:2": "直线", "zhi:3": "纸张", "zhi:4": "志气",
            "chi:1": "吃饭", "chi:2": "池塘", "chi:3": "尺子", "chi:4": "赤脚",
            "shi:1": "师生", "shi:2": "十个", "shi:3": "使劲", "shi:4": "世界",
            "zi:1": "资料", "zi:3": "紫色", "zi:4": "自己",
            "ci:1": "刺猬", "ci:2": "磁铁", "ci:4": "次序",
            "si:1": "司机", "si:3": "死心", "si:4": "四季",
            "yue:4": "月亮", "yu:2": "鱼儿", "yuan:2": "元旦", "yun:2": "云朵"
        ]
        return examples[key] ?? syllable(initial: initial, final: final, tone: tone)
    }

    static func syllable(initial: String, final: String, tone: Int) -> String {
        var base: String
        if ["j", "q", "x"].contains(initial), final.hasPrefix("ü") {
            base = initial + final.replacingOccurrences(of: "ü", with: "u")
        } else if initial == "y" {
            let ySpellings = ["i": "yi", "u": "yu", "ü": "yu", "üan": "yuan", "ün": "yun", "üe": "yue", "iou": "you", "uei": "wei", "uen": "wen"]
            base = ySpellings[final].map { $0 } ?? ("y" + final)
        } else if initial == "w" {
            let wSpellings = ["u": "wu", "uo": "wo"]
            base = wSpellings[final].map { $0 } ?? ("w" + final)
        } else {
            base = initial + final
        }
        guard (1...4).contains(tone) else { return base }
        let marks: [Character: [Character]] = [
            "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"],
            "i": ["ī", "í", "ǐ", "ì"], "o": ["ō", "ó", "ǒ", "ò"],
            "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"]
        ]
        let chars = Array(base)
        let targetIndex: Int? = {
            if let index = chars.firstIndex(of: "a") { return index }
            if let index = chars.firstIndex(of: "e") { return index }
            if base.contains("ou"), let index = chars.firstIndex(of: "o") { return index }
            if base.contains("iu"), let index = chars.lastIndex(of: "u") { return index }
            if base.contains("ui"), let index = chars.lastIndex(of: "i") { return index }
            return chars.indices.reversed().first { marks[chars[$0]] != nil }
        }()
        guard let targetIndex, let options = marks[chars[targetIndex]] else { return base }
        var marked = chars
        marked[targetIndex] = options[tone - 1]
        return String(marked)
    }
}
