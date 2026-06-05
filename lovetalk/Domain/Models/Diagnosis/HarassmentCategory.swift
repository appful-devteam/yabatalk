import Foundation

/// 大分類（パワハラ / セクハラ / モラハラ / その他）
enum HarassmentCategory: String, Codable, CaseIterable, Sendable {
    case power = "powerHarassment"
    case sexual = "sexualHarassment"
    case moral = "moralHarassment"
    case other = "otherHarassment"

    var displayName: String {
        switch self {
        case .power: return "パワハラ"
        case .sexual: return "セクハラ"
        case .moral: return "モラハラ"
        case .other: return "その他ハラスメント"
        }
    }

    var shortName: String {
        switch self {
        case .power: return "パワハラ"
        case .sexual: return "セクハラ"
        case .moral: return "モラハラ"
        case .other: return "その他"
        }
    }

    var emoji: String {
        switch self {
        case .power: return "🪓"
        case .sexual: return "🫥"
        case .moral: return "🧸"
        case .other: return "🌀"
        }
    }
}

/// その他のサブ分類
enum HarassmentSubCategory: String, Codable, CaseIterable, Sendable {
    case gender         // ジェンダーハラ
    case academic       // アカハラ
    case customer       // カスハラ
    case alcohol        // アルハラ
    case maternity      // マタハラ / 育児介護
    case digital        // デジハラ
    case privacy        // プライバシー侵害
    case grouping       // 集団いじめ・排除

    var displayName: String {
        switch self {
        case .gender:    return "ジェンダーハラスメント"
        case .academic:  return "アカデミックハラスメント"
        case .customer:  return "カスタマーハラスメント"
        case .alcohol:   return "アルコールハラスメント"
        case .maternity: return "マタニティ／育児介護ハラスメント"
        case .digital:   return "デジタルハラスメント"
        case .privacy:   return "プライバシー侵害"
        case .grouping:  return "集団いじめ・排除"
        }
    }

    var trailingSuffix: String { "傾向" }

    var parentCategory: HarassmentCategory { .other }
}

/// リスクレベル
enum RiskLevel: String, Codable, CaseIterable, Sendable {
    case low        // 0-20
    case caution    // 21-40
    case medium     // 41-60
    case high       // 61-80
    case severe     // 81-100

    static func from(score: Int) -> RiskLevel {
        switch score {
        case ..<21:  return .low
        case 21..<41: return .caution
        case 41..<61: return .medium
        case 61..<81: return .high
        default:     return .severe
        }
    }

    var displayName: String {
        switch self {
        case .low:     return "低い"
        case .caution: return "注意"
        case .medium:  return "中"
        case .high:    return "高い"
        case .severe:  return "非常に高い"
        }
    }

    /// ダーク毒舌系の危険度ラベル（揺らし用に複数候補）
    var dangerLabelCandidates: [String] {
        switch self {
        case .low:
            return ["ほぼ平和", "ひとまず安全圏", "今のところセーフ"]
        case .caution:
            return ["ちょっと怪しい", "もやっと圏内", "微圧あり"]
        case .medium:
            return ["それなりに香る", "ちょっと焦げてる", "中辛"]
        case .high:
            return ["かなり香ばしい", "燻製レベル", "明確にやばい"]
        case .severe:
            return ["笑でごまかせないレベル", "丸焦げ", "即避難案件"]
        }
    }
}
