import Foundation

/// 全タイプ名カタログ。docs/spec/diagnosis-logic.md §6 と整合。
enum HarassmentTypeCatalog {

    static let all: [HarassmentType] = powerTypes + sexualTypes + moralTypes + otherTypes

    // MARK: - パワハラ系
    private static let powerTypes: [HarassmentType] = [
        HarassmentType(
            id: "boss_dragon",
            emoji: "🐉",
            typeName: "上司ドラゴン型",
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: "立場差と評価・仕事を使った圧",
            catchCopyTemplates: [
                "肩書きを背負って炎を吐くタイプ。逃げ場が狭くなる会話です。",
                "立場の重さで殴ってくるので、防御が間に合いません。",
            ],
            triggerFactors: [.dominance, .workEvaluation, .disadvantageThreat],
            darkHumorAdvice: "肩書きと指導の距離が遠すぎるとドラゴンになります。"
        ),
        HarassmentType(
            id: "indoctrination_devil",
            emoji: "👹",
            typeName: "指導の皮をかぶった鬼型",
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: "指導風の人格否定・精神的攻撃",
            catchCopyTemplates: [
                "これは指導ではなく、メンタルに紙やすりをかけるタイプの会話です。",
                "指導の名のもとに、人格をすり減らしにきています。",
            ],
            triggerFactors: [.personalityDenial, .abilityDenial, .workEvaluation, .dominance],
            darkHumorAdvice: "本当に必要な指導は、人格を燃やさなくてもできます。"
        ),
        HarassmentType(
            id: "rank_swinger",
            emoji: "🪓",
            typeName: "立場ブンブン丸型",
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: "権限を振りかざす、不利益示唆",
            catchCopyTemplates: [
                "権限を振り回すたびに、相手の安全圏が削れていきます。",
                "肩書きで人を黙らせるタイプ。会話の往復が成立していません。",
            ],
            triggerFactors: [.dominance, .disadvantageThreat, .refusalImpossible],
            darkHumorAdvice: "権限は振り回すものではなく、機能させるものです。"
        ),
        HarassmentType(
            id: "mental_mower",
            emoji: "🌱",
            typeName: "メンタル草刈り機型",
            primaryCategories: [.power, .moral],
            subCategories: [],
            structureSummary: "人格否定・能力否定・自己肯定感削り",
            catchCopyTemplates: [
                "話すたびに自己肯定感が一段ずつ刈り取られていきます。",
                "丁寧に見えて、芯のところを削ってきます。",
            ],
            triggerFactors: [.personalityDenial, .abilityDenial, .existenceDenial],
            darkHumorAdvice: "自己肯定感を草扱いされる関係は、長続きしない方が健全です。"
        ),
        HarassmentType(
            id: "task_dumper",
            emoji: "📦",
            typeName: "仕事押しつけ倉庫型",
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: "過大要求・無理な期限・休日深夜対応",
            catchCopyTemplates: [
                "段ボールごと仕事を投げてくるタイプ。受け取る前提で会話が進みます。",
                "期限と量の感覚がバグっているので、こちらが壊れる前提です。",
            ],
            triggerFactors: [.excessiveDemand, .workEvaluation, .refusalImpossible],
            darkHumorAdvice: "倉庫業務は本来、人間に直接投げるものではありません。"
        ),
        HarassmentType(
            id: "place_revoker",
            emoji: "🚪",
            typeName: "居場所はく奪マン型",
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: "「来なくていい」「外す」など所属否定",
            catchCopyTemplates: [
                "出口を見せながら従わせるタイプ。残るのも出るのもこちらの負担です。",
                "ドアを開けたまま指示してくる、心理的に逃げにくい構造です。",
            ],
            triggerFactors: [.existenceDenial, .disadvantageThreat, .dominance],
            darkHumorAdvice: "居場所をちらつかせる人と居場所を共有しなくて大丈夫です。"
        ),
        HarassmentType(
            id: "info_freezer",
            emoji: "🧊",
            typeName: "共有外し冷凍庫型",
            primaryCategories: [.power, .other],
            subCategories: [.grouping],
            structureSummary: "情報共有外し・孤立化・無視指示",
            catchCopyTemplates: [
                "情報の流れから少しずつ凍結させていくタイプです。",
                "見えないところで距離を取られる、じわじわ冷える構造です。",
            ],
            triggerFactors: [.groupExclusion, .dominance, .workEvaluation],
            darkHumorAdvice: "情報共有は感情の天気予報ではないので、ムラがあると困ります。"
        ),
    ]

