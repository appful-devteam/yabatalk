import Foundation

/// 構成要素検出のためのルール辞書
/// docs/spec/diagnosis-logic.md §1 / §3 と整合。仕様変更時は spec.md を先に更新する。
struct FactorRule: Sendable {
    let factor: HarassmentFactor
    let pattern: String                  // NSRegularExpression パターン
    let severity: FactorSeverity
    let baseWeight: Int                  // factor score への寄与値
    /// 周辺にあれば検出を **無効化**（モノ向けの否定 / 3人称への愚痴を除外）
    let suppressIfNearby: [String]
    /// 周辺に必須のパターン。なければ破棄。
    let requireAnyNearby: [String]
    /// 周辺にあれば severity を **1 段下げる**（「ごめん、やめるね」のような柔らかい同居）
    let softenIfNearby: [String]
    /// 周辺にあれば severity を **1 段上げる**（「お前は使えない」のような 2人称明示）
    let amplifyIfNearby: [String]
    let note: String

    init(
        _ factor: HarassmentFactor,
        _ pattern: String,
        _ severity: FactorSeverity,
        _ baseWeight: Int,
        suppressIfNearby: [String] = [],
        requireAnyNearby: [String] = [],
        softenIfNearby: [String] = [],
        amplifyIfNearby: [String] = [],
        note: String = ""
    ) {
        self.factor = factor
        self.pattern = pattern
        self.severity = severity
        self.baseWeight = baseWeight
        self.suppressIfNearby = suppressIfNearby
        self.requireAnyNearby = requireAnyNearby
        self.softenIfNearby = softenIfNearby
        self.amplifyIfNearby = amplifyIfNearby
        self.note = note
    }
}

/// false-positive 抑制用の語彙辞書（モノ・場所・身体パーツ・状態語など）
enum SubjectMarkers {
    /// 「使えない / 悪い / ダメ」等の評価語が **モノ・状態** に向いている場合、個人攻撃ではないので suppress 対象。
    static let objectAndState: [String] = [
        // デジタル系
        "アプリ", "ソフト", "サイト", "システム", "PC", "パソコン", "スマホ",
        "Wi-?Fi", "WiFi", "電池", "バッテリー", "充電", "電源", "電波",
        "Mac", "Windows", "iPhone", "iPad", "Android",
        "アカウント", "カード", "鍵", "コード", "URL", "リンク",
        "Bluetooth", "イヤホン", "AirPods",
        // 店・モノ・場所
        "店", "クーポン", "ポイント", "車", "電車", "バス", "傘",
        "服", "靴", "鍋", "皿", "ペン", "シャワー", "風呂", "トイレ",
        "冷蔵庫", "エアコン", "テレビ", "洗濯機", "コンビニ",
        "クレカ", "電子マネー", "PayPay", "Suica",
        // 身体・状態
        "頭", "腰", "足", "目", "口", "脳", "腕", "肩", "肌", "歯", "胃",
        "体力", "気力", "集中力", "やる気", "記憶",
        // 副詞・時間
        "今日", "もう", "今", "最近", "ここ最近", "本当に何も",
        // 抽象
        "アイデア", "案", "方法", "やり方"
    ]

    /// 攻撃が「人 (相手)」に向いていることを示す二人称マーカー（必須化用 / amplify 用）
    static let secondPerson: [String] = [
        "お前", "おまえ", "あなた", "あんた", "君", "きみ",
        "テメー", "貴様", "おたく",
        "お前ら", "おまえら", "君たち", "きみたち",
        "そっち"
    ]

    /// 発言が **第三者** について話していることを示すマーカー（個人攻撃→suppress 対象）。
    /// 「あの上司マジ使えない」「うちの教授バカ」「客がうざい」のような愚痴を、相手への攻撃と誤検出しないため。
    static let thirdPerson: [String] = [
        "あの", "うちの", "あいつ", "そいつ", "こいつ",
        "うちの(母|父|親|兄|姉|妹|弟|犬|猫|子|長男|長女|旦那|嫁|嫁さん)",
        "(会社|店|職場|学校|大学|ゼミ|サークル|部活).{0,4}(の|で|から)",
        "(上司|先輩|後輩|店長|店員|客|お客|教授|先生|教員|親|親父|母親|嫁|旦那|彼氏|彼女|元彼|元カノ|友達|友人).{0,2}(が|は|の|って|で)",
        "うちのコ", "あの子", "あの人", "あの人達", "誰か", "あの店",
        "兄貴", "姉ちゃん"
    ]

    /// 柔らかい着地語（「ごめん、やめるね」「ちゃんと話そう」等）。
    /// 同じメッセージや周辺にあれば、近接するヤバ要素の severity を 1 段下げる。
    static let softMarkers: [String] = [
        "ごめん", "ごめんね", "ごめんなさい",
        "嫌だったらごめん", "嫌だったならごめん",
        "無理しないで", "無理ならいいよ", "無理せず",
        "わかった、(今度|次)", "今度から気をつける",
        "落ち着いてから話", "落ち着いてから", "ちゃんと話そう", "ちゃんと話したい",
        "傷つけるつもりはなかった", "嫌だったなら教えて",
        "どうしたらよかった", "どうしたら良かった",
        "ありがとう", "ありがと", "助かった", "嬉しかった"
    ]

    /// 「相手に直接向けている」推定マーカー（2人称 + 「君は」「お前って」等）。
    /// 近接で severity を 1 段上げる。
    static let directAddress: [String] = [
        "お前(は|って|に|の)", "おまえ(は|って|に|の)",
        "あなた(は|って|に|の)",
        "あんた(は|って|に|の)",
        "君(は|って|に|の)", "きみ(は|って|に|の)",
        "テメー", "そっち(は|って|の)"
    ]
}

