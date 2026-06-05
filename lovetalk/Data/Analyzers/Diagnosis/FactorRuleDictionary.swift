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