    // MARK: - セクハラ系
    private static let sexualTypes: [HarassmentType] = [
        HarassmentType(
            id: "distance_bugged_uncle",
            emoji: "🫥",
            typeName: "距離感バグおじさん型",
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: "身体・恋愛への不要な踏み込み",
            catchCopyTemplates: [
                "距離感の解像度が壊れているタイプ。こちらの安全圏が狭まります。",
                "親しみのつもりが、業務上不要な踏み込みになっています。",
            ],
            triggerFactors: [.sexualContext, .privacyIntrusion],
            darkHumorAdvice: "親しみと距離感のバグはアップデートで直しましょう。"
        ),
        HarassmentType(
            id: "hidden_motive_skeleton",
            emoji: "💀",
            typeName: "下心スケルトン型",
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: "下心が透ける誘い・性的ニュアンス",
            catchCopyTemplates: [
                "オブラートが薄すぎて、中身が透けています。",
                "親しみの皮の下から、別の意図がはっきり見えます。",
            ],
            triggerFactors: [.sexualContext, .mockingLaughter],
            darkHumorAdvice: "下心は装飾しても重量は減りません。"
        ),
        HarassmentType(
            id: "drink_zombie",
            emoji: "🧟",
            typeName: "飲み誘いゾンビ型",
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: "拒否後も続く誘い、執拗な連絡",
            catchCopyTemplates: [
                "断っても断っても誘いが復活してくるタイプです。",
                "「やめて」を聞いたあとから、誘いの回数が増えています。",
            ],
            triggerFactors: [.sexualContext, .boundaryViolation, .persistentRepetition],
            darkHumorAdvice: "誘いは何度も復活させるものではありません。"
        ),
        HarassmentType(
            id: "quota_bundle_seller",
            emoji: "🎁",
            typeName: "評価と下心の抱き合わせ販売型",
            primaryCategories: [.sexual, .power],
            subCategories: [],
            structureSummary: "性的・恋愛的要求と評価の結合",
            catchCopyTemplates: [
                "下心と評価がセット販売されています。返品してください。",
                "業務文脈に恋愛を混ぜ込む、抱き合わせ販売型の会話です。",
            ],
            triggerFactors: [.quotaPairing, .sexualContext, .workEvaluation, .disadvantageThreat],
            darkHumorAdvice: "冗談に見せた圧は、冗談よりだいぶ重いです。"
        ),
        HarassmentType(
            id: "outfit_check_yokai",
            emoji: "👗",
            typeName: "服装チェック妖怪型",
            primaryCategories: [.sexual, .other],
            subCategories: [.gender],
            structureSummary: "服装・身体への過剰な言及",
            catchCopyTemplates: [
                "毎回服装に評価を入れてくる、視線の置き場がバグった会話です。",
                "服装＝コミュニケーションだと思っているタイプ。境界が薄いです。",
            ],
            triggerFactors: [.sexualContext, .roleStereotype],
            darkHumorAdvice: "服装は天気の話ではないので、毎回採点しなくて大丈夫です。"
        ),
        HarassmentType(
            id: "sticky_compliment",
            emoji: "🧴",
            typeName: "ねっとり褒め殺し型",
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: "褒めている風の性的評価",
            catchCopyTemplates: [
                "褒めているように見えて、評価の角度が私的すぎるタイプです。",
                "褒め言葉の中に、業務上不要な観察が混ざっています。",
            ],
            triggerFactors: [.sexualContext, .mockingLaughter],
            darkHumorAdvice: "業務評価は褒め殺しの形式を取らないものです。"
        ),
        HarassmentType(
            id: "haha_humidifier",
            emoji: "🫧",
            typeName: "笑でごまかす湿気型",
            primaryCategories: [.sexual, .moral],
            subCategories: [],
            structureSummary: "「笑」で圧や性的発言を軽く見せる",
            catchCopyTemplates: [
                "「笑」で空気を軽くしているように見えて、内容は重いです。",
                "ジョーク風の包装紙が、中身の重さを変えていません。",
            ],
            triggerFactors: [.mockingLaughter, .sexualContext, .disadvantageThreat],
            darkHumorAdvice: "「w」「笑」を足しても、不快の総量は変わりません。"
        ),
    ]

