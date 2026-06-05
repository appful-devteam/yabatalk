import Foundation

/// トーク相手との関係性。診断前にユーザーが必須選択する。
/// docs/spec/diagnosis-logic.md §3.5 と完全に整合させる。
enum RelationshipContext: String, Codable, CaseIterable, Sendable {
    case romantic       // 恋人 / 配偶者
    case exRomantic     // 元恋人
    case family         // 親 / 子 / 兄弟 / 親戚
    case friend         // 友人 / 親友
    case bossOverMe     // 相手が上の立場（上司 / 先輩 / 教員）
    case subToMe        // 相手が下の立場（部下 / 後輩 / 生徒）
    case colleague      // 同僚（横）
    case unknown        // 指定しない（補正なし）

    var displayName: String {
        switch self {
        case .romantic:    return "恋人・配偶者"
        case .exRomantic:  return "元恋人"
        case .family:      return "家族"
        case .friend:      return "友人・親友"
        case .bossOverMe:  return "上司・先輩"
        case .subToMe:     return "部下・後輩"
        case .colleague:   return "同僚"
        case .unknown:     return "指定しない"
        }
    }

    /// UI で短く出す用
    var shortName: String {
        switch self {
        case .romantic:    return "恋人"
        case .exRomantic:  return "元恋人"
        case .family:      return "家族"
        case .friend:      return "友人"
        case .bossOverMe:  return "上司"
        case .subToMe:     return "部下"
        case .colleague:   return "同僚"
        case .unknown:     return "未指定"
        }
    }

    var emoji: String {
        switch self {
        case .romantic:    return "💞"
        case .exRomantic:  return "💔"
        case .family:      return "🏠"
        case .friend:      return "🫂"
        case .bossOverMe:  return "🎓"
        case .subToMe:     return "🪪"
        case .colleague:   return "🧑‍💼"
        case .unknown:     return "❔"
        }
    }

    /// アウトプットで「相手」を呼ぶときの一般化された主語
    var partnerNoun: String {
        switch self {
        case .romantic:    return "パートナー"
        case .exRomantic:  return "元パートナー"
        case .family:      return "ご家族"
        case .friend:      return "友達"
        case .bossOverMe:  return "上司・先輩"
        case .subToMe:     return "部下・後輩"
        case .colleague:   return "同僚"
        case .unknown:     return "相手"
        }
    }

    /// 「〜から見て」を出すための短文
    var contextLabel: String {
        switch self {
        case .romantic:    return "恋人視点"
        case .exRomantic:  return "元恋人視点"
        case .family:      return "家族視点"
        case .friend:      return "友人視点"
        case .bossOverMe:  return "上司→自分視点"
        case .subToMe:     return "部下→自分視点"
        case .colleague:   return "同僚視点"
        case .unknown:     return "関係性指定なし"
        }
    }

    // MARK: - C1/C2 Factor multiplier (spec §4.4)

    /// 関係性 × factor の multiplier。`1.0` = 中立、`0.0` = 無効化、`>1.0` = ブースト。
    func multiplier(for factor: HarassmentFactor) -> Double {
        Self.table(for: self)[factor] ?? 1.0
    }

    /// 完全に無効化される factor 集合（multiplier 0.0 と等価）
    var suppressedFactors: Set<HarassmentFactor> {
        var out: Set<HarassmentFactor> = []
        for factor in HarassmentFactor.allCases where multiplier(for: factor) <= 0.0 {
            out.insert(factor)
        }
        return out
    }

    // MARK: - C3 PriorityResolver hints

    /// このルール (§5-1 対価型セクハラ) を発火させるか
    var allowsQuotaPairingRule: Bool {
        switch self {
        case .romantic, .exRomantic, .family, .friend: return false
        case .bossOverMe, .subToMe, .colleague, .unknown: return true
        }
    }

    /// §5-1 対価型セクハラのしきい値（`quotaPairing` factor スコアの最小値）
    var quotaPairingThreshold: Int {
        switch self {
        case .bossOverMe: return 12
        default: return 18
        }
    }

