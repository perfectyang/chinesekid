import Foundation

struct CharacterPronunciation: Codable, Hashable, Identifiable {
    let pinyin: String
    let example: String
    let meaning: String

    var id: String { pinyin }
}

enum PolyphonicReadings {
    // A small, child-friendly starter dictionary. The SQLite readings_json
    // column keeps these options with each character and can grow over time.
    static let catalog: [String: [CharacterPronunciation]] = [
        "行": [
            .init(pinyin: "xíng", example: "行走", meaning: "走路、行动"),
            .init(pinyin: "háng", example: "银行", meaning: "办理存钱和取钱的地方")
        ],
        "乐": [
            .init(pinyin: "lè", example: "快乐", meaning: "开心、高兴"),
            .init(pinyin: "yuè", example: "音乐", meaning: "歌曲和乐曲")
        ],
        "重": [
            .init(pinyin: "zhòng", example: "重要", meaning: "很要紧"),
            .init(pinyin: "chóng", example: "重复", meaning: "再来一次")
        ],
        "长": [
            .init(pinyin: "cháng", example: "长短", meaning: "从一头到另一头的距离"),
            .init(pinyin: "zhǎng", example: "长大", meaning: "慢慢长高、长成")
        ],
        "好": [
            .init(pinyin: "hǎo", example: "好朋友", meaning: "亲近、友善的朋友"),
            .init(pinyin: "hào", example: "爱好", meaning: "喜欢做的事情")
        ],
        "得": [
            .init(pinyin: "dé", example: "得到", meaning: "获得"),
            .init(pinyin: "děi", example: "得回家", meaning: "需要、必须"),
            .init(pinyin: "de", example: "跑得快", meaning: "用在动词后连接结果")
        ],
        "应": [
            .init(pinyin: "yīng", example: "应该", meaning: "理当这样"),
            .init(pinyin: "yìng", example: "答应", meaning: "同意别人的请求")
        ],
        "还": [
            .init(pinyin: "hái", example: "还有", meaning: "仍然、此外"),
            .init(pinyin: "huán", example: "归还", meaning: "把东西送回去")
        ],
        "着": [
            .init(pinyin: "zhe", example: "看着", meaning: "表示动作正在继续"),
            .init(pinyin: "zháo", example: "着火", meaning: "碰上、达到"),
            .init(pinyin: "zhuó", example: "着装", meaning: "穿戴衣物")
        ],
        "只": [
            .init(pinyin: "zhǐ", example: "只有", meaning: "仅仅"),
            .init(pinyin: "zhī", example: "一只鸟", meaning: "用于一些动物的量词")
        ],
        "空": [
            .init(pinyin: "kōng", example: "天空", meaning: "地面以上广阔的空间"),
            .init(pinyin: "kòng", example: "空地", meaning: "空出来的地方")
        ],
        "发": [
            .init(pinyin: "fā", example: "发现", meaning: "看到或找到原来没注意的事物"),
            .init(pinyin: "fà", example: "头发", meaning: "长在头上的毛发")
        ],
        "便": [
            .init(pinyin: "biàn", example: "方便", meaning: "便利、省事"),
            .init(pinyin: "pián", example: "便宜", meaning: "价钱低")
        ],
        "角": [
            .init(pinyin: "jiǎo", example: "角落", meaning: "边角的位置"),
            .init(pinyin: "jué", example: "角色", meaning: "故事或戏剧中的人物")
        ],
        "教": [
            .init(pinyin: "jiào", example: "教师", meaning: "教别人知识的人"),
            .init(pinyin: "jiāo", example: "教汉字", meaning: "把知识或本领传给别人")
        ],
        "校": [
            .init(pinyin: "xiào", example: "学校", meaning: "学习知识的地方"),
            .init(pinyin: "jiào", example: "校对", meaning: "检查文字或数字是否准确")
        ],
        "都": [
            .init(pinyin: "dōu", example: "大家都来", meaning: "表示全部"),
            .init(pinyin: "dū", example: "首都", meaning: "国家的中心城市")
        ],
        "少": [
            .init(pinyin: "shǎo", example: "多少", meaning: "数量不多"),
            .init(pinyin: "shào", example: "少年", meaning: "年纪较小的人")
        ],
        "中": [
            .init(pinyin: "zhōng", example: "中间", meaning: "两边之间"),
            .init(pinyin: "zhòng", example: "中奖", meaning: "碰巧得到奖品")
        ],
        "数": [
            .init(pinyin: "shù", example: "数字", meaning: "表示数量的符号"),
            .init(pinyin: "shǔ", example: "数一数", meaning: "一个一个地计算"),
            .init(pinyin: "shuò", example: "数见不鲜", meaning: "屡次、多次")
        ],
        "为": [
            .init(pinyin: "wéi", example: "成为", meaning: "变成"),
            .init(pinyin: "wèi", example: "为了", meaning: "表示目的或原因")
        ],
        "觉": [
            .init(pinyin: "jué", example: "觉得", meaning: "感觉到、认为"),
            .init(pinyin: "jiào", example: "睡觉", meaning: "休息时进入睡眠")
        ],
        "背": [
            .init(pinyin: "bèi", example: "后背", meaning: "身体的背面"),
            .init(pinyin: "bēi", example: "背书包", meaning: "把东西放在背上带着")
        ],
        "朝": [
            .init(pinyin: "cháo", example: "朝阳", meaning: "面对着太阳"),
            .init(pinyin: "zhāo", example: "朝气", meaning: "早晨的活力")
        ],
        "倒": [
            .init(pinyin: "dǎo", example: "倒下", meaning: "站立的东西横躺下来"),
            .init(pinyin: "dào", example: "倒水", meaning: "让液体从容器里出来")
        ],
        "调": [
            .init(pinyin: "tiáo", example: "调整", meaning: "改变后变得合适"),
            .init(pinyin: "diào", example: "调动", meaning: "调换、安排")
        ],
        "更": [
            .init(pinyin: "gèng", example: "更加", meaning: "程度比原来深"),
            .init(pinyin: "gēng", example: "三更", meaning: "旧时夜间计时的单位")
        ],
        "结": [
            .init(pinyin: "jié", example: "结果", meaning: "事情最后的情况"),
            .init(pinyin: "jiē", example: "结实", meaning: "植物长出果实")
        ],
        "尽": [
            .init(pinyin: "jìn", example: "用尽", meaning: "全部用完"),
            .init(pinyin: "jǐn", example: "尽量", meaning: "尽可能做到")
        ],
        "假": [
            .init(pinyin: "jiǎ", example: "真假", meaning: "不是真的"),
            .init(pinyin: "jià", example: "放假", meaning: "停止上学或工作休息")
        ],
        "处": [
            .init(pinyin: "chù", example: "到处", meaning: "各个地方"),
            .init(pinyin: "chǔ", example: "相处", meaning: "彼此生活或交往")
        ]
    ]

    static func encodedOptions(for glyph: String) -> String {
        guard let data = try? JSONEncoder().encode(catalog[glyph] ?? []) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func options(from json: String) -> [CharacterPronunciation] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([CharacterPronunciation].self, from: data)) ?? []
    }
}
