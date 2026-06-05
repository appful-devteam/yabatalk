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
        case .dominance:            return "優位性"
        case .workEvaluation:       return "業務・評価文脈"
        case .sexualContext:        return "性的文脈"
        case .intimateRelationship: return "親密関係"
        case .personalityDenial:    return "人格否定"
        case .abilityDenial:        return "能力否定"
        case .existenceDenial:      return "存在・所属否定"
        case .disadvantageThreat:   return "不利益示唆"
        case .excessiveDemand:      return "過大要求"
        case .refusalImpossible:    return "拒否不能性"
        case .boundaryViolation:    return "境界線侵害"
        case .persistentRepetition: return "反復性・執拗性"
        case .guiltManipulation:    return "罪悪感操作"
        case .gaslighting:          return "ガスライティング"
        case .monitoringControl:    return "監視・束縛"
        case .privacyIntrusion:     return "私生活侵害"
        case .groupExclusion:       return "集団排除"
        case .roleStereotype:       return "属性・役割押し付け"
        case .quotaPairing:         return "評価と性的要求の結合"
        case .mockingLaughter:      return "「笑」での軽量化"
        case .alcoholCoercion:      return "飲酒強要"
        case .customerAggression:   return "顧客・取引先からの脅し"
        case .maternityPenalty:     return "妊娠・育児・介護への不利益示唆"
        case .academicPower:        return "学業権限の濫用"
        }
    }

    /// 闇成分ミックスの表示名（毒見 UI 用）。揺らがず固定。
    var ingredientName: String {
        switch self {
        case .dominance:            return "立場ふりかけ"
        case .workEvaluation:       return "業務指導っぽさ"
        case .sexualContext:        return "距離感バグ味"
        case .intimateRelationship: return "親密関係コーティング"
        case .personalityDenial:    return "人格削りパウダー"
        case .abilityDenial:        return "能力否定ペッパー"
        case .existenceDenial:      return "居場所はく奪エキス"
        case .disadvantageThreat:   return "不利益ちらつかせシロップ"
        case .excessiveDemand:      return "重労働シロップ"
        case .refusalImpossible:    return "逃げ道ふさぎエキス"
        case .boundaryViolation:    return "境界線ぶち破り味"
        case .persistentRepetition: return "しつこさ煮込み"
        case .guiltManipulation:    return "罪悪感の素"
        case .gaslighting:          return "記憶改ざんスパイス"
        case .monitoringControl:    return "監視・返信強要ジュース"
        case .privacyIntrusion:     return "プライベート漬け"
        case .groupExclusion:       return "仲間外し氷"
        case .roleStereotype:       return "古臭い役割タレ"
        case .quotaPairing:         return "評価との抱き合わせ"
        case .mockingLaughter:      return "笑でごまかし"
        case .alcoholCoercion:      return "飲酒強要ハイボール"
        case .customerAggression:   return "クレーマー火薬"
        case .maternityPenalty:     return "ライフイベント踏みつけ味"
        case .academicPower:        return "研究室の絶対権力"
        }
    }

    /// 毒見アウトプットの quote 解説テンプレ（占い／友達のツッコミ寄りの柔らかトーン）
    func explanationTemplate() -> String {
        switch self {
        case .personalityDenial:
            return "「やったこと」じゃなく「人としてどうなの」って言い方になりがち。"
        case .abilityDenial:
            return "「ここを直そう」じゃなく「もうムリでしょ」って丸ごとパスかも。"
        case .existenceDenial:
            return "居場所そのものを取り上げるみたいな言い方が混じってます。"
        case .disadvantageThreat:
            return "「やらないと損するよ」って匂わせがちなタイプ。"
        case .refusalImpossible:
            return "一見、選べそうで実は断りにくい言い方になってるかも。"
        case .excessiveDemand:
            return "相手の体調や時間、ちょっと無視ぎみな要求が出てます。"
        case .sexualContext:
            return "ちょっと距離感バグった、踏み込みすぎな話題かも。"
        case .quotaPairing:
            return "色恋っぽい話と評価・仕事の話がくっついちゃってます。"
        case .mockingLaughter:
            return "「笑」をつけてマイルドに見せてるけど、中身は結構強め。"
        case .guiltManipulation:
            return "「私の気持ち、あなたのせい」風の言い回しが目立ちます。"
        case .gaslighting:
            return "「そんなこと言ってない」「気のせい」で相手の感覚を上書きしがち。"
        case .monitoringControl:
            return "返信や行動の追跡みがちょっと強めかも。"
        case .intimateRelationship:
            return "愛情や関係性を条件にしたお願いが混ざってます。"
        case .boundaryViolation:
            return "「やめて」「嫌」って言われた後にも、同じノリが続いてるかも。"
        case .persistentRepetition:
            return "短時間にバババッと連投する追い打ちタイプ。"
        case .dominance:
            return "「立場が上だから」を前提にしてる圧、ちょっと出てます。"
        case .workEvaluation:
            return "評価・仕事・成績の話を持ち出して効かせるタイプかも。"
        case .privacyIntrusion:
            return "プライベート、ちょっと踏み込みすぎな質問が混ざってます。"
        case .groupExclusion:
            return "「あいつは入れない」みたいな、ハブり寄りの言い方かも。"
        case .roleStereotype:
            return "「女だから」「男なら」みたいな、役割押しつけが入ってます。"
        case .alcoholCoercion:
            return "「飲もうよ」「飲まないの？」が、ちょっと強引めかも。"
        case .customerAggression:
            return "客・取引先の立場で押してくる、強気めな出方。"
        case .maternityPenalty:
            return "妊娠・育児・介護を理由に、ちょっと冷たいムードが出てます。"
        case .academicPower:
            return "成績・推薦・卒業の話で、上から効かせる感じが出てます。"
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
