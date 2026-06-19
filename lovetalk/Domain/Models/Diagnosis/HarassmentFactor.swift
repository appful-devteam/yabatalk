import Foundation

/// 診断構成要素（factor）
/// docs/spec/diagnosis-logic.md §1 と完全一致させる。
enum HarassmentFactor: String, Codable, CaseIterable, Sendable {
    case dominance              // 優位性
    case workEvaluation         // 業務・評価文脈
    case sexualContext          // 性的文脈
    case intimateRelationship   // 親密関係
    case personalityDenial      // 人格否定
    case abilityDenial          // 能力否定
    case existenceDenial        // 存在・所属否定
    case disadvantageThreat     // 不利益示唆
    case excessiveDemand        // 過大要求
    case refusalImpossible      // 拒否不能性
    case boundaryViolation      // 境界線侵害
    case persistentRepetition   // 反復性・執拗性
    case guiltManipulation      // 罪悪感操作
    case gaslighting            // ガスライティング
    case monitoringControl      // 監視・束縛
    case privacyIntrusion       // 私生活侵害
    case groupExclusion         // 集団排除
    case roleStereotype         // 属性・役割押し付け
    case quotaPairing           // 性的要求と評価の結合（複合 factor）
    case mockingLaughter        // 「笑」での圧の軽量化
    case alcoholCoercion        // 飲酒強要
    case customerAggression     // 顧客・取引先からの脅し
    case maternityPenalty       // 妊娠・育児・介護への不利益示唆
    case academicPower          // 学業権限の濫用

    /// 構成要素の正式名（日本語）
    var displayName: String {
        switch self {
        case .dominance:            return String(localized: "優位性", bundle: LanguageManager.appBundle)
        case .workEvaluation:       return String(localized: "業務・評価文脈", bundle: LanguageManager.appBundle)
        case .sexualContext:        return String(localized: "性的文脈", bundle: LanguageManager.appBundle)
        case .intimateRelationship: return String(localized: "親密関係", bundle: LanguageManager.appBundle)
        case .personalityDenial:    return String(localized: "人格否定", bundle: LanguageManager.appBundle)
        case .abilityDenial:        return String(localized: "能力否定", bundle: LanguageManager.appBundle)
        case .existenceDenial:      return String(localized: "存在・所属否定", bundle: LanguageManager.appBundle)
        case .disadvantageThreat:   return String(localized: "不利益示唆", bundle: LanguageManager.appBundle)
        case .excessiveDemand:      return String(localized: "過大要求", bundle: LanguageManager.appBundle)
        case .refusalImpossible:    return String(localized: "拒否不能性", bundle: LanguageManager.appBundle)
        case .boundaryViolation:    return String(localized: "境界線侵害", bundle: LanguageManager.appBundle)
        case .persistentRepetition: return String(localized: "反復性・執拗性", bundle: LanguageManager.appBundle)
        case .guiltManipulation:    return String(localized: "罪悪感操作", bundle: LanguageManager.appBundle)
        case .gaslighting:          return String(localized: "ガスライティング", bundle: LanguageManager.appBundle)
        case .monitoringControl:    return String(localized: "監視・束縛", bundle: LanguageManager.appBundle)
        case .privacyIntrusion:     return String(localized: "私生活侵害", bundle: LanguageManager.appBundle)
        case .groupExclusion:       return String(localized: "集団排除", bundle: LanguageManager.appBundle)
        case .roleStereotype:       return String(localized: "属性・役割押し付け", bundle: LanguageManager.appBundle)
        case .quotaPairing:         return String(localized: "評価と性的要求の結合", bundle: LanguageManager.appBundle)
        case .mockingLaughter:      return String(localized: "「笑」での軽量化", bundle: LanguageManager.appBundle)
        case .alcoholCoercion:      return String(localized: "飲酒強要", bundle: LanguageManager.appBundle)
        case .customerAggression:   return String(localized: "顧客・取引先からの脅し", bundle: LanguageManager.appBundle)
        case .maternityPenalty:     return String(localized: "妊娠・育児・介護への不利益示唆", bundle: LanguageManager.appBundle)
        case .academicPower:        return String(localized: "学業権限の濫用", bundle: LanguageManager.appBundle)
        }
    }