enum FactorRuleDictionary {
    /// 静的ルール一覧（プレーンテキスト regex）
    static let rules: [FactorRule] = [
        // MARK: - 人格否定（subject 検証あり: モノ向けの否定は除外）
        FactorRule(.personalityDenial, "使えない", .high, 22,
                   suppressIfNearby: SubjectMarkers.objectAndState,
                   note: "存在価値否定。アプリ/電池/頭等への否定は除外"),
        FactorRule(.personalityDenial, "ゴミ", .high, 25,
                   suppressIfNearby: ["分別", "回収", "出した", "捨て", "燃え", "袋", "箱"]),
        FactorRule(.personalityDenial, "クズ", .high, 25,
                   suppressIfNearby: ["紙クズ", "野菜クズ", "残り"]),
        FactorRule(.personalityDenial, "価値ない", .high, 25,
                   suppressIfNearby: ["商品", "株", "投資", "中古", "古い.{0,4}本"]),
        FactorRule(.personalityDenial, "普通じゃない", .medium, 14),
        FactorRule(.personalityDenial, "本当に(無理|だめ|ダメ)", .medium, 14,
                   suppressIfNearby: ["この問題", "今日", "今週", "間に合", "終わり", "眠"]),
        FactorRule(.personalityDenial, "性格(悪い|終わってる)", .high, 22),

        // MARK: - 能力否定（モノ・状態に対する否定は除外）
        FactorRule(.abilityDenial, "こんなこともできない", .high, 20,
                   suppressIfNearby: SubjectMarkers.objectAndState),
        FactorRule(.abilityDenial, "頭(悪い|わるい)", .high, 20,
                   suppressIfNearby: ["天気", "今日", "予報", "気圧"]),
        FactorRule(.abilityDenial, "バカ", .medium, 10,
                   suppressIfNearby: ["親バカ", "馬鹿正直", "バカ高", "バカ売れ", "バカうま", "バカでか"]),
        FactorRule(.abilityDenial, "アホ", .medium, 10,
                   suppressIfNearby: ["阿呆陀羅", "アホみたい.{0,5}(うま|可愛|多|たくさん)"]),
        FactorRule(.abilityDenial, "無能", .high, 22),
        FactorRule(.abilityDenial, "(まじで|本当に)使えない", .high, 25,
                   suppressIfNearby: SubjectMarkers.objectAndState),

        // MARK: - 存在・所属否定
        FactorRule(.existenceDenial, "来なくていい", .high, 26),
        FactorRule(.existenceDenial, "もう来ないで", .high, 26),
        FactorRule(.existenceDenial, "消えろ", .high, 30),
        FactorRule(.existenceDenial, "(お前|あんた)(いら|要ら)ない", .high, 26),
        FactorRule(.existenceDenial, "辞めれば", .medium, 16),
        FactorRule(.existenceDenial, "クビ", .high, 25),

        // MARK: - 不利益示唆
        FactorRule(.disadvantageThreat, "クビ", .high, 24,
                   suppressIfNearby: ["クビレ", "首輪", "首が", "首だけ"]),
        FactorRule(.disadvantageThreat, "評価下げる", .high, 26),
        FactorRule(.disadvantageThreat, "評価(ちょっと)?考え", .high, 24),
        FactorRule(.disadvantageThreat, "シフト(減らす|切る)", .high, 25),
        FactorRule(.disadvantageThreat, "晒す", .high, 30,
                   suppressIfNearby: ["雨", "日に晒", "風に晒", "光に晒", "ネタばれ", "目に晒"]),
        FactorRule(.disadvantageThreat, "ばらまく", .high, 30,
                   suppressIfNearby: ["お金ばらまく", "種", "肥料"]),
        FactorRule(.disadvantageThreat, "スクショ", .medium, 16,
                   suppressIfNearby: ["送って", "して送", "ありがとう", "保存して"]),
        FactorRule(.disadvantageThreat, "推薦(書)?(は)?書かない", .high, 26),
        FactorRule(.disadvantageThreat, "卒業させない", .high, 26),
        FactorRule(.disadvantageThreat, "別れる(から|ぞ|よ)", .medium, 15),
        FactorRule(.disadvantageThreat, "(育休|産休).{0,8}(期待|評価|出世|難しい)", .high, 24),
        FactorRule(.disadvantageThreat, "(辞|やめ)てもらう", .high, 22),

        // MARK: - 性的文脈（旅行・サービス名・身体検査等は除外）
        FactorRule(.sexualContext, "ホテル", .high, 25,
                   suppressIfNearby: ["朝食", "ロビー", "予約", "出張", "シティ", "ニューオータニ", "リッツ", "プリンス", "東横", "東急", "コンフォート", "アパ", "ルートイン", "民泊", "ビジネス", "宿泊"]),
        FactorRule(.sexualContext, "色気", .medium, 15,
                   suppressIfNearby: ["景色", "風景", "アニメ", "漫画", "キャラ", "演技", "映画", "ドラマ", "色気のある.{0,4}(料理|食|味|店|曲|歌|声|顔(?!.{0,3}(見|見せ)))"]),
        FactorRule(.sexualContext, "胸", .medium, 14,
                   suppressIfNearby: ["胸ポケット", "胸ぐら", "胸の中", "ぐっと胸", "胸を打", "胸を張", "胸キュン", "胸熱", "胸糞", "度胸", "胸騒ぎ", "胸を痛", "胸が熱"]),
        FactorRule(.sexualContext, "身体", .low, 8,
                   suppressIfNearby: ["身体検査", "身体測定", "身体能力", "身体障害", "健康", "保健", "病院", "ジム", "鍛え", "身体的", "身体つき(?!.{0,4}(見|なめ|エ|セク))", "身体を冷"]),
        FactorRule(.sexualContext, "(セクシー|エロ)", .high, 20,
                   suppressIfNearby: ["エロイ.{0,4}難", "エロ要素なし", "エロ漫画.{0,5}話", "エロくない", "エロじゃない", "エロい話じゃ", "セクシー(?!.{0,4}(服|下着|写真|姿|画像))"]),
        FactorRule(.sexualContext, "(2人|ふたり|二人)(きり|だけ)?で(飲|食事|会|遊)", .medium, 16),
        FactorRule(.sexualContext, "ふたりきり", .medium, 16),
        FactorRule(.sexualContext, "彼氏(いる|いた)", .low, 6),
        FactorRule(.sexualContext, "(処女|童貞|経験人数)", .high, 25),
        FactorRule(.sexualContext, "服(似合|可愛|エロ|きわどい)", .medium, 14),
        FactorRule(.sexualContext, "添い寝", .high, 22),

        // MARK: - 業務・評価文脈
        FactorRule(.workEvaluation, "評価", .medium, 14),
        FactorRule(.workEvaluation, "シフト", .medium, 12),
        FactorRule(.workEvaluation, "案件", .low, 10),
        FactorRule(.workEvaluation, "成績", .medium, 12),
        FactorRule(.workEvaluation, "推薦", .medium, 14),
        FactorRule(.workEvaluation, "卒業", .low, 10),
        FactorRule(.workEvaluation, "(上司|先輩|先生|教授|店長)", .medium, 10),
        FactorRule(.workEvaluation, "(仕事|業務|職場)", .low, 6),

        // MARK: - 過大要求
        FactorRule(.excessiveDemand, "今日中", .medium, 14),
        FactorRule(.excessiveDemand, "今すぐ", .medium, 12),
        FactorRule(.excessiveDemand, "休日(も|に|でも)?(対応|出勤|来)", .high, 18),
        FactorRule(.excessiveDemand, "深夜(まで|に|でも)", .medium, 14),
        FactorRule(.excessiveDemand, "徹夜", .medium, 15),
        FactorRule(.excessiveDemand, "(体調|熱|病気).{0,8}(関係|でも|無視|出て)", .high, 18),
        FactorRule(.excessiveDemand, "明日(まで|までに).{0,10}(全|完)", .medium, 14),

        // MARK: - 拒否不能性
        FactorRule(.refusalImpossible, "断るな", .high, 25),
        FactorRule(.refusalImpossible, "嫌なら(辞|帰|や)", .high, 25),
        FactorRule(.refusalImpossible, "好きなら.{0,6}できる", .high, 25),
        FactorRule(.refusalImpossible, "できないなら", .medium, 14),
        FactorRule(.refusalImpossible, "拒否(権|する)", .high, 20),
        FactorRule(.refusalImpossible, "選択肢ない", .medium, 14),

        // MARK: - 罪悪感操作（自分の素直な感情報告を誤判定しないよう、二人称含意を必須に）
        FactorRule(.guiltManipulation, "俺がこんなに", .high, 22),
        FactorRule(.guiltManipulation, "私がこんなに", .high, 22),
        FactorRule(.guiltManipulation, "(君|お前|あなた|きみ)のせい", .high, 22),
        FactorRule(.guiltManipulation, "責任(を)?取って", .high, 22,
                   suppressIfNearby: ["仕事.{0,4}責任", "自分.{0,4}責任", "問題.{0,4}責任", "ミス.{0,4}責任"]),
        FactorRule(.guiltManipulation, "(君|お前|あなた|きみ).{0,8}不安にさせ", .medium, 16),
        FactorRule(.guiltManipulation, "(君|お前|あなた|きみ).{0,8}傷つけ(られ|た)", .medium, 14),
        FactorRule(.guiltManipulation, "(俺|私)はこんなに(尽くし|頑張)", .high, 22),

        // MARK: - ガスライティング
        FactorRule(.gaslighting, "勘違い", .high, 20,
                   suppressIfNearby: ["時間", "予約", "メニュー", "店", "場所", "住所", "日付", "曜日"]),
        FactorRule(.gaslighting, "被害妄想", .high, 24),
        FactorRule(.gaslighting, "そんなこと言ってない", .medium, 16),
        FactorRule(.gaslighting, "覚えてない", .low, 8,
                   suppressIfNearby: ["パスワード", "暗証番号", "予約", "名前", "曲名", "ドラマ"]),
        FactorRule(.gaslighting, "(考えすぎ|気にしすぎ)", .medium, 14),
        FactorRule(.gaslighting, "誰もそんなこと", .medium, 14),

        // MARK: - 監視・束縛
        FactorRule(.monitoringControl, "今どこ", .high, 18),
        FactorRule(.monitoringControl, "誰といる", .high, 18),
        FactorRule(.monitoringControl, "写真送って", .medium, 14),
        FactorRule(.monitoringControl, "既読(.{0,6})?なんで", .high, 22),
        FactorRule(.monitoringControl, "既読ついてる", .medium, 16),
        FactorRule(.monitoringControl, "位置情報", .high, 18),
        FactorRule(.monitoringControl, "返信遅(い|くない)", .medium, 14),
        FactorRule(.monitoringControl, "何で返さない", .high, 20),

        // MARK: - 親密関係（substring 誤検出を強力に抑制）
        FactorRule(.intimateRelationship, "好きなら", .medium, 14),
        FactorRule(.intimateRelationship, "本当に(俺|私)のこと", .medium, 14),
        FactorRule(.intimateRelationship, "(彼女|彼氏)", .low, 4,
                   suppressIfNearby: ["元彼女", "元彼氏", "彼女(が|は|の|って|に|も|と|から|なんだ|っぽ)", "彼氏(が|は|の|って|に|も|と|から|なんだ|っぽ)", "ドラマ", "アニメ", "漫画", "小説", "映画", "曲", "歌詞"]),
        FactorRule(.intimateRelationship, "付き合って", .low, 4,
                   suppressIfNearby: ["買い物.{0,3}付き合", "今日.{0,3}付き合", "ちょっと付き合", "見るのに付き合", "勉強.{0,3}付き合", "練習.{0,3}付き合"]),
        FactorRule(.intimateRelationship, "(妻|夫|旦那|嫁)", .low, 4,
                   suppressIfNearby: ["大丈夫", "丈夫", "工夫", "夫婦", "夫妻", "夫人", "農夫", "漁夫", "凡夫", "亭主", "花嫁", "許嫁", "新妻", "稲妻", "妻子", "人妻", "夫々", "夫子"]),
        FactorRule(.intimateRelationship, "(愛してる|愛情)", .low, 4,
                   suppressIfNearby: ["ドラマ", "アニメ", "漫画", "小説", "映画", "曲", "歌詞", "って曲", "って歌", "ペット.{0,3}愛情", "家族.{0,3}愛情", "親.{0,3}愛情", "犬.{0,3}愛情", "猫.{0,3}愛情"]),

        // MARK: - 優位性
        FactorRule(.dominance, "上司として", .high, 18),
        FactorRule(.dominance, "先輩として", .medium, 14),
        FactorRule(.dominance, "(部下|新人|後輩)のくせに", .high, 20),
        FactorRule(.dominance, "新人(の|なんだから)", .medium, 14),
        FactorRule(.dominance, "何様", .medium, 14),
        FactorRule(.dominance, "立場(わかって|考え)", .medium, 14),
        FactorRule(.dominance, "(教えて|やって)(あげ|あげた)", .low, 6),

        // MARK: - 集団排除
        FactorRule(.groupExclusion, "無視(でいい|していい|してて)", .high, 22),
        FactorRule(.groupExclusion, "(共有|連絡)外", .medium, 16),
        FactorRule(.groupExclusion, "仲間外れ", .high, 22),
        FactorRule(.groupExclusion, "あいつ(は|だけ).{0,8}(抜|外|無視)", .high, 20),
        FactorRule(.groupExclusion, "グループ.{0,6}晒", .high, 24),

        // MARK: - 私生活侵害
        FactorRule(.privacyIntrusion, "住所", .high, 16,
                   suppressIfNearby: ["変更", "登録", "宛先", "宅配", "ふるさと", "Amazon", "Mercari", "メルカリ"]),
        FactorRule(.privacyIntrusion, "家どこ", .high, 16),
        FactorRule(.privacyIntrusion, "実家", .medium, 8,
                   suppressIfNearby: ["の犬", "の猫", "の母", "の父", "に帰", "の野菜", "の米"]),
        FactorRule(.privacyIntrusion, "(休日|休み)(何|なに)してた", .medium, 12),
        FactorRule(.privacyIntrusion, "家族(構成|の話|について)", .medium, 10),

        // MARK: - 属性押し付け
        FactorRule(.roleStereotype, "女(なん|だから)", .high, 20),
        FactorRule(.roleStereotype, "男のくせに", .high, 20),
        FactorRule(.roleStereotype, "女(らしく|の子なんだから)", .high, 18),
        FactorRule(.roleStereotype, "男(らしく|なら)", .high, 18),
        FactorRule(.roleStereotype, "妊娠.{0,5}(辞|やめ)", .high, 25),
        FactorRule(.roleStereotype, "育休(取るなら|取ったら)", .high, 22),
        FactorRule(.roleStereotype, "結婚.{0,4}(まだ|の予定)", .medium, 12),

        // MARK: - 「笑」での軽量化
        FactorRule(.mockingLaughter, "(評価|不利益|シフト|別れ).{0,12}(笑|w|ｗ|草)", .high, 20, note: "圧 + 笑 セット"),
        FactorRule(.mockingLaughter, "(冗談|ジョーク).{0,8}(だよ|だから)", .medium, 12,
                   suppressIfNearby: ["友達.{0,4}冗談", "兄弟.{0,4}冗談", "ただの冗談だよね", "冗談だよね？", "それ冗談", "冗談.{0,4}通じ"]),

        // MARK: - 評価と性的要求の結合（複合 factor）
        FactorRule(.quotaPairing, "(2人|ふたり|二人).{0,8}(評価|推薦|シフト|案件|成績)", .high, 28),
        FactorRule(.quotaPairing, "(飲|食事|ホテル).{0,10}(評価|推薦|シフト|案件|成績)", .high, 30),
        FactorRule(.quotaPairing, "(断るなら|嫌なら).{0,8}(評価|推薦|シフト)", .high, 28),

        // MARK: - アルハラ
        FactorRule(.alcoholCoercion, "一杯(くらい|だけ)?(飲|の)", .medium, 16),
        FactorRule(.alcoholCoercion, "飲めない.{0,6}(失礼|つまらない|ノリ悪)", .high, 22),
        FactorRule(.alcoholCoercion, "イッキ", .high, 22),

        // MARK: - カスハラ
        FactorRule(.customerAggression, "(SNS|Twitter|X|Google).{0,8}(晒|書|レビュー)", .high, 24),
        FactorRule(.customerAggression, "(店長|本社|本部).{0,6}(出せ|呼べ|電話)", .high, 22),
        FactorRule(.customerAggression, "(土下座|誠意)", .high, 22),
        FactorRule(.customerAggression, "(訴える|告訴)", .high, 22),

        // MARK: - マタハラ
        FactorRule(.maternityPenalty, "妊娠.{0,8}(辞|やめ|期待しない|出世|評価)", .high, 26),
        FactorRule(.maternityPenalty, "育児.{0,6}(言い訳|甘え|理由にする)", .high, 22),
        FactorRule(.maternityPenalty, "介護.{0,6}(辞|やめ|難しい)", .high, 22),
        FactorRule(.maternityPenalty, "(産休|育休).{0,8}(評価|期待|出世)", .high, 22),

        // MARK: - アカハラ
        FactorRule(.academicPower, "(推薦書|推薦状).{0,4}書かない", .high, 28),
        FactorRule(.academicPower, "(教授|指導教員|ゼミ).{0,6}(従|逆らう|気に入)", .high, 24),
        FactorRule(.academicPower, "(卒業|単位).{0,6}(させない|落とす|あげない)", .high, 26),

        // ============================================================
        // MARK: - 友達/カップル LINE 用 追加ルール群
        // ユーザー提示の判断ルール 14 カテゴリ準拠
        // ============================================================

        // --- 1. 拒否後の継続 / 冗談シールド ---
        FactorRule(.refusalImpossible, "ノリ悪い", .high, 22),
        FactorRule(.refusalImpossible, "逃げるな", .high, 22),
        FactorRule(.refusalImpossible, "本気にすんな", .medium, 16),
        FactorRule(.refusalImpossible, "本当は嬉しいくせに", .high, 22),
        FactorRule(.refusalImpossible, "そういうとこ(めんどい|めんどう|うざい)", .high, 22),
        FactorRule(.refusalImpossible, "なんで無理なの", .medium, 16),
        FactorRule(.refusalImpossible, "今すぐ返して", .high, 20),
        FactorRule(.refusalImpossible, "友達なら(普通)?やる", .high, 22),
        FactorRule(.refusalImpossible, "好きならできる", .high, 24),

        FactorRule(.mockingLaughter, "冗談じゃん", .high, 18),
        FactorRule(.mockingLaughter, "冗談だよ", .medium, 12),
        FactorRule(.mockingLaughter, "いじりじゃん", .medium, 14),
        FactorRule(.mockingLaughter, "空気読めない", .medium, 14),
        FactorRule(.mockingLaughter, "傷つく方がおかしい", .high, 24),
        FactorRule(.mockingLaughter, "このくらいで怒る", .high, 22),
        FactorRule(.mockingLaughter, "みんな笑ってた", .medium, 14),

        // --- 2. 愛情・友情の条件化 ---
        FactorRule(.intimateRelationship, "本当に好きなら", .high, 22),
        FactorRule(.intimateRelationship, "好きなら(普通)?(でき|する|来|返)", .high, 24),
        FactorRule(.intimateRelationship, "返信できないなら好き", .high, 24),
        FactorRule(.intimateRelationship, "(俺|私)のこと(大事|大切)なら", .high, 22),
        FactorRule(.intimateRelationship, "友達なら(普通|わかる|来)", .medium, 16),
        FactorRule(.intimateRelationship, "親友なら(わかって|わかる)", .medium, 16),
        FactorRule(.intimateRelationship, "できないなら友達じゃない", .high, 26),
        FactorRule(.intimateRelationship, "(俺|私)を優先(でき|して)", .high, 22),

        // --- 3. 返信強要・既読監視（軽 → 中 → 重 階層化） ---
        FactorRule(.monitoringControl, "返信遅(い|くない)\\?", .low, 8),
        FactorRule(.monitoringControl, "見たら返", .low, 6),
        FactorRule(.monitoringControl, "あとで返して", .low, 4),
        FactorRule(.monitoringControl, "オンラインだった", .high, 18),
        FactorRule(.monitoringControl, "出るまで電話", .high, 24),
        FactorRule(.monitoringControl, "ブロックしたら許さ", .high, 26),
        FactorRule(.monitoringControl, "見てるの知ってる", .high, 18),

        // --- 4. 監視・証拠要求 ---
        FactorRule(.monitoringControl, "証拠見せて", .high, 22),
        FactorRule(.monitoringControl, "スクショ送って", .medium, 12,
                   softenIfNearby: ["ありがとう", "助かる"]),
        FactorRule(.monitoringControl, "通話つけっぱ", .high, 22),
        FactorRule(.monitoringControl, "本当にそこにいる", .high, 22),
        FactorRule(.monitoringControl, "(男|女)いる\\?", .high, 22),
        FactorRule(.monitoringControl, "送れないなら(怪しい|嘘)", .high, 24),
        FactorRule(.monitoringControl, "隠してることある", .high, 20),

        // --- 5. 嫉妬・束縛 ---
        FactorRule(.monitoringControl, "(男|女)と(話|DM|連絡)(すんな|しないで|するな)", .high, 26),
        FactorRule(.monitoringControl, "その友達と会わないで", .high, 22),
        FactorRule(.monitoringControl, "(飲み会|合コン).{0,6}(行くなら|行ったら)別れ", .high, 28),
        FactorRule(.monitoringControl, "その服やめて", .medium, 16),
        FactorRule(.monitoringControl, "SNS消して", .high, 22),
        FactorRule(.monitoringControl, "異性の連絡先消して", .high, 24),
        FactorRule(.monitoringControl, "友達より(俺|私)を優先", .high, 22),

        // --- 6. 罪悪感操作 (拡張) ---
        FactorRule(.guiltManipulation, "(俺|私)ばっかり我慢", .high, 20),
        FactorRule(.guiltManipulation, "(君|お前|あなた)のせいで(不安|眠れない|泣)", .high, 24),
        FactorRule(.guiltManipulation, "(俺|私)を(怒らせ|傷つけ)", .high, 20),
        FactorRule(.guiltManipulation, "責任(を)?取って", .high, 22),
        FactorRule(.guiltManipulation, "泣きたいのはこっち", .high, 22),
        FactorRule(.guiltManipulation, "全部(そっち|お前|君)のせい", .high, 22),
        FactorRule(.guiltManipulation, "不安にさせたんだから", .high, 22),

        // --- 7. ガスライティング (拡張) ---
        FactorRule(.gaslighting, "また始まった", .medium, 14),
        FactorRule(.gaslighting, "頭おかしい", .high, 22),
        FactorRule(.gaslighting, "記憶違い", .medium, 12),
        FactorRule(.gaslighting, "受け取り方(が|する)悪い", .high, 18),
        FactorRule(.gaslighting, "普通そんなふうに思わない", .high, 18),
        FactorRule(.gaslighting, "大げさ", .medium, 12,
                   suppressIfNearby: ["演技", "ドラマ", "演出", "話"]),

        // --- 9. 関係終了を使った脅し ---
        FactorRule(.disadvantageThreat, "(返信|連絡)しないなら別れ", .high, 28),
        FactorRule(.disadvantageThreat, "(男|女)と遊ぶなら別れ", .high, 28),
        FactorRule(.disadvantageThreat, "来ないなら(友達|もう)やめ", .high, 26),
        FactorRule(.disadvantageThreat, "言うこと聞かないなら別れ", .high, 28),
        FactorRule(.disadvantageThreat, "次やったら終わり", .high, 24),
        FactorRule(.disadvantageThreat, "できないならもういい", .medium, 16,
                   softenIfNearby: ["今日は", "今回は", "また今度"]),
        FactorRule(.disadvantageThreat, "優先(でき|して)ないなら(終|別)", .high, 26),

        // --- 11. 修復不能 / 責め継続 ---
        FactorRule(.guiltManipulation, "謝っても無駄", .high, 22),
        FactorRule(.guiltManipulation, "ごめんで済む", .high, 20),
        FactorRule(.guiltManipulation, "話すことない", .medium, 14),
        FactorRule(.guiltManipulation, "勝手にすれば", .medium, 16),
        FactorRule(.guiltManipulation, "信用できない", .medium, 14,
                   suppressIfNearby: ["ニュース", "サイト", "業者", "店"]),
        FactorRule(.guiltManipulation, "また同じこと(する|やる)んでしょ", .high, 18),
        FactorRule(.guiltManipulation, "何回同じこと", .medium, 14),
        FactorRule(.guiltManipulation, "自分で考えろ", .medium, 16),

        // --- 12. 孤立化 / 相談先制限 ---
        FactorRule(.groupExclusion, "家族に言うな", .high, 24),
        FactorRule(.groupExclusion, "誰にも相談するな", .high, 26),
        FactorRule(.groupExclusion, "誰にも言うな", .high, 24),
        FactorRule(.groupExclusion, "俺たちのこと(外|他)に話", .high, 22),

        // --- 13. 晒し・スクショ脅迫 ---
        FactorRule(.disadvantageThreat, "晒すぞ", .high, 30),
        FactorRule(.disadvantageThreat, "スクショばらまく", .high, 30),
        FactorRule(.disadvantageThreat, "みんなに(言|広め|伝え)", .high, 24),
        FactorRule(.disadvantageThreat, "(学校|会社|職場)に(言|広め|連絡|報告)", .high, 26),
        FactorRule(.disadvantageThreat, "SNSに(載|流|あげ)", .high, 26),
        FactorRule(.disadvantageThreat, "秘密(を)?バラ", .high, 28),
        FactorRule(.disadvantageThreat, "このトーク(を)?送る", .high, 26),
        FactorRule(.disadvantageThreat, "ブロックしたら(晒|許さ)", .high, 28),

        // --- 14. 自傷・自殺示唆による支配 (最重要、強 severity) ---
        FactorRule(.disadvantageThreat, "別れるなら死", .high, 32),
        FactorRule(.disadvantageThreat, "返信(くれ|し)ないなら(消える|死)", .high, 32),
        FactorRule(.disadvantageThreat, "(お前|君)のせいで(死にたい|消えたい)", .high, 32),
        FactorRule(.disadvantageThreat, "来ないなら何するか(わから|分から)", .high, 30),
        FactorRule(.disadvantageThreat, "生きてる意味ない", .high, 28),
        FactorRule(.disadvantageThreat, "(俺|私)が死んでもいい", .high, 30),
    ]
}