    /// §5-2 パワハラルールを発火させるか
    var allowsPowerRule: Bool {
        switch self {
        case .romantic, .exRomantic, .family, .friend: return false
        case .bossOverMe, .subToMe, .colleague, .unknown: return true
        }
    }

    /// §5-2 パワハラルールのしきい値ペア (workEvaluation, dominance)
    var powerRuleThresholds: (workEvaluation: Int, dominance: Int) {
        switch self {
        case .bossOverMe: return (20, 12)
        default: return (30, 20)
        }
    }

    /// §5-3 親密関係モラハラルールで `intimateRelationship` 必須を無視するか
    /// `true` なら親密関係スコアが 0 でも罪悪感操作等の単体検出でモラハラ優先に倒れる。
    var bypassIntimacyRequirementForMoral: Bool {
        switch self {
        case .romantic, .exRomantic, .family: return true
        default: return false
        }
    }

    /// §5-3 モラハラルールの心理支配 factor 単体しきい値
    var moralRuleSingleFactorThreshold: Int {
        switch self {
        case .romantic, .exRomantic, .family: return 12
        default: return 18
        }
    }

    /// §5-4 関係性ベースのデフォルト主分類（他ルール非該当時の弱いヒント）
    var defaultCategoryHint: HarassmentCategory? {
        switch self {
        case .bossOverMe: return .power
        case .subToMe: return .other
        case .romantic, .exRomantic, .family: return .moral
        default: return nil
        }
    }

    // MARK: - C4 TypeMatcher filter

    /// このタイプを候補にしてよいか（spec §6 関係性別タイプ照合表）
    func includesType(_ type: HarassmentType) -> Bool {
        let excluded = Self.excludedTypeIDs[self] ?? []
        return !excluded.contains(type.id)
    }

    // MARK: - C5 Output tone

    /// アウトプット冒頭の関係性フレーバ（OutputBuilder.makeLogicParagraphs に挿入）
    var openingFlavor: String {
        switch self {
        case .romantic:
            return "「恋人ならこのくらい」って言葉が刃物に変わる関係です。重さの基準を恋愛モードに合わせて読みます。"
        case .exRomantic:
            return "別れたあとの残響は、現役の関係よりも一段重く響きます。脅し・束縛系は通常より強めに読みます。"
        case .family:
            return "家族の関係は逃げ場が物理的に狭いので、罪悪感操作・ガスライティング系は通常より重く効きます。"
        case .friend:
            return "友達同士のイジリは「ノリ」と「圧」の境界が曖昧。境界線越えと集団排除を中心に読みます。"
        case .bossOverMe:
            return "立場と評価をベースに会話が動くので、業務指導と人格攻撃の境界がそのまま結果に響きます。"
        case .subToMe:
            return "下から上への圧（逆パワハラ・カスハラ風）は通常の検出だと埋もれがち。集団排除・脅し系を強めに読みます。"
        case .colleague:
            return "横並び関係なので、性別役割の押し付け・お酒・グループ排除あたりが効きやすい構造です。"
        case .unknown:
            return "関係性プリオールはオフ。中立スコアで読みます。"
        }
    }

    // MARK: - Multiplier table (spec §4.4)
    //
    // 関係性ごとに [factor: multiplier] dict を分割保持する。
    // 1 つの巨大 dict 入れ子は Swift 型推論が秒単位でハングするので、
    // ここは「分割管理 → 関係性キーで lookup」の構造で固定する。

    private static func table(for context: RelationshipContext) -> [HarassmentFactor: Double] {
        switch context {
        case .romantic:    return romanticTable
        case .exRomantic:  return exRomanticTable
        case .family:      return familyTable
        case .friend:      return friendTable
        case .bossOverMe:  return bossOverMeTable
        case .subToMe:     return subToMeTable
        case .colleague:   return colleagueTable
        case .unknown:     return [:]
        }
    }