    // MARK: - モラハラ系
    private static let moralTypes: [HarassmentType] = [
        HarassmentType(
            id: "guilt_artisan",
            emoji: "🧵",
            typeName: "罪悪感職人型",
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: "相手に罪悪感を背負わせる",
            catchCopyTemplates: [
                "罪悪感を縫い付けてくるタイプ。会話のたびに重くなります。",
                "感情の責任分担が完全にこちら側に寄っています。",
            ],
            triggerFactors: [.guiltManipulation, .intimateRelationship],
            darkHumorAdvice: "感情の責任は一人で背負うものでも、押し付けるものでもありません。"
        ),
        HarassmentType(
            id: "emotion_hostage",
            emoji: "🧸",
            typeName: "感情人質型",
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: "愛情・関係継続を条件に支配",
            catchCopyTemplates: [
                "「好き」を担保に、相手の自由時間を差し押さえています。",
                "愛情を条件付き販売しているタイプの関係です。",
            ],
            triggerFactors: [.intimateRelationship, .guiltManipulation, .refusalImpossible, .monitoringControl],
            darkHumorAdvice: "恋愛はログインボーナスではないので、即レス義務はありません。"
        ),
        HarassmentType(
            id: "memory_fraud_ghost",
            emoji: "👻",
            typeName: "記憶改ざん妖怪型",
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: "ガスライティング・感覚否定",
            catchCopyTemplates: [
                "覚えてないのではなく、こちらの記憶を書き換えにきています。",
                "出来事ではなく、こちらの感覚そのものを否定してくるタイプです。",
            ],
            triggerFactors: [.gaslighting, .guiltManipulation],
            darkHumorAdvice: "あなたの記憶は、相手の都合で書き換わるものではありません。"
        ),
        HarassmentType(
            id: "read_watching_crow",
            emoji: "🐦‍⬛",
            typeName: "既読監視カラス型",
            primaryCategories: [.moral, .other],
            subCategories: [.digital],
            structureSummary: "既読責め・返信強要・監視",
            catchCopyTemplates: [
                "既読の有無で機嫌が決まるタイプ。返信は人質です。",
                "通知を見るたびに、安全圏が削られていく構造です。",
            ],
            triggerFactors: [.monitoringControl, .persistentRepetition, .guiltManipulation],
            darkHumorAdvice: "既読は感情の天気予報ではないので、機嫌の根拠にできません。"
        ),
        HarassmentType(
            id: "sulk_blackhole",
            emoji: "🕳",
            typeName: "不機嫌ブラックホール型",
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: "沈黙・不機嫌で相手を操作",
            catchCopyTemplates: [
                "不機嫌で空気の重力を上げてくるタイプの会話です。",
                "沈黙を武器にしているので、こちらの呼吸が浅くなります。",
            ],
            triggerFactors: [.guiltManipulation, .intimateRelationship],
            darkHumorAdvice: "沈黙は感情の説明から逃げる便利な道具にされがちです。"
        ),
        HarassmentType(
            id: "restraint_overkill",
            emoji: "🔒",
            typeName: "束縛セキュリティ過剰型",
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: "位置情報・写真要求・交友関係制限",
            catchCopyTemplates: [
                "安全のためと言いつつ、行動範囲を制限する構造です。",
                "信頼のなさをセキュリティ強化で覆っているタイプです。",
            ],
            triggerFactors: [.monitoringControl, .privacyIntrusion, .intimateRelationship],
            darkHumorAdvice: "セキュリティは行動制限ではなく、信頼関係で組むものです。"
        ),
        HarassmentType(
            id: "victim_position_lock",
            emoji: "🎭",
            typeName: "被害者ポジション固定型",
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: "自分を被害者にして相手を責める",
            catchCopyTemplates: [
                "常に被害者席に座って、加害の負担をこちらに置いてくるタイプです。",
                "立場のすり替えが起きているので、責任の重心が常にずれます。",
            ],
            triggerFactors: [.guiltManipulation, .gaslighting, .intimateRelationship],
            darkHumorAdvice: "被害者と加害者の席は、自分で勝手に決めるものではありません。"
        ),
    ]