    /// 闇成分ミックスの表示名（毒見 UI 用）。揺らがず固定。
    var ingredientName: String {
        switch self {
        case .dominance:            return String(localized: "立場ふりかけ", bundle: LanguageManager.appBundle)
        case .workEvaluation:       return String(localized: "業務指導っぽさ", bundle: LanguageManager.appBundle)
        case .sexualContext:        return String(localized: "距離感バグ味", bundle: LanguageManager.appBundle)
        case .intimateRelationship: return String(localized: "親密関係コーティング", bundle: LanguageManager.appBundle)
        case .personalityDenial:    return String(localized: "人格削りパウダー", bundle: LanguageManager.appBundle)
        case .abilityDenial:        return String(localized: "能力否定ペッパー", bundle: LanguageManager.appBundle)
        case .existenceDenial:      return String(localized: "居場所はく奪エキス", bundle: LanguageManager.appBundle)
        case .disadvantageThreat:   return String(localized: "不利益ちらつかせシロップ", bundle: LanguageManager.appBundle)
        case .excessiveDemand:      return String(localized: "重労働シロップ", bundle: LanguageManager.appBundle)
        case .refusalImpossible:    return String(localized: "逃げ道ふさぎエキス", bundle: LanguageManager.appBundle)
        case .boundaryViolation:    return String(localized: "境界線ぶち破り味", bundle: LanguageManager.appBundle)
        case .persistentRepetition: return String(localized: "しつこさ煮込み", bundle: LanguageManager.appBundle)
        case .guiltManipulation:    return String(localized: "罪悪感の素", bundle: LanguageManager.appBundle)
        case .gaslighting:          return String(localized: "記憶改ざんスパイス", bundle: LanguageManager.appBundle)
        case .monitoringControl:    return String(localized: "監視・返信強要ジュース", bundle: LanguageManager.appBundle)
        case .privacyIntrusion:     return String(localized: "プライベート漬け", bundle: LanguageManager.appBundle)
        case .groupExclusion:       return String(localized: "仲間外し氷", bundle: LanguageManager.appBundle)
        case .roleStereotype:       return String(localized: "古臭い役割タレ", bundle: LanguageManager.appBundle)
        case .quotaPairing:         return String(localized: "評価との抱き合わせ", bundle: LanguageManager.appBundle)
        case .mockingLaughter:      return String(localized: "笑でごまかし", bundle: LanguageManager.appBundle)
        case .alcoholCoercion:      return String(localized: "飲酒強要ハイボール", bundle: LanguageManager.appBundle)
        case .customerAggression:   return String(localized: "クレーマー火薬", bundle: LanguageManager.appBundle)
        case .maternityPenalty:     return String(localized: "ライフイベント踏みつけ味", bundle: LanguageManager.appBundle)
        case .academicPower:        return String(localized: "研究室の絶対権力", bundle: LanguageManager.appBundle)
        }
    }