    private static let romanticTable: [HarassmentFactor: Double] = [
        .dominance: 0.7, .workEvaluation: 0.4, .sexualContext: 0.8,
        .intimateRelationship: 1.5, .personalityDenial: 1.2, .abilityDenial: 1.1,
        .existenceDenial: 1.2, .disadvantageThreat: 1.2, .excessiveDemand: 1.0,
        .refusalImpossible: 1.2, .boundaryViolation: 1.2, .persistentRepetition: 1.2,
        .guiltManipulation: 1.3, .gaslighting: 1.3, .monitoringControl: 1.4,
        .privacyIntrusion: 1.0, .groupExclusion: 0.8, .roleStereotype: 1.0,
        .quotaPairing: 0.6, .mockingLaughter: 1.1, .alcoholCoercion: 0.8,
        .customerAggression: 0.0, .maternityPenalty: 0.0, .academicPower: 0.0,
    ]

    private static let exRomanticTable: [HarassmentFactor: Double] = [
        .dominance: 0.8, .workEvaluation: 0.5, .sexualContext: 1.0,
        .intimateRelationship: 0.7, .personalityDenial: 1.3, .abilityDenial: 1.2,
        .existenceDenial: 1.3, .disadvantageThreat: 1.4, .excessiveDemand: 1.0,
        .refusalImpossible: 1.3, .boundaryViolation: 1.4, .persistentRepetition: 1.4,
        .guiltManipulation: 1.5, .gaslighting: 1.4, .monitoringControl: 1.5,
        .privacyIntrusion: 1.2, .groupExclusion: 0.9, .roleStereotype: 1.0,
        .quotaPairing: 0.8, .mockingLaughter: 1.2, .alcoholCoercion: 0.9,
        .customerAggression: 0.0, .maternityPenalty: 0.0, .academicPower: 0.0,
    ]

    private static let familyTable: [HarassmentFactor: Double] = [
        .dominance: 1.0, .workEvaluation: 0.6, .sexualContext: 1.5,
        .intimateRelationship: 0.5, .personalityDenial: 1.3, .abilityDenial: 1.2,
        .existenceDenial: 1.2, .disadvantageThreat: 1.2, .excessiveDemand: 1.0,
        .refusalImpossible: 1.1, .boundaryViolation: 1.2, .persistentRepetition: 1.1,
        .guiltManipulation: 1.4, .gaslighting: 1.3, .monitoringControl: 0.8,
        .privacyIntrusion: 1.2, .groupExclusion: 0.9, .roleStereotype: 1.1,
        .quotaPairing: 0.0, .mockingLaughter: 1.0, .alcoholCoercion: 0.8,
        .customerAggression: 0.0, .maternityPenalty: 0.7, .academicPower: 0.0,
    ]

    private static let friendTable: [HarassmentFactor: Double] = [
        .dominance: 0.6, .workEvaluation: 0.5, .sexualContext: 1.0,
        .intimateRelationship: 0.4, .personalityDenial: 1.1, .abilityDenial: 1.0,
        .existenceDenial: 1.1, .disadvantageThreat: 1.1, .excessiveDemand: 0.9,
        .refusalImpossible: 1.1, .boundaryViolation: 1.2, .persistentRepetition: 1.0,
        .guiltManipulation: 1.1, .gaslighting: 1.0, .monitoringControl: 0.7,
        .privacyIntrusion: 0.9, .groupExclusion: 1.4, .roleStereotype: 1.0,
        .quotaPairing: 0.6, .mockingLaughter: 1.3, .alcoholCoercion: 1.2,
        .customerAggression: 0.0, .maternityPenalty: 0.0, .academicPower: 0.0,
    ]

