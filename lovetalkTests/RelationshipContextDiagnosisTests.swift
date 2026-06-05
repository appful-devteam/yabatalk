import Foundation
import Testing
@testable import yabatalk

/// 関係性プリオール (spec §3.5) が診断ロジックを実際にずらすかの回帰テスト。
/// `RelationshipContext` を `.unknown` から特定の関係性に変えたとき、
/// factor / category / type / 文言が想定方向に変わることを検証する。
@Suite("関係性プリオール — diagnosis")
struct RelationshipContextDiagnosisTests {

    // MARK: - Helpers

    /// 簡易セッションを作る。messages は (sender, content, hour) の配列で渡す。
    private func makeSession(
        title: String = "test",
        participants: [String],
        messages: [(sender: String, content: String, hour: Int)],
        relationship: RelationshipContext?
    ) -> ChatSession {
        let base = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        let chatMessages: [ChatMessage] = messages.enumerated().map { (i, m) in
            let ts = Calendar.current.date(
                bySettingHour: m.hour, minute: 0, second: i % 60, of: base
            ) ?? base
            return ChatMessage(
                timestamp: ts,
                senderName: m.sender,
                content: m.content,
                eventType: .text
            )
        }
        let chatParticipants = participants.map { name -> ChatParticipant in
            let count = messages.filter { $0.sender == name }.count
            return ChatParticipant(
                name: name,
                messageCount: count,
                textMessageCount: count
            )
        }
        return ChatSession(
            title: title,
            messages: chatMessages,
            participants: chatParticipants,
            estimatedSelfName: participants.last,
            relationship: relationship
        )
    }

    // MARK: - C1: factor multiplier 効果

    @Test("既読責めは恋人で重く、友人で軽くなる")
    func monitoringControlScalesByRelationship() {
        let template: [(sender: String, content: String, hour: Int)] = [
            ("相手", "なんで返さないの", 22),
            ("自分", "ごめん、寝てた", 23),
            ("相手", "既読つけたよね", 23),
            ("相手", "無視するの？", 23),
            ("相手", "返事まだ？", 23),
            ("自分", "明日また話そう", 23),
            ("相手", "オンラインだったでしょ", 0),
            ("相手", "なんで無視するの", 0),
            ("自分", "ちょっと寝かせて", 0),
            ("相手", "出るまで電話するから", 1),
        ]
        let romantic = makeSession(participants: ["相手", "自分"], messages: template, relationship: .romantic)
        let friend = makeSession(participants: ["相手", "自分"], messages: template, relationship: .friend)
        let unknown = makeSession(participants: ["相手", "自分"], messages: template, relationship: .unknown)

        let usecase = DiagnoseHarassmentUseCase()
        let rRomantic = usecase.execute(session: romantic)
        let rFriend = usecase.execute(session: friend)
        let rUnknown = usecase.execute(session: unknown)

        let mc: (DiagnosisResult) -> Int = { result in
            result.factorScores.first { $0.factor == .monitoringControl }?.score ?? 0
        }
        // 恋人 > unknown > 友人 の順で monitoringControl が出るはず
        #expect(mc(rRomantic) > mc(rUnknown), "恋人は監視 factor が ×1.4 で強くなる")
        #expect(mc(rUnknown) > mc(rFriend), "友人は ×0.7 で弱くなる")
    }

    // MARK: - C2: factor 完全無効化