    /// 毒見アウトプットの quote 解説テンプレ（占い／友達のツッコミ寄りの柔らかトーン）
    func explanationTemplate() -> String {
        switch self {
        case .personalityDenial:
            return String(localized: "「やったこと」じゃなく「人としてどうなの」って言い方になりがち。", bundle: LanguageManager.appBundle)
        case .abilityDenial:
            return String(localized: "「ここを直そう」じゃなく「もうムリでしょ」って丸ごとパスかも。", bundle: LanguageManager.appBundle)
        case .existenceDenial:
            return String(localized: "居場所そのものを取り上げるみたいな言い方が混じってます。", bundle: LanguageManager.appBundle)
        case .disadvantageThreat:
            return String(localized: "「やらないと損するよ」って匂わせがちなタイプ。", bundle: LanguageManager.appBundle)
        case .refusalImpossible:
            return String(localized: "一見、選べそうで実は断りにくい言い方になってるかも。", bundle: LanguageManager.appBundle)
        case .excessiveDemand:
            return String(localized: "相手の体調や時間、ちょっと無視ぎみな要求が出てます。", bundle: LanguageManager.appBundle)
        case .sexualContext:
            return String(localized: "ちょっと距離感バグった、踏み込みすぎな話題かも。", bundle: LanguageManager.appBundle)
        case .quotaPairing:
            return String(localized: "色恋っぽい話と評価・仕事の話がくっついちゃってます。", bundle: LanguageManager.appBundle)
        case .mockingLaughter:
            return String(localized: "「笑」をつけてマイルドに見せてるけど、中身は結構強め。", bundle: LanguageManager.appBundle)
        case .guiltManipulation:
            return String(localized: "「私の気持ち、あなたのせい」風の言い回しが目立ちます。", bundle: LanguageManager.appBundle)
        case .gaslighting:
            return String(localized: "「そんなこと言ってない」「気のせい」で相手の感覚を上書きしがち。", bundle: LanguageManager.appBundle)
        case .monitoringControl:
            return String(localized: "返信や行動の追跡みがちょっと強めかも。", bundle: LanguageManager.appBundle)
        case .intimateRelationship:
            return String(localized: "愛情や関係性を条件にしたお願いが混ざってます。", bundle: LanguageManager.appBundle)
        case .boundaryViolation:
            return String(localized: "「やめて」「嫌」って言われた後にも、同じノリが続いてるかも。", bundle: LanguageManager.appBundle)
        case .persistentRepetition:
            return String(localized: "短時間にバババッと連投する追い打ちタイプ。", bundle: LanguageManager.appBundle)
        case .dominance:
            return String(localized: "「立場が上だから」を前提にしてる圧、ちょっと出てます。", bundle: LanguageManager.appBundle)
        case .workEvaluation:
            return String(localized: "評価・仕事・成績の話を持ち出して効かせるタイプかも。", bundle: LanguageManager.appBundle)
        case .privacyIntrusion:
            return String(localized: "プライベート、ちょっと踏み込みすぎな質問が混ざってます。", bundle: LanguageManager.appBundle)
        case .groupExclusion:
            return String(localized: "「あいつは入れない」みたいな、ハブり寄りの言い方かも。", bundle: LanguageManager.appBundle)
        case .roleStereotype:
            return String(localized: "「女だから」「男なら」みたいな、役割押しつけが入ってます。", bundle: LanguageManager.appBundle)
        case .alcoholCoercion:
            return String(localized: "「飲もうよ」「飲まないの？」が、ちょっと強引めかも。", bundle: LanguageManager.appBundle)
        case .customerAggression:
            return String(localized: "客・取引先の立場で押してくる、強気めな出方。", bundle: LanguageManager.appBundle)
        case .maternityPenalty:
            return String(localized: "妊娠・育児・介護を理由に、ちょっと冷たいムードが出てます。", bundle: LanguageManager.appBundle)
        case .academicPower:
            return String(localized: "成績・推薦・卒業の話で、上から効かせる感じが出てます。", bundle: LanguageManager.appBundle)
        }
    }
}

/// 構成要素の検出 severity
enum FactorSeverity: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var weightMultiplier: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 1.6
        case .high: return 2.4
        }
    }

    /// 1 段上げる（low→medium→high→high）
    func upgrade() -> FactorSeverity {
        switch self {
        case .low: return .medium
        case .medium: return .high
        case .high: return .high
        }
    }

    /// 1 段下げる（high→medium→low→low）
    func downgrade() -> FactorSeverity {
        switch self {
        case .high: return .medium
        case .medium: return .low
        case .low: return .low
        }
    }
}
