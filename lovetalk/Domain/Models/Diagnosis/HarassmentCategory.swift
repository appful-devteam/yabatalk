import Foundation

/// 大分類（パワハラ / セクハラ / モラハラ / その他）
enum HarassmentCategory: String, Codable, CaseIterable, Sendable {
    case power = "powerHarassment"
    case sexual = "sexualHarassment"
    case moral = "moralHarassment"
    case other = "otherHarassment"

    var displayName: String {
        switch self {
        case .power: return String(localized: "パワハラ", bundle: LanguageManager.appBundle)
        case .sexual: return String(localized: "セクハラ", bundle: LanguageManager.appBundle)
        case .moral: return String(localized: "モラハラ", bundle: LanguageManager.appBundle)
        case .other: return String(localized: "その他ハラスメント", bundle: LanguageManager.appBundle)
        }
    }

    var shortName: String {
        switch self {
        case .power: return String(localized: "パワハラ", bundle: LanguageManager.appBundle)
        case .sexual: return String(localized: "セクハラ", bundle: LanguageManager.appBundle)
        case .moral: return String(localized: "モラハラ", bundle: LanguageManager.appBundle)
        case .other: return String(localized: "その他", bundle: LanguageManager.appBundle)
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

    /// この分類が「どういうハラスメントか」の一言説明（スコアタブの分類カードで展開表示）。
    var explanation: String {
        switch self {
        case .power:
            return String(localized: "立場や力関係を使って、相手を追い詰めたり評価・居場所で脅したりするタイプ。", bundle: LanguageManager.appBundle)
        case .sexual:
            return String(localized: "性的な話題・距離感の踏み込みや、恋愛と評価をくっつけて効かせるタイプ。", bundle: LanguageManager.appBundle)
        case .moral:
            return String(localized: "罪悪感・束縛・「気のせい」での上書きなど、心理的にじわじわ削るタイプ。", bundle: LanguageManager.appBundle)
        case .other:
            return String(localized: "役割の押しつけ・お酒・客の立場・プライバシー侵害など、上記に収まらない圧。", bundle: LanguageManager.appBundle)
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
        case .gender:    return String(localized: "ジェンダーハラスメント", bundle: LanguageManager.appBundle)
        case .academic:  return String(localized: "アカデミックハラスメント", bundle: LanguageManager.appBundle)
        case .customer:  return String(localized: "カスタマーハラスメント", bundle: LanguageManager.appBundle)
        case .alcohol:   return String(localized: "アルコールハラスメント", bundle: LanguageManager.appBundle)
        case .maternity: return String(localized: "マタニティ／育児介護ハラスメント", bundle: LanguageManager.appBundle)
        case .digital:   return String(localized: "デジタルハラスメント", bundle: LanguageManager.appBundle)
        case .privacy:   return String(localized: "プライバシー侵害", bundle: LanguageManager.appBundle)
        case .grouping:  return String(localized: "集団いじめ・排除", bundle: LanguageManager.appBundle)
        }
    }

    var trailingSuffix: String { String(localized: "傾向", bundle: LanguageManager.appBundle) }

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
        case .low:     return String(localized: "低い", bundle: LanguageManager.appBundle)
        case .caution: return String(localized: "注意", bundle: LanguageManager.appBundle)
        case .medium:  return String(localized: "中", bundle: LanguageManager.appBundle)
        case .high:    return String(localized: "高い", bundle: LanguageManager.appBundle)
        case .severe:  return String(localized: "非常に高い", bundle: LanguageManager.appBundle)
        }
    }

    /// ダーク毒舌系の危険度ラベル（揺らし用に複数候補）
    var dangerLabelCandidates: [String] {
        switch self {
        case .low:
            return [String(localized: "ほぼ平和", bundle: LanguageManager.appBundle), String(localized: "ひとまず安全圏", bundle: LanguageManager.appBundle), String(localized: "今のところセーフ", bundle: LanguageManager.appBundle)]
        case .caution:
            return [String(localized: "ちょっと怪しい", bundle: LanguageManager.appBundle), String(localized: "もやっと圏内", bundle: LanguageManager.appBundle), String(localized: "微圧あり", bundle: LanguageManager.appBundle)]
        case .medium:
            return [String(localized: "それなりに香る", bundle: LanguageManager.appBundle), String(localized: "ちょっと焦げてる", bundle: LanguageManager.appBundle), String(localized: "中辛", bundle: LanguageManager.appBundle)]
        case .high:
            return [String(localized: "かなり香ばしい", bundle: LanguageManager.appBundle), String(localized: "燻製レベル", bundle: LanguageManager.appBundle), String(localized: "明確にやばい", bundle: LanguageManager.appBundle)]
        case .severe:
            return [String(localized: "笑でごまかせないレベル", bundle: LanguageManager.appBundle), String(localized: "丸焦げ", bundle: LanguageManager.appBundle), String(localized: "即避難案件", bundle: LanguageManager.appBundle)]
        }
    }
}