// ============================================================
// MARK: - 多言語対応: DiagnosisLexicon
// 検知層 (FactorDetector / ConversationPatternAnalyzer / CategoryScorer) が
// 使う言語依存の語彙・ルールを 1 箇所に集約する。スコアリング以降は factor
// ベースで言語非依存なので変更不要。ChatSession.detectedLanguage で選択。
// ============================================================

/// 言語別の検知語彙バンドル。`caseInsensitive` が true のとき regex マッチを
/// 大文字小文字無視で行う（英語向け）。
struct DiagnosisLexicon: Sendable {
    // FactorRuleDictionary
    let rules: [FactorRule]
    /// regex マッチを case-insensitive にするか（英語=true）
    let caseInsensitive: Bool
    // SubjectMarkers
    let objectAndState: [String]
    let secondPerson: [String]
    let thirdPerson: [String]
    let softMarkers: [String]
    let directAddress: [String]
    // FactorDetector
    let stopPatterns: [String]
    let continuationPatterns: [String]
    let intimateKeywords: [String]
    // ConversationPatternAnalyzer
    let worryEmotionPatterns: [String]
    let coldShortReplies: [String]
    let imperativePatterns: [String]
    let mountingPhrases: [String]
    let sarcasmPatterns: [String]
    let readPressurePhrases: [String]
    let dismissivePatterns: [String]
    // CategoryScorer
    let severePatterns: [String]

    /// チャット言語から lexicon を選択。日本語のみ日本語、それ以外（英語 / スペイン語 /
    /// 韓国語 / 中国語など未対応言語）はすべて英語にフォールバックする。
    static func forLanguage(_ language: ChatLanguage) -> DiagnosisLexicon {
        switch language {
        case .japanese: return .japanese
        default:        return .english
        }
    }