    @Test("恋人関係では maternityPenalty が完全に消える")
    func maternityFactorSuppressedInRomantic() {
        let messages: [(sender: String, content: String, hour: Int)] = [
            ("相手", "妊娠したら辞めてもらうしかないかな", 12),
            ("相手", "育休取るなら評価は期待しないで", 13),
            ("自分", "それはちょっと", 13),
            ("相手", "妊娠.{0,5}辞めたら？", 14),
        ]
        // bossOverMe (有効) vs romantic (無効化) で同じ文言を投入
        let romantic = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .romantic)
        let boss = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .bossOverMe)

        let usecase = DiagnoseHarassmentUseCase()
        let rRomantic = usecase.execute(session: romantic)
        let rBoss = usecase.execute(session: boss)

        let mat: (DiagnosisResult) -> Int = { r in
            r.factorScores.first { $0.factor == .maternityPenalty }?.score ?? 0
        }
        #expect(mat(rRomantic) == 0, "恋人では maternityPenalty multiplier 0.0 で完全に消える")
        #expect(mat(rBoss) > 0, "bossOverMe では検出される")
    }

    // MARK: - C3: priority ルール変動

    @Test("bossOverMe では業務文脈しきい値が緩和されパワハラ優先になる")
    func bossOverMeLowersPowerThreshold() {
        let messages: [(sender: String, content: String, hour: Int)] = [
            ("相手", "評価考えるよ", 10),
            ("相手", "次やったら終わりだから", 10),
            ("相手", "上司として言うけど、新人のくせに何様", 11),
            ("相手", "クビにするしかないかな", 11),
            ("自分", "ちょっと待ってください", 11),
            ("相手", "断るなら評価考える", 14),
            ("相手", "シフト切るしかない", 15),
            ("相手", "本当に使えない", 15),
        ]
        let boss = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .bossOverMe)
        let unknown = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .unknown)

        let usecase = DiagnoseHarassmentUseCase()
        let rBoss = usecase.execute(session: boss)
        let rUnknown = usecase.execute(session: unknown)

        #expect(rBoss.primaryCategory == .power, "bossOverMe ではパワハラ優先になる")
        #expect(rBoss.overallRiskScore >= rUnknown.overallRiskScore,
                "bossOverMe で multiplier ブースト後はスコアが下がらないはず")
    }

    @Test("恋人関係では intimateRelationship なしでも罪悪感単体でモラハラ優先")
    func romanticTriggersMoralOnGuiltAlone() {
        let messages: [(sender: String, content: String, hour: Int)] = [
            ("相手", "俺がこんなにしてるのに", 20),
            ("相手", "全部そっちのせい", 20),
            ("相手", "謝っても無駄", 21),
            ("相手", "泣きたいのはこっち", 21),
            ("相手", "俺ばっかり我慢してる", 22),
            ("自分", "ごめん", 22),
            ("相手", "ごめんで済む話じゃない", 22),
            ("相手", "信用できない", 22),
        ]
        let romantic = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .romantic)

        let usecase = DiagnoseHarassmentUseCase()
        let result = usecase.execute(session: romantic)
        #expect(result.primaryCategory == .moral, "恋人 × guiltManipulation 単体でモラハラ優先（intimate 必須撤廃）")
    }

    // MARK: - C4: type filter

    @Test("友人関係では上司ドラゴン型は候補から除外される")
    func friendExcludesBossTypes() {
        let messages: [(sender: String, content: String, hour: Int)] = [
            ("相手", "なんでこんなこともできないの", 12),
            ("相手", "本当に使えない", 12),
            ("相手", "立場わかってる？", 13),
        ]
        let friend = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .friend)
        let usecase = DiagnoseHarassmentUseCase()
        let result = usecase.execute(session: friend)
        // primaryType.id が boss_dragon / indoctrination_devil / rank_swinger 等にならない
        let excluded: Set<String> = [
            "boss_dragon", "indoctrination_devil", "rank_swinger",
            "task_dumper", "place_revoker", "info_freezer",
        ]
        #expect(!excluded.contains(result.primaryType.id),
                "友人関係では上司系タイプは候補プールから外れる (実際: \(result.primaryType.id))")
    }

    // MARK: - C5: 文言ローカライズ

    @Test("関係性指定ありの結果には partnerNoun が反映される")
    func outputUsesRelationshipNoun() {
        let messages: [(sender: String, content: String, hour: Int)] = [
            ("相手", "本当に使えないやつだな", 10),
            ("相手", "評価考えるしかない", 11),
            ("相手", "上司として言うけどクビにするしかない", 11),
            ("自分", "改善します", 12),
        ]
        let boss = makeSession(participants: ["相手", "自分"], messages: messages, relationship: .bossOverMe)
        let usecase = DiagnoseHarassmentUseCase()
        let result = usecase.execute(session: boss)
        // OutputBuilder の logicParagraphs P1 に partnerNoun が入る
        let bodyText = result.logicParagraphs.joined(separator: "\n")
        #expect(bodyText.contains("上司・先輩") || bodyText.contains("上司"),
                "関係性 noun (上司・先輩) が出力本文に含まれる")
    }

    @Test("関係性 unknown では openingFlavor が出ない")
    func unknownDoesNotInjectOpening() {
        let messages: [(sender: String, content: String, hour: Int)] = [
            ("相手", "本当に使えない", 10),
        ]
        let unknown = makeSession(participants: ["相手", "自分"], messages: messages, relationship: nil)
        let usecase = DiagnoseHarassmentUseCase()
        let result = usecase.execute(session: unknown)
        let first = result.logicParagraphs.first ?? ""
        #expect(!first.contains("前提で読みます"), "unknown 時は『〜前提で読みます』の P0 が出ないこと")
    }

    // MARK: - 多 multiplier の整合性

    @Test("multiplier 表は 1.0 が中立で全関係性に存在する")
    func multiplierTableHasAllRelationshipsForAllFactors() {
        for relationship in RelationshipContext.allCases {
            for factor in HarassmentFactor.allCases {
                let m = relationship.multiplier(for: factor)
                #expect(m >= 0.0 && m <= 2.0,
                        "factor=\(factor) relationship=\(relationship) multiplier=\(m) が許容範囲 [0, 2] 外")
            }
        }
    }

    @Test("unknown は全 factor で multiplier 1.0")
    func unknownIsNeutral() {
        for factor in HarassmentFactor.allCases {
            #expect(RelationshipContext.unknown.multiplier(for: factor) == 1.0,
                    "unknown は中立であるべき (factor=\(factor))")
        }
    }
}