    private static let bossOverMeTable: [HarassmentFactor: Double] = [
        .dominance: 1.5, .workEvaluation: 1.5, .sexualContext: 1.2,
        .intimateRelationship: 0.3, .personalityDenial: 1.3, .abilityDenial: 1.3,
        .existenceDenial: 1.4, .disadvantageThreat: 1.5, .excessiveDemand: 1.4,
        .refusalImpossible: 1.3, .boundaryViolation: 1.2, .persistentRepetition: 1.2,
        .guiltManipulation: 1.0, .gaslighting: 1.1, .monitoringControl: 0.7,
        .privacyIntrusion: 1.3, .groupExclusion: 1.3, .roleStereotype: 1.2,
        .quotaPairing: 1.4, .mockingLaughter: 1.0, .alcoholCoercion: 1.2,
        .customerAggression: 0.0, .maternityPenalty: 1.4, .academicPower: 1.2,
    ]

    private static let subToMeTable: [HarassmentFactor: Double] = [
        .dominance: 0.7, .workEvaluation: 1.0, .sexualContext: 1.0,
        .intimateRelationship: 0.3, .personalityDenial: 1.0, .abilityDenial: 0.9,
        .existenceDenial: 1.0, .disadvantageThreat: 0.8, .excessiveDemand: 0.6,
        .refusalImpossible: 1.2, .boundaryViolation: 1.1, .persistentRepetition: 1.0,
        .guiltManipulation: 1.2, .gaslighting: 1.2, .monitoringControl: 0.7,
        .privacyIntrusion: 0.9, .groupExclusion: 1.2, .roleStereotype: 1.0,
        .quotaPairing: 1.0, .mockingLaughter: 1.2, .alcoholCoercion: 1.0,
        .customerAggression: 0.8, .maternityPenalty: 1.2, .academicPower: 0.0,
    ]

    private static let colleagueTable: [HarassmentFactor: Double] = [
        .dominance: 0.8, .workEvaluation: 1.0, .sexualContext: 1.1,
        .intimateRelationship: 0.3, .personalityDenial: 1.2, .abilityDenial: 1.0,
        .existenceDenial: 1.1, .disadvantageThreat: 1.0, .excessiveDemand: 1.0,
        .refusalImpossible: 1.0, .boundaryViolation: 1.1, .persistentRepetition: 1.0,
        .guiltManipulation: 1.0, .gaslighting: 1.0, .monitoringControl: 0.7,
        .privacyIntrusion: 1.1, .groupExclusion: 1.3, .roleStereotype: 1.0,
        .quotaPairing: 1.2, .mockingLaughter: 1.2, .alcoholCoercion: 1.2,
        .customerAggression: 0.0, .maternityPenalty: 1.0, .academicPower: 0.5,
    ]

    // MARK: - Type exclusion (spec §6)

    /// 関係性ごとに「タイプ候補から外す」HarassmentType.id 集合。
    /// 表は HarassmentTypeCatalog で定義された ID と整合させる。
    private static let excludedTypeIDs: [RelationshipContext: Set<String>] = [
        .romantic: [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "task_dumper", "place_revoker", "info_freezer",
            "customer_firebomb", "lab_king", "life_event_stomper",
            "drink_primitive", "quota_bundle_seller",
        ],
        .exRomantic: [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "task_dumper", "place_revoker", "info_freezer",
            "customer_firebomb", "lab_king", "life_event_stomper",
            "drink_primitive", "quota_bundle_seller",
        ],
        .family: [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "task_dumper", "place_revoker", "info_freezer",
            "customer_firebomb", "lab_king", "life_event_stomper",
            "quota_bundle_seller", "outfit_check_yokai",
        ],
        .friend: [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "task_dumper", "place_revoker", "quota_bundle_seller",
            "life_event_stomper", "lab_king",
        ],
        .bossOverMe: [
            "emotion_hostage", "sulk_blackhole", "restraint_overkill",
            "victim_position_lock",
        ],
        .subToMe: [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "lab_king", "life_event_stomper",
        ],
        .colleague: [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "task_dumper", "place_revoker",
            "emotion_hostage", "sulk_blackhole", "restraint_overkill",
        ],
        .unknown: [],
    ]
}