    // MARK: 日本語（既存実装をラップ）
    static let japanese = DiagnosisLexicon(
        rules: FactorRuleDictionary.rules,
        caseInsensitive: false,
        objectAndState: SubjectMarkers.objectAndState,
        secondPerson: SubjectMarkers.secondPerson,
        thirdPerson: SubjectMarkers.thirdPerson,
        softMarkers: SubjectMarkers.softMarkers,
        directAddress: SubjectMarkers.directAddress,
        stopPatterns: [
            "やめて", "やめてください", "もうやめて", "やめろ",
            "嫌だ", "嫌です", "嫌だよ", "嫌なんだけど",
            "無理", "無理だよ", "無理なんだけど",
            "それはちょっと", "ちょっと困る",
            "やめてほしい", "やめて欲しい",
            "本気で嫌", "マジで嫌",
        ],
        continuationPatterns: [
            "冗談じゃん", "ノリ悪い", "本気にすんな", "いじりじゃん",
            "本当は嬉しい", "そういうとこ(めんどい|うざ)",
            "なんで無理", "このくらいで(怒|キレ)", "傷つく方がおかしい",
            "空気読めない",
            "逃げるな", "好きならできる", "本当に好きなら",
            "友達なら(普通)?やる", "親友なら",
            "ホテル", "添い寝", "2人(きり|だけ)?で", "ふたりきり", "色気",
            "今どこ", "誰といる", "写真送", "位置情報", "証拠",
            "評価", "シフト", "推薦",
        ],
        intimateKeywords: ["好き", "愛してる", "彼女", "彼氏", "付き合", "デート", "結婚", "うちら"],
        worryEmotionPatterns: [
            "大丈夫", "心配", "疲れた", "しんどい", "つらい", "辛い", "悲しい",
            "嬉しい", "楽しみ", "怖い", "不安", "落ち込", "病んで", "泣", "寂しい",
            "ありがと", "助かった", "嬉しかった",
        ],
        coldShortReplies: [
            "別に", "知らん", "知らんがな", "知らない", "知るか",
            "あっそ", "あっそう", "ふーん。", "へーそう",
            "は？", "は?", "で？", "で?", "だから？", "だから?",
            "それで？", "それで?", "どうでもいい", "勝手にして",
        ],
        imperativePatterns: [
            "して$", "してよ$", "してくれ$", "してくれない\\??$",
            "やって$", "やれ$", "やりなさい$",
            "頼む$", "頼んだ$", "頼みます$",
            "送って$", "送れ$", "出して$", "出せ$",
            "決めて$", "決めろ$",
            "返して$", "返事して$", "答えて$",
        ],
        mountingPhrases: [
            "私だったら", "俺だったら", "僕だったら", "私なら", "俺なら", "僕なら",
            "普通は", "普通に考えて", "常識的に", "当たり前", "当然", "それぐらい",
            "簡単に", "そんなの", "そんなことも", "そんな簡単", "そんなんで",
        ],
        sarcasmPatterns: [
            "すごいね（笑）", "すごいねw", "すごいねー", "へー、すごい",
            "ふーん", "なるほどね", "ほー、そうですか", "ほー、そう",
            "あっそ", "へぇ.{0,3}そう",
        ],
        readPressurePhrases: [
            "返事は？", "返事まだ？", "なんで返さないの",
            "無視？", "無視するの？",
            "怒ってる？", "なんか怒ってる",
            "既読つけたよね", "既読見たよね",
            "返信ぐらい", "返信して",
        ],
        dismissivePatterns: [
            "^で？$", "^だから？$", "^それで？$", "^は？$", "^なに？$",
            "^どうでもいい$", "^勝手にして$", "^知らんがな$",
            "^好きにすれば$", "^好きにしたら$",
        ],
        severePatterns: ["誰にも言うな", "ばらまく", "死ぬ", "自殺", "切り刻", "(消す|◯す)ぞ"]
    )

    // MARK: 英語
    static let english = DiagnosisLexicon(
        rules: FactorRuleDictionaryEN.rules,
        caseInsensitive: true,
        objectAndState: SubjectMarkersEN.objectAndState,
        secondPerson: SubjectMarkersEN.secondPerson,
        thirdPerson: SubjectMarkersEN.thirdPerson,
        softMarkers: SubjectMarkersEN.softMarkers,
        directAddress: SubjectMarkersEN.directAddress,
        stopPatterns: FactorRuleDictionaryEN.stopPatterns,
        continuationPatterns: FactorRuleDictionaryEN.continuationPatterns,
        intimateKeywords: FactorRuleDictionaryEN.intimateKeywords,
        worryEmotionPatterns: FactorRuleDictionaryEN.worryEmotionPatterns,
        coldShortReplies: FactorRuleDictionaryEN.coldShortReplies,
        imperativePatterns: FactorRuleDictionaryEN.imperativePatterns,
        mountingPhrases: FactorRuleDictionaryEN.mountingPhrases,
        sarcasmPatterns: FactorRuleDictionaryEN.sarcasmPatterns,
        readPressurePhrases: FactorRuleDictionaryEN.readPressurePhrases,
        dismissivePatterns: FactorRuleDictionaryEN.dismissivePatterns,
        severePatterns: FactorRuleDictionaryEN.severePatterns
    )
}

/// English false-positive suppression vocabulary (objects / states / venting / soft landings).
/// Mirrors SubjectMarkers (JP). All entries are case-insensitive regex fragments.
enum SubjectMarkersEN {
    /// Insults aimed at objects/states are non-personal → suppress.
    static let objectAndState: [String] = [
        "\\bapp\\b", "\\bphone\\b", "\\bwi-?fi\\b", "\\bwifi\\b", "\\bbattery\\b",
        "\\bcharger\\b", "\\blaptop\\b", "\\bpc\\b", "\\bcomputer\\b", "\\binternet\\b",
        "\\bsignal\\b", "\\bprinter\\b", "\\bscanner\\b", "\\brouter\\b", "\\bmodem\\b",
        "\\bkeyboard\\b", "\\bmouse\\b", "\\bscreen\\b", "\\bmonitor\\b", "\\bheadphones?\\b",
        "\\bearbuds?\\b", "\\bairpods?\\b", "\\bbluetooth\\b", "\\bcode\\b", "\\blink\\b",
        "\\baccount\\b", "\\bwebsite\\b", "\\bsite\\b", "\\bserver\\b", "\\bapi\\b",
        "\\bbuild\\b", "\\bsoftware\\b", "\\bupdate\\b", "\\bos\\b", "\\bbrowser\\b",
        "\\bcar\\b", "\\bbus\\b", "\\btrain\\b", "\\bumbrella\\b", "\\bcoupon\\b",
        "\\bthis place\\b", "\\bthe (food|coffee|soup|service|menu|line|traffic)\\b",
        "\\bweather\\b", "\\bac\\b", "\\bair[\\s-]?con\\b", "\\bfridge\\b", "\\bheater\\b",
        "\\bwasher\\b", "\\bshower\\b", "\\boven\\b", "\\bremote\\b", "\\bcard\\b", "\\bkey\\b",
        "\\b(this|that)\\s+(movie|show|song|game|book|app|episode|team|plan|idea)\\b",
        "\\bidea\\b", "\\bplan\\b", "\\bmeeting\\b", "\\btraffic\\b",
        "\\bmy\\s+(head|back|legs?|arms?|knees?|feet|eyes?|hair|skin|stomach|brain)\\b",
        "\\bmy\\s+(motivation|energy|focus|memory|sleep schedule)\\b",
        "\\btoday\\b", "\\blately\\b", "\\bright now\\b", "\\bthis week\\b",
    ]

    /// Second-person markers (attack aimed at the recipient) — for require/amplify.
    static let secondPerson: [String] = [
        "\\byou\\b", "\\bu\\b", "\\byou'?re\\b", "\\byoure\\b", "\\bur\\b",
        "\\bya\\b", "\\bu r\\b", "\\byou'?ll\\b", "\\bu'?ll\\b",
    ]

    /// Third-person / venting markers (talking ABOUT someone else) → suppress personal attack.
    static let thirdPerson: [String] = [
        "\\bmy\\s+(boss|coworker|co-worker|manager|supervisor|professor|teacher|prof|customer|client|ex|roommate|landlord|friend|mom|dad|sister|brother|coach|neighbor|neighbour)\\b",
        "\\bthat\\s+(guy|girl|dude|woman|man|customer|teacher|coworker|professor|chick|person|kid|bitch)\\b",
        "\\bthis\\s+(guy|girl|dude|customer|coworker|person)\\b",
        "\\b(he|she|they)('?s|\\s+is|\\s+was|\\s+are|\\s+were)\\b",
        "\\b(his|her|their)\\s+(attitude|behavior|behaviour|fault)\\b",
        "\\bthe\\s+(new\\s+)?(guy|girl|intern|manager|customer)\\b",
        "\\bsome\\s+(guy|girl|dude|lady|idiot|asshole)\\b",
    ]

    /// Soft landing markers — soften nearby severity by 1 step.
    static let softMarkers: [String] = [
        "\\bsorry\\b", "\\bi'?m\\s+sorry\\b", "\\bmy\\s+bad\\b", "\\bi\\s+didn'?t\\s+mean\\b",
        "\\bno\\s+worries\\b", "\\btake\\s+your\\s+time\\b", "\\bit'?s\\s+ok(ay)?\\s+if\\s+(you|u)\\s+can'?t\\b",
        "\\bjk\\s+sorry\\b", "\\bthanks?\\b", "\\bthank\\s+(you|u)\\b", "\\bappreciate\\s+(it|you|u)\\b",
        "\\bno\\s+rush\\b", "\\ball\\s+good\\b", "\\bnp\\b", "\\bdon'?t\\s+stress\\b",
        "\\bwhenever\\s+(you|u)\\s+(can|get a chance)\\b", "\\bonly\\s+if\\s+(you|u)\\s+want\\b",
        "\\bi\\s+love\\s+(you|u)\\b", "\\bproud\\s+of\\s+(you|u)\\b",
    ]

    /// Direct-address markers ("you're a/an", "you little") — amplify nearby severity by 1 step.
    static let directAddress: [String] = [
        "\\b(you'?re|ur|u r)\\s+(a|an|such)\\b",
        "\\byou\\s+little\\b", "\\bu\\s+absolute\\b", "\\byou\\s+(fucking|fckin|fkn|damn|stupid)\\b",
        "\\byou\\s+(are|r)\\s+(literally|honestly|genuinely)\\b",
        "\\b@(you|u)\\b",
    ]
}