    // MARK: - その他系
    private static let otherTypes: [HarassmentType] = [
        HarassmentType(
            id: "gender_fossil",
            emoji: "🦴",
            typeName: "ジェンダー化石型",
            primaryCategories: [.other],
            subCategories: [.gender],
            structureSummary: "性別役割の押し付け",
            catchCopyTemplates: [
                "アップデートが止まっている価値観をそのまま押し付けてくるタイプです。",
                "性別を理由にした要求が、令和を未読のまま届いています。",
            ],
            triggerFactors: [.roleStereotype, .dominance],
            darkHumorAdvice: "アップデートしていない価値観は、押し付け用ではなく博物館用です。"
        ),
        HarassmentType(
            id: "drink_primitive",
            emoji: "🍺",
            typeName: "飲み会原始人型",
            primaryCategories: [.other],
            subCategories: [.alcohol],
            structureSummary: "飲酒強要・拒否への非難",
            catchCopyTemplates: [
                "飲める＝偉い、で物事を片付けてくるタイプの会話です。",
                "場のテンションを飲酒で揃えようとする、原始的な圧の構造です。",
            ],
            triggerFactors: [.alcoholCoercion, .dominance],
            darkHumorAdvice: "飲める量で人を評価する時代は、本当にもう終わっています。"
        ),
        HarassmentType(
            id: "customer_firebomb",
            emoji: "🔥",
            typeName: "カスハラ火炎瓶型",
            primaryCategories: [.other],
            subCategories: [.customer],
            structureSummary: "客・取引先からの過剰要求・脅し",
            catchCopyTemplates: [
                "客の立場で爆弾を投げてくるタイプ。要求が燃料に変わっています。",
                "SNS・本社・誠意のワードを武器に切り出してくる構造です。",
            ],
            triggerFactors: [.customerAggression, .disadvantageThreat],
            darkHumorAdvice: "正当な要求は、火炎瓶にしなくても伝わります。"
        ),
        HarassmentType(
            id: "privacy_thief",
            emoji: "🕵️",
            typeName: "プライバシー泥棒型",
            primaryCategories: [.other, .moral],
            subCategories: [.privacy],
            structureSummary: "私生活への過度な干渉",
            catchCopyTemplates: [
                "プライバシーの境界線を、軽い質問の顔で越えてきます。",
                "私生活の在庫管理をしようとしてくるタイプの会話です。",
            ],
            triggerFactors: [.privacyIntrusion, .monitoringControl],
            darkHumorAdvice: "プライバシーは差し出す前提のメニューではありません。"
        ),
        HarassmentType(
            id: "lab_king",
            emoji: "🎓",
            typeName: "研究室の王様型",
            primaryCategories: [.other],
            subCategories: [.academic],
            structureSummary: "成績・推薦・卒業権限を使った圧",
            catchCopyTemplates: [
                "学業の権限を切り札に出してくる、教室サイズの絶対王政です。",
                "推薦・卒業をちらつかせる、出口を握って指示するタイプです。",
            ],
            triggerFactors: [.academicPower, .dominance, .disadvantageThreat],
            darkHumorAdvice: "学業の権限は、相手の人生を握る道具ではありません。"
        ),
        HarassmentType(
            id: "life_event_stomper",
            emoji: "🍼",
            typeName: "ライフイベント踏みつけ型",
            primaryCategories: [.other],
            subCategories: [.maternity],
            structureSummary: "妊娠・育児・介護への不利益示唆",
            catchCopyTemplates: [
                "妊娠・育児・介護を「評価のマイナス材料」に変換してくるタイプです。",
                "ライフイベントを軽くまたいで、評価軸を変えてくる構造です。",
            ],
            triggerFactors: [.maternityPenalty, .disadvantageThreat, .roleStereotype],
            darkHumorAdvice: "ライフイベントは、評価で踏みつぶしていいものではありません。"
        ),
        HarassmentType(
            id: "screenshot_bomb",
            emoji: "📢",
            typeName: "スクショ拡散爆弾型",
            primaryCategories: [.other],
            subCategories: [.digital],
            structureSummary: "晒し・スクショ悪用・拡散脅迫",
            catchCopyTemplates: [
                "拡散をちらつかせて従わせる、デジタル時代型の脅しです。",
                "スクショ・晒しのワードで黙らせにくるタイプの会話です。",
            ],
            triggerFactors: [.disadvantageThreat, .persistentRepetition, .customerAggression],
            darkHumorAdvice: "拡散を交渉カードに使うのは、対等な関係ではありません。"
        ),
        HarassmentType(
            id: "group_freeze_beam",
            emoji: "🧊",
            typeName: "グループ冷凍ビーム型",
            primaryCategories: [.other],
            subCategories: [.grouping],
            structureSummary: "無視・仲間外れ・グループ内晒し",
            catchCopyTemplates: [
                "グループの空気を凍らせて、特定の人だけ寒くしてくる構造です。",
                "「無視でいい」を共通指示にしてくる、集団的な排除の形です。",
            ],
            triggerFactors: [.groupExclusion, .dominance],
            darkHumorAdvice: "集団の温度差を武器にされる関係は、温まる前に離脱が安全です。"
        ),
    ]

    static func types(matching primary: HarassmentCategory) -> [HarassmentType] {
        all.filter { $0.primaryCategories.contains(primary) }
    }
}