/// English-only conversation/severe arrays not provided elsewhere (imperatives, mounting,
/// sarcasm, read-pressure, dismissive). Authored to mirror the JP analyzer surfaces.
enum FactorRuleDictionaryEN {
    /// Static rule list (plain-text regex, matched case-insensitively by the engine).
    /// Mirrors FactorRuleDictionary.rules (JP). See docs/spec/diagnosis-logic.md §1/§3/§4.3.
    static let rules: [FactorRule] = [

        // MARK: - personalityDenial
        FactorRule(.personalityDenial, "\\buseless\\b", .high, 22,
                   suppressIfNearby: SubjectMarkersEN.objectAndState + SubjectMarkersEN.thirdPerson,
                   note: "Value denial. 'the app is useless' / 'my boss is useless' excluded."),
        FactorRule(.personalityDenial, "\\bworthless\\b", .high, 25,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.personalityDenial, "\\b(piece of (shit|crap)|\\bpos\\b)\\b", .high, 26,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.personalityDenial, "\\b(you'?re|ur|u r|youre)\\s+(such\\s+)?(a\\s+|an\\s+)?(trash|garbage)\\b", .high, 24,
                   note: "'trash/garbage' aimed at you."),
        FactorRule(.personalityDenial, "\\b(trash|garbage)\\b", .medium, 14,
                   suppressIfNearby: SubjectMarkersEN.objectAndState + SubjectMarkersEN.thirdPerson + ["take out", "took out", "can\\b", "bin", "movie", "show", "song", "that game"],
                   amplifyIfNearby: SubjectMarkersEN.directAddress,
                   note: "'take out the trash' / 'this movie is trash' excluded."),
        FactorRule(.personalityDenial, "\\bpathetic\\b", .high, 20,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.personalityDenial, "\\b(loser|l o s e r)\\b", .medium, 16,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson + ["take the l", "sore loser", "the game"]),
        FactorRule(.personalityDenial, "\\bwaste of (space|air|time|oxygen)\\b", .high, 25,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.personalityDenial, "\\bgood for nothing\\b", .high, 24),
        FactorRule(.personalityDenial, "\\b(you'?re|ur|u r|youre)\\s+nothing\\b", .high, 24),
        FactorRule(.personalityDenial, "\\b(embarrassment|disgrace)\\b", .high, 22,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson + ["so embarrassing", "i'?m embarrassed", "that was embarrassing"]),
        FactorRule(.personalityDenial, "\\b(freak|weirdo|creep)\\b", .medium, 14,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson + ["freak out", "freaking", "control freak", "neat freak", "freak accident"],
                   amplifyIfNearby: SubjectMarkersEN.directAddress),
        FactorRule(.personalityDenial, "\\b(scum|degenerate|vile|disgusting (person|human))\\b", .high, 24,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.personalityDenial, "\\b(you'?re|ur|u r|youre)\\s+(a\\s+)?joke\\b", .medium, 16,
                   suppressIfNearby: ["inside joke", "tell a joke"]),
        FactorRule(.personalityDenial, "\\bnobody\\s+(likes|respects)\\s+(you|u|ya)\\b", .high, 24),

        // MARK: - abilityDenial
        FactorRule(.abilityDenial, "\\b(so+|too|really|sooo+)\\s+(dumb|stupid)\\b", .high, 18,
                   suppressIfNearby: SubjectMarkersEN.objectAndState + SubjectMarkersEN.thirdPerson + ["that'?s so dumb", "this is so stupid", "so stupid (lol|lmao)"]),
        FactorRule(.abilityDenial, "\\b(you'?re|ur|u r|youre)\\s+(so+\\s+)?(dumb|stupid)\\b", .high, 20),
        FactorRule(.abilityDenial, "\\b(dumbass|dumb ass)\\b", .high, 20,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.abilityDenial, "\\b(idiot|moron|imbecile)\\b", .high, 20,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson + ["village idiot joke"]),
        FactorRule(.abilityDenial, "\\b(brain ?dead|braindead|smooth brain|smoothbrain)\\b", .high, 20,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.abilityDenial, "\\b(two|2)\\s+brain\\s+cells\\b", .medium, 16,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.abilityDenial, "\\b(are|r)\\s+(you|u)\\s+(slow|stupid|dumb|special|braindead)\\b", .high, 20),
        FactorRule(.abilityDenial, "\\b(can'?t|cannot)\\s+even\\b", .low, 8,
                   suppressIfNearby: ["i can'?t even", "literally can'?t even", "lol"],
                   note: "'i can't even' is self-directed slang."),
        FactorRule(.abilityDenial, "\\bhow\\s+(are|r)\\s+(you|u)\\s+this\\s+(dumb|stupid|slow)\\b", .high, 22),
        FactorRule(.abilityDenial, "\\b(incompetent|useless at)\\b", .high, 20,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.abilityDenial, "\\bcan'?t\\s+do\\s+anything\\s+right\\b", .high, 20),
        FactorRule(.abilityDenial, "\\b(you'?re|ur|u r|youre)\\s+(so+\\s+)?(slow|clueless|hopeless|helpless)\\b", .medium, 16),
        FactorRule(.abilityDenial, "\\b(use your brain|do you (even )?have a brain|where'?s your brain)\\b", .high, 18),
        FactorRule(.abilityDenial, "\\b(retard(ed)?|sped)\\b", .high, 22,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),

        // MARK: - existenceDenial
        FactorRule(.existenceDenial, "\\bnobody\\s+wants\\s+(you|u|ya)\\b", .high, 26),
        FactorRule(.existenceDenial, "\\bno\\s*one\\s+(likes|wants|needs)\\s+(you|u|ya)\\b", .high, 26),
        FactorRule(.existenceDenial, "\\beveryone\\s+hates\\s+(you|u|ya)\\b", .high, 26),
        FactorRule(.existenceDenial, "\\bjust\\s+(leave|go|quit|disappear)\\b", .medium, 16,
                   suppressIfNearby: ["leave it", "leave that", "leave the", "just leave it to me", "just go for it"]),
        FactorRule(.existenceDenial, "\\bget\\s+out\\b", .medium, 16,
                   suppressIfNearby: ["get out of here lol", "get outta here lol", "get out of bed", "let'?s get out", "get out the house to go"]),
        FactorRule(.existenceDenial, "\\b(you|u)\\s+don'?t\\s+belong\\b", .high, 24),
        FactorRule(.existenceDenial, "\\bnobody\\s+would\\s+miss\\s+(you|u|ya)\\b", .high, 28),
        FactorRule(.existenceDenial, "\\b(you|u)\\s+should\\s+(quit|leave|resign)\\b", .medium, 16),
        FactorRule(.existenceDenial, "\\bdon'?t\\s+(come|show up|bother coming)\\b", .high, 22,
                   suppressIfNearby: ["don'?t come over yet", "don'?t come if you'?re sick"]),
        FactorRule(.existenceDenial, "\\b(you'?re|ur|u r)\\s+(fired|done here|out)\\b", .high, 24),

        // MARK: - disadvantageThreat
        FactorRule(.disadvantageThreat, "\\b(get|have)\\s+(you|u)\\s+fired\\b", .high, 26),
        FactorRule(.disadvantageThreat, "\\bcut\\s+your\\s+(hours|shifts?|pay)\\b", .high, 25),
        FactorRule(.disadvantageThreat, "\\b(lower|tank|drop)\\s+your\\s+(grade|review|score|rating|eval(uation)?)\\b", .high, 26),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+(expose|out)\\s+(you|u)\\b", .high, 30),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+leak\\b", .high, 30,
                   suppressIfNearby: ["leak in the", "water leak", "gas leak", "roof leak"]),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+tell\\s+(everyone|everybody|your)\\b", .high, 24),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+post\\s+(it|them|that|these|your|the (pics?|photos?))\\b", .high, 28),
        FactorRule(.disadvantageThreat, "\\b(i'?ll|gonna)\\s+screenshot\\b", .medium, 14,
                   suppressIfNearby: ["screenshot it for you", "send you a screenshot", "thanks for the screenshot"]),
        FactorRule(.disadvantageThreat, "\\b(won'?t|not gonna|never)\\s+(write|do)\\s+your\\s+(rec(ommendation|ommendation letter)?|reference)\\b", .high, 26),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+fail\\s+(you|u)\\b", .high, 26),
        FactorRule(.disadvantageThreat, "\\bwe'?re\\s+done\\s+if\\b", .high, 24),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+(break\\s+up|dump)\\b", .medium, 16),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+dump\\s+(you|u|ya)\\b", .medium, 16),
        FactorRule(.disadvantageThreat, "\\b(you'?ll|youll|u'?ll)\\s+regret\\s+(it|this)\\b", .high, 24),
        FactorRule(.disadvantageThreat, "\\bwatch\\s+what\\s+happens\\b", .high, 22),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+ruin\\s+(you|u|your life|your career|your rep)\\b", .high, 28),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+make\\s+your\\s+life\\s+(hell|a living hell|miserable)\\b", .high, 28),
        FactorRule(.disadvantageThreat, "\\b(if|unless)\\s+(you|u)\\s+(don'?t|won'?t).{0,24}(or else|you'?ll regret|i'?ll tell|i'?ll post|i'?ll leak)\\b", .high, 28),
        FactorRule(.disadvantageThreat, "\\byou'?ll\\s+(be sorry|pay for this|see what happens)\\b", .high, 24),
        FactorRule(.disadvantageThreat, "\\bi\\s+know\\s+where\\s+(you|u)\\s+(live|work)\\b", .high, 30),
        // self-harm coercion cluster
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+kill\\s+myself\\s+if\\b", .high, 32,
                   note: "Coercive self-harm threat. §4.3 forced high-risk."),
        FactorRule(.disadvantageThreat, "\\bif\\s+(you|u)\\s+leave\\s+(me\\s+)?i'?ll\\s+(die|kill myself|end it)\\b", .high, 32),
        FactorRule(.disadvantageThreat, "\\b(you'?ll|youll|u'?ll)\\s+be\\s+sorry\\s+when\\s+i'?m\\s+gone\\b", .high, 32),
        FactorRule(.disadvantageThreat, "\\bi'?ll\\s+hurt\\s+myself\\b", .high, 30),
        FactorRule(.disadvantageThreat, "\\b(i'?ll|i\\s+might|gonna)\\s+end\\s+(it all|my life|myself)\\b", .high, 32),
        FactorRule(.disadvantageThreat, "\\bif\\s+(you|u)\\s+(don'?t|won'?t).{0,18}(i'?ll die|i'?ll kill myself|i'?ll hurt myself)\\b", .high, 32),
        FactorRule(.disadvantageThreat, "\\b(kys|k\\.?y\\.?s\\.?)\\b", .high, 32,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson,
                   note: "'kys' directed at the other person. §4.3."),
        FactorRule(.disadvantageThreat, "\\bkill\\s+(yourself|urself|yourselff+)\\b", .high, 32,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.disadvantageThreat, "\\b(go\\s+)?(die|drop dead)\\b", .high, 28,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson + ["i'?m dying", "dying laughing", "i'?m dead", "dead tired", "die for this", "to die for", "dying to"],
                   note: "excludes 'dying laughing' / 'to die for'."),

        // MARK: - sexualContext
        FactorRule(.sexualContext, "\\bsend\\s+(me\\s+)?nudes?\\b", .high, 28),
        FactorRule(.sexualContext, "\\bsend\\s+(me\\s+)?(a\\s+)?(pic|pics|picture|photo)\\b", .medium, 16,
                   suppressIfNearby: ["pic of the receipt", "pic of the menu", "pic of the dog", "pic of your screen", "send me a pic of the", "pic of homework", "pic of the slides"]),
        FactorRule(.sexualContext, "\\bnudes?\\b", .high, 24,
                   suppressIfNearby: ["nude (color|colour|palette|lipstick|polish|heels|dress|nails)", "nude beach (article|news)"]),
        FactorRule(.sexualContext, "\\b(you'?re|ur|u r|youre)\\s+(so+\\s+)?(hot|sexy|gorgeous)\\b", .medium, 16,
                   suppressIfNearby: ["it'?s so hot (out|today|in here)", "the (food|soup|coffee) is hot"]),
        FactorRule(.sexualContext, "\\b(nice|great|amazing)\\s+(body|ass|tits|boobs|rack|curves)\\b", .high, 20),
        FactorRule(.sexualContext, "\\bshow\\s+me\\s+(your|ur)\\b", .medium, 16,
                   suppressIfNearby: ["show me your screen", "show me your work", "show me your notes", "show me your homework", "show me your room (tour)?"]),
        FactorRule(.sexualContext, "\\bhotel\\b", .high, 25,
                   suppressIfNearby: ["hotel (booking|reservation|lobby|breakfast|checkout|check-in|conference|wifi|gym|pool)", "business hotel", "hotel for the trip", "book(ing)? a hotel", "transit hotel", "the hotel california"]),
        FactorRule(.sexualContext, "\\bcome\\s+over\\b", .medium, 16,
                   suppressIfNearby: ["come over to (study|the team|our side)", "come over for the (meeting|project|game)", "come over here lol"]),
        FactorRule(.sexualContext, "\\bstay\\s+(the\\s+night|over\\s+tonight|over\\s+tn)\\b", .high, 22),
        FactorRule(.sexualContext, "\\bnetflix\\s+(and|n)\\s+chill\\b", .high, 20),
        FactorRule(.sexualContext, "\\bu\\s+up\\b", .medium, 16,
                   note: "'u up' late-night booty-call slang."),
        FactorRule(.sexualContext, "\\bwyd\\s+(rn|tn|tonight|later)\\b", .low, 8,
                   amplifyIfNearby: ["come over", "alone", "u up", "send", "pic"]),
        FactorRule(.sexualContext, "\\b(are|r)\\s+(you|u)\\s+a\\s+virgin\\b", .high, 25),
        FactorRule(.sexualContext, "\\bhow\\s+many\\s+(guys|girls|people|partners)\\s+(have\\s+(you|u)|ya)\\b", .high, 24),
        FactorRule(.sexualContext, "\\bbody\\s+count\\b", .high, 22,
                   suppressIfNearby: ["game", "zombies", "kill", "match", "shooter"]),
        FactorRule(.sexualContext, "\\bdtf\\b", .high, 24),
        FactorRule(.sexualContext, "\\bthicc+\\b", .medium, 14),
        FactorRule(.sexualContext, "\\bdaddy\\b", .medium, 14,
                   suppressIfNearby: ["sugar daddy joke", "who'?s your daddy lol", "my daddy", "daddy issues", "daddy'?s home"]),
        FactorRule(.sexualContext, "\\b(just\\s+)?(the\\s+)?(two|2)\\s+of\\s+us\\b", .medium, 16,
                   note: "'just the two of us' = 2-people-alone invite."),
        FactorRule(.sexualContext, "\\b(grab\\s+)?drinks?\\s+(just\\s+)?(me\\s+(and|n)\\s+(you|u)|w\\s*u|alone)\\b", .medium, 16),
        FactorRule(.sexualContext, "\\b(do\\s+(you|u)\\s+have\\s+a\\s+)?(bf|boyfriend|gf|girlfriend)\\s*\\?\\b", .low, 6),
        FactorRule(.sexualContext, "\\b(your|ur)\\s+(lips|legs|figure|outfit'?s? (hot|sexy))\\b", .medium, 16),
        FactorRule(.sexualContext, "\\b(wanna|want to|wnt 2)\\s+(hook ?up|smash|fuck|bang)\\b", .high, 26),
        FactorRule(.sexualContext, "\\bcuddle\\b", .low, 8,
                   suppressIfNearby: ["the cat", "the dog", "my pet", "with a blanket"]),

        // MARK: - intimateRelationship
        FactorRule(.intimateRelationship, "\\bi\\s+love\\s+(you|u|ya)\\b", .low, 6,
                   suppressIfNearby: ["i love (it|this|that|food|the song|the show|how)", "love you guys", "love you all", "love u so much for helping"]),
        FactorRule(.intimateRelationship, "\\bif\\s+(you|u)\\s+(loved|love)\\s+me\\b", .high, 22),
        FactorRule(.intimateRelationship, "\\bif\\s+(you|u)\\s+(really\\s+)?cared\\b", .high, 20),
        FactorRule(.intimateRelationship, "\\b(babe|bae|baby)\\b", .low, 4,
                   suppressIfNearby: ["baby (shower|carrot|steps|sister|brother|food|formula|monitor)", "babe ruth", "the baby"]),
        FactorRule(.intimateRelationship, "\\bmy\\s+(gf|bf|girlfriend|boyfriend|gurl|man)\\b", .low, 4,
                   suppressIfNearby: ["ex (gf|bf|girlfriend|boyfriend)", "his gf", "her bf", "their (gf|bf)"]),
        FactorRule(.intimateRelationship, "\\b(boyfriend|girlfriend)\\b", .low, 4,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson + ["movie", "show", "song", "ex boyfriend", "ex girlfriend"]),
        FactorRule(.intimateRelationship, "\\ba\\s+real\\s+(gf|bf|partner|girlfriend|boyfriend)\\s+would\\b", .high, 22),
        FactorRule(.intimateRelationship, "\\bif\\s+(you|u)\\s+were\\s+(a\\s+)?(good|real)\\s+(gf|bf|partner)\\b", .high, 22),
        FactorRule(.intimateRelationship, "\\b(prove|show)\\s+(you|u)\\s+love\\s+me\\b", .high, 24),
        FactorRule(.intimateRelationship, "\\bcan'?t\\s+live\\s+without\\s+(you|u)\\b", .medium, 12),

        // MARK: - workEvaluation
        FactorRule(.workEvaluation, "\\b(performance\\s+)?(review|eval(uation)?)\\b", .medium, 14),
        FactorRule(.workEvaluation, "\\bshift(s)?\\b", .medium, 12,
                   suppressIfNearby: ["shift key", "night shift song", "shift gears", "paradigm shift"]),
        FactorRule(.workEvaluation, "\\bperformance\\b", .low, 10,
                   suppressIfNearby: ["concert", "stage", "the band", "movie performance", "car performance"]),
        FactorRule(.workEvaluation, "\\b(grade|gpa)\\b", .medium, 12,
                   suppressIfNearby: ["grade school", "uphill grade", "grade of the road"]),
        FactorRule(.workEvaluation, "\\b(rec(ommendation)?\\s+letter|reference\\s+letter|letter\\s+of\\s+rec)\\b", .medium, 14),
        FactorRule(.workEvaluation, "\\b(raise|promotion|bonus)\\b", .medium, 12,
                   suppressIfNearby: ["raise the (volume|roof|bar|stakes)", "raise a (glass|kid|child|toast)"]),
        FactorRule(.workEvaluation, "\\b(your|ur)\\s+(manager|boss|supervisor)\\b", .low, 8,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.workEvaluation, "\\b(internship|your job|your position|your contract)\\b", .low, 10),
        FactorRule(.workEvaluation, "\\b(professor|prof|advisor|dean)\\b", .low, 8,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),

        // MARK: - excessiveDemand
        FactorRule(.excessiveDemand, "\\bby\\s+(tonight|tn|midnight)\\b", .medium, 14),
        FactorRule(.excessiveDemand, "\\b(right\\s+now|rn)\\b", .low, 8,
                   amplifyIfNearby: ["need it", "do it", "send it", "finish", "come in", "answer"]),
        FactorRule(.excessiveDemand, "\\bneed\\s+it\\s+now\\b", .medium, 12),
        FactorRule(.excessiveDemand, "\\bcome\\s+in\\s+on\\s+your\\s+(day\\s+off|off\\s+day|weekend|vacation|pto)\\b", .high, 18),
        FactorRule(.excessiveDemand, "\\b(pull\\s+an\\s+)?all[\\s-]?nighter\\b", .medium, 15),
        FactorRule(.excessiveDemand, "\\bstay\\s+(late|until|till)\\b", .medium, 14,
                   suppressIfNearby: ["stay late if you want", "no need to stay late"]),
        FactorRule(.excessiveDemand, "\\b(doesn'?t|don'?t)\\s+matter\\s+if\\s+(you'?re|ur|u r)\\s+(sick|ill|tired)\\b", .high, 18),
        FactorRule(.excessiveDemand, "\\bby\\s+tomorrow\\s+morning\\b", .medium, 14),
        FactorRule(.excessiveDemand, "\\bdrop\\s+everything\\b", .medium, 16),
        FactorRule(.excessiveDemand, "\\bi\\s+don'?t\\s+care\\s+if\\s+(you'?re|ur|u r)\\s+(busy|sleeping|with family)\\b", .high, 18),
        FactorRule(.excessiveDemand, "\\b(asap|right\\s+away|this\\s+instant)\\b", .low, 8,
                   amplifyIfNearby: SubjectMarkersEN.directAddress + ["need", "now", "or else"]),

        // MARK: - refusalImpossible
        FactorRule(.refusalImpossible, "\\b(you|u)\\s+can'?t\\s+say\\s+no\\b", .high, 25),
        FactorRule(.refusalImpossible, "\\bno\\s+(isn'?t|is not)\\s+an\\s+option\\b", .high, 25),
        FactorRule(.refusalImpossible, "\\bif\\s+(you|u)\\s+loved\\s+me\\s+(you'?d|youd|u'?d|you would)\\b", .high, 25),
        FactorRule(.refusalImpossible, "\\bdon'?t\\s+be\\s+(lame|boring|difficult|like that)\\b", .medium, 16),
        FactorRule(.refusalImpossible, "\\b(you'?re|ur|u r)\\s+no\\s+fun\\b", .medium, 16),
        FactorRule(.refusalImpossible, "\\bcan'?t\\s+take\\s+a\\s+joke\\b", .medium, 16),
        FactorRule(.refusalImpossible, "\\b(you|u)\\s+owe\\s+me\\b", .high, 20),
        FactorRule(.refusalImpossible, "\\ba\\s+real\\s+friend\\s+would\\b", .high, 22),
        FactorRule(.refusalImpossible, "\\bstop\\s+being\\s+(difficult|so difficult|like this)\\b", .medium, 16),
        FactorRule(.refusalImpossible, "\\bwhy\\s+(are|r)\\s+(you|u)\\s+making\\s+this\\s+(so\\s+)?hard\\b", .medium, 16),
        FactorRule(.refusalImpossible, "\\b(you|u)\\s+have\\s+to\\b", .low, 6,
                   amplifyIfNearby: SubjectMarkersEN.directAddress + ["no choice", "or else", "i said"]),
        FactorRule(.refusalImpossible, "\\bdon'?t\\s+make\\s+me\\s+ask\\s+again\\b", .high, 20),
        FactorRule(.refusalImpossible, "\\b(you'?re|ur|u r)\\s+(being\\s+)?dramatic\\s+just\\s+(do|say)\\b", .medium, 16),

        // MARK: - guiltManipulation
        FactorRule(.guiltManipulation, "\\bafter\\s+everything\\s+i'?ve\\s+done\\b", .high, 22),
        FactorRule(.guiltManipulation, "\\bit'?s\\s+(your|ur)\\s+fault\\b", .high, 20),
        FactorRule(.guiltManipulation, "\\b(you|u)\\s+made\\s+me\\b", .high, 20,
                   suppressIfNearby: ["made me laugh", "made me smile", "made me happy", "made me cry (happy|of joy)"]),
        FactorRule(.guiltManipulation, "\\blook\\s+what\\s+(you|u)\\s+(did|made me do)\\b", .high, 22),
        FactorRule(.guiltManipulation, "\\bi\\s+do\\s+everything\\s+for\\s+(you|u)\\b", .high, 22),
        FactorRule(.guiltManipulation, "\\b(you'?re|ur|u r)\\s+(so+\\s+)?selfish\\b", .medium, 16),
        FactorRule(.guiltManipulation, "\\bi\\s+can'?t\\s+sleep\\s+(bc|because|cuz|cause)\\s+of\\s+(you|u)\\b", .high, 22),
        FactorRule(.guiltManipulation, "\\b(you'?re|ur|u r)\\s+hurting\\s+me\\b", .medium, 14),
        FactorRule(.guiltManipulation, "\\bi'?m\\s+always\\s+the\\s+one\\b", .medium, 16),
        FactorRule(.guiltManipulation, "\\bafter\\s+(all\\s+)?i\\s+(do|did|sacrificed)\\s+for\\s+(you|u)\\b", .high, 22),
        FactorRule(.guiltManipulation, "\\b(you|u)\\s+(always\\s+)?(make|made)\\s+me\\s+(cry|upset|feel bad)\\b", .high, 20),
        FactorRule(.guiltManipulation, "\\bi\\s+gave\\s+up\\s+everything\\s+for\\s+(you|u)\\b", .high, 22),
        FactorRule(.guiltManipulation, "\\bsorry\\s+for\\s+(existing|breathing|caring too much)\\b", .medium, 16,
                   note: "Martyr / victim-positioning sarcasm."),
        FactorRule(.guiltManipulation, "\\bguess\\s+i'?m\\s+(just\\s+)?(the\\s+)?bad\\s+(guy|one)\\b", .medium, 16),

        // MARK: - gaslighting
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+(being\\s+)?(crazy|delusional|insane|psycho)\\b", .high, 22),
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+overreacting\\b", .high, 18),
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+(being\\s+)?(so\\s+)?dramatic\\b", .high, 18),
        FactorRule(.gaslighting, "\\bthat\\s+never\\s+happened\\b", .medium, 16),
        FactorRule(.gaslighting, "\\bi\\s+never\\s+said\\s+that\\b", .medium, 16),
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+imagining\\s+(things|it)\\b", .high, 18),
        FactorRule(.gaslighting, "\\bcalm\\s+down\\b", .low, 8,
                   suppressIfNearby: ["i need to calm down", "let me calm down", "trying to calm down", "calm down the (kids|dog)"]),
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+(too|so)\\s+sensitive\\b", .medium, 16),
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+making\\s+(it|this|stuff)\\s+up\\b", .high, 18),
        FactorRule(.gaslighting, "\\b(you|u)\\s+remember\\s+(it\\s+)?wrong\\b", .medium, 16),
        FactorRule(.gaslighting, "\\bthat'?s\\s+not\\s+what\\s+(happened|i said)\\b", .medium, 14),
        FactorRule(.gaslighting, "\\b(you'?re|ur|u r)\\s+(twisting|misremembering)\\b", .high, 18),
        FactorRule(.gaslighting, "\\bstop\\s+being\\s+(so\\s+)?(paranoid|dramatic|emotional)\\b", .high, 18),
        FactorRule(.gaslighting, "\\bit'?s\\s+all\\s+in\\s+your\\s+head\\b", .high, 20),
        FactorRule(.gaslighting, "\\b(no one|nobody)\\s+else\\s+has\\s+a\\s+problem\\s+with\\s+me\\b", .medium, 16),

        // MARK: - monitoringControl
        FactorRule(.monitoringControl, "\\bwhere\\s+(are|r)\\s+(you|u)\\b", .high, 18,
                   suppressIfNearby: ["where are you from", "where r u from", "where are you at on the project", "where are you in the book"]),
        FactorRule(.monitoringControl, "\\bwho\\s+(are|r)\\s+(you|u)\\s+with\\b", .high, 18),
        FactorRule(.monitoringControl, "\\bsend\\s+(me\\s+)?your\\s+location\\b", .high, 22),
        FactorRule(.monitoringControl, "\\bshare\\s+(your|ur)\\s+location\\b", .high, 20),
        FactorRule(.monitoringControl, "\\bwhy\\s+(aren'?t|are'?nt|arent)\\s+(you|u)\\s+(answering|replying|responding)\\b", .high, 20),
        FactorRule(.monitoringControl, "\\b(you|u)\\s+left\\s+me\\s+on\\s+read\\b", .medium, 16),
        FactorRule(.monitoringControl, "\\bi\\s+saw\\s+(you|u)\\s+(were\\s+)?(online|active|posting)\\b", .high, 18),
        FactorRule(.monitoringControl, "\\bwhy'?d\\s+it\\s+take\\s+(you\\s+)?so\\s+long\\s+to\\s+(reply|text back|answer)\\b", .high, 18),
        FactorRule(.monitoringControl, "\\banswer\\s+me\\b", .high, 18),
        FactorRule(.monitoringControl, "\\bpick\\s+up\\b", .medium, 12,
                   suppressIfNearby: ["pick up milk", "pick up the kids", "pick up groceries", "pick up the order", "pick up dinner", "i'?ll pick up the"]),
        FactorRule(.monitoringControl, "\\bstop\\s+talking\\s+to\\s+(him|her|them|that guy|that girl)\\b", .high, 24),
        FactorRule(.monitoringControl, "\\bdelete\\s+(his|her|their)\\s+(number|contact)\\b", .high, 24),
        FactorRule(.monitoringControl, "\\bi\\s+checked\\s+(your|ur)\\s+phone\\b", .high, 24),
        FactorRule(.monitoringControl, "\\bsend\\s+(a\\s+)?(pic|selfie)\\s+to\\s+prove\\b", .high, 22),
        FactorRule(.monitoringControl, "\\bwhy\\s+did\\s+(you|u)\\s+(like|follow|dm)\\s+(his|her|their|that)\\b", .high, 22),
        FactorRule(.monitoringControl, "\\b(you'?re|ur|u r)\\s+typing\\b", .medium, 14),
        FactorRule(.monitoringControl, "\\bstop\\s+ignoring\\s+me\\b", .high, 18),
        FactorRule(.monitoringControl, "\\bwho'?s\\s+(that|he|she)\\b", .medium, 14,
                   amplifyIfNearby: ["dm", "liked", "commented", "following", "in your phone"]),

        // MARK: - groupExclusion
        FactorRule(.groupExclusion, "\\bignore\\s+(him|her|them)\\b", .high, 22),
        FactorRule(.groupExclusion, "\\bleave\\s+(him|her|them)\\s+out\\b", .high, 22),
        FactorRule(.groupExclusion, "\\bdon'?t\\s+invite\\b", .medium, 16),
        FactorRule(.groupExclusion, "\\bwe'?re\\s+not\\s+including\\s+(you|u|him|her|them)\\b", .high, 22),
        FactorRule(.groupExclusion, "\\bdon'?t\\s+tell\\s+anyone\\b", .high, 24,
                   note: "§4.3 forced high-risk: isolation / secrecy."),
        FactorRule(.groupExclusion, "\\bdon'?t\\s+tell\\s+(your|ur)\\s+(family|parents|mom|dad|friends)\\b", .high, 24),
        FactorRule(.groupExclusion, "\\bdon'?t\\s+talk\\s+to\\s+anyone\\s+about\\s+this\\b", .high, 24),
        FactorRule(.groupExclusion, "\\b(nobody|no one)\\s+wants\\s+(you|u)\\s+(there|here|around)\\b", .high, 24),
        FactorRule(.groupExclusion, "\\bkick\\s+(him|her|them)\\s+(out\\s+)?(of|from)\\s+the\\s+(group|chat|gc)\\b", .high, 22),
        FactorRule(.groupExclusion, "\\beveryone'?s\\s+(against|done with)\\s+(you|u|him|her)\\b", .high, 22),
        FactorRule(.groupExclusion, "\\bkeep\\s+this\\s+between\\s+us\\b", .medium, 16,
                   softenIfNearby: ["surprise", "gift", "party", "birthday"]),

        // MARK: - privacyIntrusion
        FactorRule(.privacyIntrusion, "\\bwhat'?s\\s+(your|ur)\\s+address\\b", .high, 16,
                   suppressIfNearby: ["email address", "shipping address", "for the package", "for delivery", "billing address"]),
        FactorRule(.privacyIntrusion, "\\bwhere\\s+do\\s+(you|u)\\s+live\\b", .high, 16),
        FactorRule(.privacyIntrusion, "\\bwho\\s+were\\s+(you|u)\\s+with\\b", .medium, 14),
        FactorRule(.privacyIntrusion, "\\bwhat\\s+were\\s+(you|u)\\s+doing\\b", .medium, 12),
        FactorRule(.privacyIntrusion, "\\bsend\\s+me\\s+(your|ur)\\s+(schedule|timetable|plans)\\b", .medium, 14),
        FactorRule(.privacyIntrusion, "\\b(your|ur)\\s+(home|apartment|dorm)\\s+(address|number)\\b", .high, 16),
        FactorRule(.privacyIntrusion, "\\bwhat\\s+(school|college|company)\\s+do\\s+(you|u)\\s+go\\s+to\\b", .low, 8),

        // MARK: - roleStereotype
        FactorRule(.roleStereotype, "\\b(you'?re|ur|u r)\\s+a\\s+(girl|woman)\\s+so\\b", .high, 20),
        FactorRule(.roleStereotype, "\\bact\\s+like\\s+a\\s+(lady|woman)\\b", .high, 18),
        FactorRule(.roleStereotype, "\\bman\\s+up\\b", .high, 18),
        FactorRule(.roleStereotype, "\\bbe\\s+a\\s+man\\b", .high, 18),
        FactorRule(.roleStereotype, "\\bgirls\\s+(shouldn'?t|don'?t|can'?t)\\b", .high, 20),
        FactorRule(.roleStereotype, "\\b(boys|men)\\s+don'?t\\s+(cry|do that)\\b", .high, 18),
        FactorRule(.roleStereotype, "\\bsince\\s+(you'?re|ur|u r)\\s+pregnant\\b", .medium, 14),
        FactorRule(.roleStereotype, "\\bif\\s+(you|u)\\s+take\\s+(maternity|mat)\\s+leave\\b", .high, 20),
        FactorRule(.roleStereotype, "\\b(that'?s|thats)\\s+(a\\s+)?(man'?s|woman'?s)\\s+(job|work)\\b", .high, 18),
        FactorRule(.roleStereotype, "\\bwhen\\s+(are|r)\\s+(you|u)\\s+(getting\\s+married|having\\s+kids|settling\\s+down)\\b", .medium, 12),

        // MARK: - mockingLaughter
        FactorRule(.mockingLaughter, "\\b(fired|expose|leak|dump|ruin|fail you|kys|kill yourself).{0,14}\\b(lol|lmao|lmfao|jk|jp|😂|🤣)\\b", .high, 22,
                   note: "Threat + laugh-shield bundle."),
        FactorRule(.mockingLaughter, "\\b(stupid|dumb|loser|useless|pathetic|ugly|fat).{0,12}\\b(lol|lmao|jk)\\b", .medium, 16,
                   suppressIfNearby: SubjectMarkersEN.thirdPerson),
        FactorRule(.mockingLaughter, "\\bjust\\s+(kidding|joking)\\b", .medium, 12,
                   suppressIfNearby: ["lol just kidding about the", "jk about dinner", "haha just kidding congrats"]),
        FactorRule(.mockingLaughter, "\\bcan'?t\\s+take\\s+a\\s+joke\\b", .medium, 14),
        FactorRule(.mockingLaughter, "\\bit\\s+was\\s+(just\\s+)?a\\s+joke\\b", .medium, 12),
        FactorRule(.mockingLaughter, "\\b(you|u)\\s+actually\\s+(mad|upset|crying)\\s*(lol|lmao|\\?)\\b", .high, 20),
        FactorRule(.mockingLaughter, "\\bgetting\\s+offended\\s+over\\s+(a\\s+joke|nothing|this)\\b", .high, 20),
        FactorRule(.mockingLaughter, "\\beveryone\\s+(was\\s+)?(laughing|thought it was funny)\\b", .medium, 14),
        FactorRule(.mockingLaughter, "\\b(lighten|loosen)\\s+up\\b", .medium, 14),

        // MARK: - quotaPairing
        FactorRule(.quotaPairing, "\\b(drinks?|dinner|hotel|come over|date|hook ?up|nudes?).{0,20}(shift|review|grade|gpa|rec(ommendation)?|promotion|raise|bonus|eval)\\b", .high, 30),
        FactorRule(.quotaPairing, "\\b(shift|review|grade|gpa|rec(ommendation)?|promotion|raise|bonus|eval).{0,20}(drinks?|dinner|hotel|come over|date|hook ?up|nudes?)\\b", .high, 30),
        FactorRule(.quotaPairing, "\\b(if|unless)\\s+(you|u).{0,16}(come over|send|drinks?|date|sleep with).{0,16}(shift|grade|review|rec|promotion|pass)\\b", .high, 30),
        FactorRule(.quotaPairing, "\\bbe\\s+nice\\s+to\\s+me.{0,16}(good\\s+)?(grade|review|shift|rec|raise)\\b", .high, 28),
        FactorRule(.quotaPairing, "\\bwant\\s+(that|a)\\s+(good\\s+)?(grade|review|shift|raise|rec).{0,18}(drinks?|dinner|come over|date)\\b", .high, 30),

        // MARK: - alcoholCoercion
        FactorRule(.alcoholCoercion, "\\bone\\s+drink\\s+won'?t\\b", .medium, 16),
        FactorRule(.alcoholCoercion, "\\bdon'?t\\s+be\\s+a\\s+(buzzkill|party pooper|lightweight)\\b", .high, 20),
        FactorRule(.alcoholCoercion, "\\bchug\\b", .high, 20,
                   suppressIfNearby: ["chug along", "train chug"]),
        FactorRule(.alcoholCoercion, "\\b(you|u)\\s+have\\s+to\\s+drink\\b", .high, 20),
        FactorRule(.alcoholCoercion, "\\beveryone'?s\\s+drinking\\b", .medium, 14),
        FactorRule(.alcoholCoercion, "\\bdon'?t\\s+be\\s+lame\\s+just\\s+drink\\b", .high, 22),
        FactorRule(.alcoholCoercion, "\\b(just\\s+)?one\\s+(more\\s+)?shot\\b", .medium, 14,
                   suppressIfNearby: ["one shot at this", "give it one shot", "screenshot", "shot of espresso", "free throw"]),
        FactorRule(.alcoholCoercion, "\\b(can'?t\\s+leave|not\\s+leaving)\\s+(until|til)\\s+(you|u)\\s+(drink|finish)\\b", .high, 22),
        FactorRule(.alcoholCoercion, "\\bwhy\\s+(aren'?t|are'?nt)\\s+(you|u)\\s+drinking\\b", .medium, 14),

        // MARK: - customerAggression
        FactorRule(.customerAggression, "\\bi'?ll\\s+leave\\s+a\\s+(bad|1[\\s-]?star|one[\\s-]?star|negative)\\s+review\\b", .high, 24),
        FactorRule(.customerAggression, "\\bi'?ll\\s+post\\s+this\\s+(on|to)\\s+(yelp|google|insta|instagram|twitter|x|tiktok|social)\\b", .high, 24),
        FactorRule(.customerAggression, "\\b(get|bring)\\s+me\\s+your\\s+manager\\b", .high, 22),
        FactorRule(.customerAggression, "\\bi'?ll\\s+sue\\b", .high, 22),
        FactorRule(.customerAggression, "\\bcorporate\\s+will\\s+hear\\s+about\\s+this\\b", .high, 22),
        FactorRule(.customerAggression, "\\b(do\\s+you\\s+know\\s+who\\s+i\\s+am|the\\s+customer\\s+is\\s+always\\s+right)\\b", .high, 22),
        FactorRule(.customerAggression, "\\bi\\s+(want|demand)\\s+a\\s+(full\\s+)?refund\\b", .medium, 12,
                   suppressIfNearby: ["please", "thanks", "would it be possible", "sorry to ask"]),
        FactorRule(.customerAggression, "\\bi'?ll\\s+(report|destroy)\\s+(your|this)\\s+(business|store|company|place)\\b", .high, 24),
        FactorRule(.customerAggression, "\\bget\\s+(you|u)\\s+fired\\s+for\\s+this\\b", .high, 24),

        // MARK: - maternityPenalty
        FactorRule(.maternityPenalty, "\\bpregnant.{0,24}(don'?t\\s+expect|no)\\s+(a\\s+)?(promotion|raise)\\b", .high, 26),
        FactorRule(.maternityPenalty, "\\bshouldn'?t\\s+have\\s+(kids|a baby)\\s+if\\b", .high, 24),
        FactorRule(.maternityPenalty, "\\b(maternity|mat)\\s+leave.{0,20}(don'?t\\s+expect|forget|no)\\s+(promotion|raise|the role)\\b", .high, 24),
        FactorRule(.maternityPenalty, "\\bpregnant.{0,20}(replace|let you go|step down|demote)\\b", .high, 26),
        FactorRule(.maternityPenalty, "\\b(having a baby|the baby).{0,16}(your career|over|done)\\b", .high, 22),
        FactorRule(.maternityPenalty, "\\bcan'?t\\s+(commit|keep up)\\s+(now\\s+)?(that\\s+)?(you'?re|ur)\\s+pregnant\\b", .high, 24),

        // MARK: - academicPower
        FactorRule(.academicPower, "\\bi\\s+won'?t\\s+write\\s+(your|ur)\\s+(rec(ommendation)?|reference|letter)\\b", .high, 28),
        FactorRule(.academicPower, "\\b(you|u)\\s+won'?t\\s+graduate\\b", .high, 26),
        FactorRule(.academicPower, "\\bi'?ll\\s+fail\\s+(you|u)\\b", .high, 26),
        FactorRule(.academicPower, "\\bi\\s+decide\\s+(if|whether)\\s+(you|u)\\s+(pass|graduate|stay)\\b", .high, 26),
        FactorRule(.academicPower, "\\b(your|ur)\\s+(thesis|dissertation|defense|funding).{0,16}(depends on|up to me|if you)\\b", .high, 24),
        FactorRule(.academicPower, "\\bgo\\s+against\\s+me\\s+and.{0,16}(grade|graduate|rec|funding|lab)\\b", .high, 26),
        FactorRule(.academicPower, "\\bi'?ll\\s+(kick|remove)\\s+(you|u)\\s+(out\\s+of\\s+)?(the\\s+)?(lab|program|ph\\.?d)\\b", .high, 26),
    ]

    // MARK: - FactorDetector arrays
    static let stopPatterns: [String] = [
        "\\bstop\\b", "\\bno\\b", "\\bplease\\s+stop\\b", "\\b(pls|plz)\\s+stop\\b",
        "\\bi\\s+don'?t\\s+want\\s+to\\b", "\\bleave\\s+me\\s+alone\\b", "\\bi\\s+said\\s+no\\b",
        "\\bthat'?s\\s+enough\\b", "\\bcut\\s+it\\s+out\\b", "\\bback\\s+off\\b", "\\bnot\\s+okay\\b",
        "\\b(you'?re|ur|u r)\\s+making\\s+me\\s+uncomfortable\\b", "\\bquit\\s+it\\b", "\\bknock\\s+it\\s+off\\b",
    ]
    static let continuationPatterns: [String] = [
        "\\bjust\\s+kidding\\b", "\\bjk\\b", "\\blighten\\s+up\\b", "\\bchill\\b",
        "\\bcan'?t\\s+take\\s+a\\s+joke\\b", "\\bdon'?t\\s+be\\s+so\\s+sensitive\\b",
        "\\b(you'?re|ur|u r)\\s+overreacting\\b", "\\bstop\\s+being\\s+(so\\s+)?dramatic\\b", "\\bno\\s+fun\\b",
        "\\bdon'?t\\s+be\\s+lame\\b", "\\b(you|u)\\s+know\\s+(you|u)\\s+want\\s+(to|it)\\b",
        "\\bif\\s+(you|u)\\s+loved\\s+me\\b", "\\ba\\s+real\\s+friend\\s+would\\b",
        "\\bsend\\s+nudes?\\b", "\\bsend\\s+(a\\s+)?(pic|selfie)\\b", "\\bcome\\s+over\\b",
        "\\bwhere\\s+(are|r)\\s+(you|u)\\b", "\\bwho\\s+(are|r)\\s+(you|u)\\s+with\\b",
        "\\bsend\\s+(me\\s+)?your\\s+location\\b", "\\banswer\\s+me\\b", "\\breview\\b", "\\bshift\\b",
        "\\bjust\\s+one\\s+(drink|shot|more)\\b", "\\bdon'?t\\s+make\\s+me\\s+ask\\s+again\\b",
    ]
    static let intimateKeywords: [String] = [
        "\\blove\\s+(you|u)\\b", "\\bbabe\\b", "\\bbaby\\b", "\\bbae\\b", "\\bbf\\b", "\\bgf\\b",
        "\\bboyfriend\\b", "\\bgirlfriend\\b", "\\bdating\\b", "\\bmy\\s+love\\b", "\\bmiss\\s+(you|u)\\b", "\\bdate\\s+night\\b",
    ]

    // MARK: - ConversationPatternAnalyzer arrays
    static let worryEmotionPatterns: [String] = [
        "\\b(are|r)\\s+(you|u)\\s+ok(ay)?\\b", "\\b(you|u)\\s+ok(ay)?\\b", "\\bi'?m\\s+worried\\b",
        "\\bi'?m\\s+scared\\b", "\\bi'?m\\s+(so\\s+)?tired\\b", "\\b(i'?m\\s+)?exhausted\\b",
        "\\bi'?m\\s+sad\\b", "\\bi'?m\\s+depressed\\b", "\\bi'?m\\s+(so\\s+)?anxious\\b", "\\bi'?m\\s+crying\\b",
        "\\bi\\s+feel\\s+(awful|terrible|like crap|so down)\\b", "\\bi'?m\\s+struggling\\b",
        "\\bi'?m\\s+not\\s+ok(ay)?\\b", "\\bmiss\\s+(you|u)\\b", "\\bi'?m\\s+(so\\s+)?lonely\\b",
        "\\bthank\\s+(you|u)\\s+so\\s+much\\b", "\\bthat\\s+(really\\s+)?helped\\b",
    ]
    static let coldShortReplies: [String] = [
        "\\bk\\b", "\\bkk\\b", "\\bwhatever\\b", "\\bidc\\b", "\\bi\\s+don'?t\\s+care\\b",
        "\\bso\\b\\?", "\\band\\?", "\\bok\\s+and\\?", "\\bcool\\b", "\\blol\\s+ok\\b",
        "\\bdon'?t\\s+care\\b", "\\bnot\\s+my\\s+problem\\b", "\\byour\\s+problem\\b", "\\bmeh\\b",
        "\\bwho\\s+cares\\b", "\\bok\\.?\\b",
    ]
    /// English imperative-command leads (dominance ratio). Specific phrases to limit false positives.
    static let imperativePatterns: [String] = [
        "^(send|answer|reply|respond|text\\s+me|call\\s+me|come\\s+here|do\\s+it|hurry\\s+up|stop\\b|fix\\s+it|finish\\s+it|get\\s+(me|it)|give\\s+me|tell\\s+me|show\\s+me|delete|unsend|pick\\s+up|drop\\s+everything|move|hurry)\\b",
        "\\bdo\\s+it\\s+now\\b", "\\bjust\\s+(do|send|answer|reply)\\s+it\\b",
    ]
    /// English condescension / mansplaining markers.
    static let mountingPhrases: [String] = [
        "\\bif\\s+i\\s+were\\s+(you|u)\\b", "\\bobviously\\b", "\\bliterally\\s+everyone\\b",
        "\\bit'?s\\s+common\\s+sense\\b", "\\bany\\s+(normal|sane|reasonable)\\s+person\\b",
        "\\bthat'?s\\s+(so|literally)\\s+easy\\b", "\\beven\\s+a\\s+(kid|child|baby|toddler)\\s+could\\b",
        "\\bit'?s\\s+not\\s+that\\s+hard\\b", "\\beveryone\\s+knows\\b", "\\bduh\\b",
        "\\bi\\s+already\\s+told\\s+(you|u)\\b", "\\bas\\s+i\\s+(said|told you)\\b",
        "\\bhow\\s+do\\s+(you|u)\\s+not\\s+(know|get)\\s+(this|that)\\b",
        "\\blet\\s+me\\s+explain\\s+(this\\s+)?again\\b", "\\bnormal\\s+people\\b",
    ]
    /// English short sarcasm (matched on short messages). Kept conservative.
    static let sarcasmPatterns: [String] = [
        "\\b(wow|oh)\\s+(great|amazing|nice|cool)\\b", "\\bsure\\s+jan\\b", "\\bk\\s+cool\\b",
        "\\bwhatever\\s+(you|u)\\s+say\\b", "\\bgood\\s+for\\s+(you|u)\\b", "🙄",
        "\\bcongrats\\s+i\\s+guess\\b", "\\boh\\s+really\\b",
    ]
    /// English read-pressure phrases (complements monitoringControl).
    static let readPressurePhrases: [String] = [
        "\\b(you|u)\\s+there\\?", "\\bwhy\\s+(aren'?t|are'?nt)\\s+(you|u)\\s+(answering|replying)\\b",
        "\\bseen\\?", "\\b(are|r)\\s+(you|u)\\s+(mad|ignoring\\s+me)\\b", "\\banswer\\s+me\\b",
        "\\bjust\\s+(reply|answer|text\\s+back)\\b", "\\bhello\\?+", "\\bhellooo+\\b",
        "\\bi\\s+know\\s+(you|u)\\s+(saw|read)\\s+(this|it|my)\\b",
        "\\bso\\s+(you'?re|ur)\\s+just\\s+(gonna\\s+)?ignore\\b",
    ]
    /// English dismissive one-liners (anchored, short messages only).
    static let dismissivePatterns: [String] = [
        "^(so|and)\\??$", "^k\\.?$", "^kk$", "^whatever\\.?$", "^idc$", "^cool\\.?$", "^meh$",
        "^who\\s+cares\\??$", "^do\\s+what\\s+(you|u)\\s+want\\.?$", "^(your|not my)\\s+problem\\.?$",
    ]

    // MARK: - CategoryScorer severe patterns (§4.3)
    static let severePatterns: [String] = [
        "\\bkys\\b", "\\bkill\\s+(yourself|urself)\\b", "\\bi'?ll\\s+kill\\s+myself\\b",
        "\\bdon'?t\\s+tell\\s+anyone\\b", "\\bi'?ll\\s+leak\\b", "\\bi'?ll\\s+post\\s+(your|ur|the|those)\\b",
        "\\bsend\\s+nudes?\\s+or\\b", "\\bi'?ll\\s+ruin\\s+(you|u)\\b",
        "\\b(you'?ll|youll|u'?ll)\\s+regret\\b", "\\bi'?ll\\s+expose\\s+(you|u)\\b",
        "\\bi\\s+know\\s+where\\s+(you|u)\\s+(live|work)\\b",
    ]
}
