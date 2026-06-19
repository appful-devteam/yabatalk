import Foundation

/// 全タイプ名カタログ。docs/spec/diagnosis-logic.md §6 と整合。
enum HarassmentTypeCatalog {

    static let all: [HarassmentType] = powerTypes + sexualTypes + moralTypes + otherTypes

    // MARK: - パワハラ系
    private static let powerTypes: [HarassmentType] = [
        HarassmentType(
            id: "boss_dragon",
            emoji: "🐉",
            typeName: String(localized: "上司ドラゴン型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: String(localized: "立場差と評価・仕事を使った圧", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "肩書きを背負って炎を吐くタイプ。逃げ場が狭くなる会話です。", bundle: LanguageManager.appBundle),
                String(localized: "立場の重さで殴ってくるので、防御が間に合いません。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.dominance, .workEvaluation, .disadvantageThreat],
            darkHumorAdvice: String(localized: "肩書きと指導の距離が遠すぎるとドラゴンになります。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "indoctrination_devil",
            emoji: "👹",
            typeName: String(localized: "指導の皮をかぶった鬼型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: String(localized: "指導風の人格否定・精神的攻撃", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "これは指導ではなく、メンタルに紙やすりをかけるタイプの会話です。", bundle: LanguageManager.appBundle),
                String(localized: "指導の名のもとに、人格をすり減らしにきています。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.personalityDenial, .abilityDenial, .workEvaluation, .dominance],
            darkHumorAdvice: String(localized: "本当に必要な指導は、人格を燃やさなくてもできます。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "rank_swinger",
            emoji: "🪓",
            typeName: String(localized: "立場ブンブン丸型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: String(localized: "権限を振りかざす、不利益示唆", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "権限を振り回すたびに、相手の安全圏が削れていきます。", bundle: LanguageManager.appBundle),
                String(localized: "肩書きで人を黙らせるタイプ。会話の往復が成立していません。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.dominance, .disadvantageThreat, .refusalImpossible],
            darkHumorAdvice: String(localized: "権限は振り回すものではなく、機能させるものです。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "mental_mower",
            emoji: "🌱",
            typeName: String(localized: "メンタル草刈り機型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power, .moral],
            subCategories: [],
            structureSummary: String(localized: "人格否定・能力否定・自己肯定感削り", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "話すたびに自己肯定感が一段ずつ刈り取られていきます。", bundle: LanguageManager.appBundle),
                String(localized: "丁寧に見えて、芯のところを削ってきます。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.personalityDenial, .abilityDenial, .existenceDenial],
            darkHumorAdvice: String(localized: "自己肯定感を草扱いされる関係は、長続きしない方が健全です。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "task_dumper",
            emoji: "📦",
            typeName: String(localized: "仕事押しつけ倉庫型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: String(localized: "過大要求・無理な期限・休日深夜対応", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "段ボールごと仕事を投げてくるタイプ。受け取る前提で会話が進みます。", bundle: LanguageManager.appBundle),
                String(localized: "期限と量の感覚がバグっているので、こちらが壊れる前提です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.excessiveDemand, .workEvaluation, .refusalImpossible],
            darkHumorAdvice: String(localized: "倉庫業務は本来、人間に直接投げるものではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "place_revoker",
            emoji: "🚪",
            typeName: String(localized: "居場所はく奪マン型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power],
            subCategories: [],
            structureSummary: String(localized: "「来なくていい」「外す」など所属否定", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "出口を見せながら従わせるタイプ。残るのも出るのもこちらの負担です。", bundle: LanguageManager.appBundle),
                String(localized: "ドアを開けたまま指示してくる、心理的に逃げにくい構造です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.existenceDenial, .disadvantageThreat, .dominance],
            darkHumorAdvice: String(localized: "居場所をちらつかせる人と居場所を共有しなくて大丈夫です。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "info_freezer",
            emoji: "🧊",
            typeName: String(localized: "共有外し冷凍庫型", bundle: LanguageManager.appBundle),
            primaryCategories: [.power, .other],
            subCategories: [.grouping],
            structureSummary: String(localized: "情報共有外し・孤立化・無視指示", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "情報の流れから少しずつ凍結させていくタイプです。", bundle: LanguageManager.appBundle),
                String(localized: "見えないところで距離を取られる、じわじわ冷える構造です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.groupExclusion, .dominance, .workEvaluation],
            darkHumorAdvice: String(localized: "情報共有は感情の天気予報ではないので、ムラがあると困ります。", bundle: LanguageManager.appBundle)
        ),
    ]

    // MARK: - セクハラ系
    private static let sexualTypes: [HarassmentType] = [
        HarassmentType(
            id: "distance_bugged_uncle",
            emoji: "🫥",
            typeName: String(localized: "距離感バグおじさん型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: String(localized: "身体・恋愛への不要な踏み込み", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "距離感の解像度が壊れているタイプ。こちらの安全圏が狭まります。", bundle: LanguageManager.appBundle),
                String(localized: "親しみのつもりが、業務上不要な踏み込みになっています。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.sexualContext, .privacyIntrusion],
            darkHumorAdvice: String(localized: "親しみと距離感のバグはアップデートで直しましょう。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "hidden_motive_skeleton",
            emoji: "💀",
            typeName: String(localized: "下心スケルトン型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: String(localized: "下心が透ける誘い・性的ニュアンス", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "オブラートが薄すぎて、中身が透けています。", bundle: LanguageManager.appBundle),
                String(localized: "親しみの皮の下から、別の意図がはっきり見えます。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.sexualContext, .mockingLaughter],
            darkHumorAdvice: String(localized: "下心は装飾しても重量は減りません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "drink_zombie",
            emoji: "🧟",
            typeName: String(localized: "飲み誘いゾンビ型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: String(localized: "拒否後も続く誘い、執拗な連絡", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "断っても断っても誘いが復活してくるタイプです。", bundle: LanguageManager.appBundle),
                String(localized: "「やめて」を聞いたあとから、誘いの回数が増えています。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.sexualContext, .boundaryViolation, .persistentRepetition],
            darkHumorAdvice: String(localized: "誘いは何度も復活させるものではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "quota_bundle_seller",
            emoji: "🎁",
            typeName: String(localized: "評価と下心の抱き合わせ販売型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual, .power],
            subCategories: [],
            structureSummary: String(localized: "性的・恋愛的要求と評価の結合", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "下心と評価がセット販売されています。返品してください。", bundle: LanguageManager.appBundle),
                String(localized: "業務文脈に恋愛を混ぜ込む、抱き合わせ販売型の会話です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.quotaPairing, .sexualContext, .workEvaluation, .disadvantageThreat],
            darkHumorAdvice: String(localized: "冗談に見せた圧は、冗談よりだいぶ重いです。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "outfit_check_yokai",
            emoji: "👗",
            typeName: String(localized: "服装チェック妖怪型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual, .other],
            subCategories: [.gender],
            structureSummary: String(localized: "服装・身体への過剰な言及", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "毎回服装に評価を入れてくる、視線の置き場がバグった会話です。", bundle: LanguageManager.appBundle),
                String(localized: "服装＝コミュニケーションだと思っているタイプ。境界が薄いです。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.sexualContext, .roleStereotype],
            darkHumorAdvice: String(localized: "服装は天気の話ではないので、毎回採点しなくて大丈夫です。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "sticky_compliment",
            emoji: "🧴",
            typeName: String(localized: "ねっとり褒め殺し型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual],
            subCategories: [],
            structureSummary: String(localized: "褒めている風の性的評価", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "褒めているように見えて、評価の角度が私的すぎるタイプです。", bundle: LanguageManager.appBundle),
                String(localized: "褒め言葉の中に、業務上不要な観察が混ざっています。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.sexualContext, .mockingLaughter],
            darkHumorAdvice: String(localized: "業務評価は褒め殺しの形式を取らないものです。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "haha_humidifier",
            emoji: "🫧",
            typeName: String(localized: "笑でごまかす湿気型", bundle: LanguageManager.appBundle),
            primaryCategories: [.sexual, .moral],
            subCategories: [],
            structureSummary: String(localized: "「笑」で圧や性的発言を軽く見せる", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "「笑」で空気を軽くしているように見えて、内容は重いです。", bundle: LanguageManager.appBundle),
                String(localized: "ジョーク風の包装紙が、中身の重さを変えていません。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.mockingLaughter, .sexualContext, .disadvantageThreat],
            darkHumorAdvice: String(localized: "「w」「笑」を足しても、不快の総量は変わりません。", bundle: LanguageManager.appBundle)
        ),
    ]

    // MARK: - モラハラ系
    private static let moralTypes: [HarassmentType] = [
        HarassmentType(
            id: "guilt_artisan",
            emoji: "🧵",
            typeName: String(localized: "罪悪感職人型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: String(localized: "相手に罪悪感を背負わせる", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "罪悪感を縫い付けてくるタイプ。会話のたびに重くなります。", bundle: LanguageManager.appBundle),
                String(localized: "感情の責任分担が完全にこちら側に寄っています。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.guiltManipulation, .intimateRelationship],
            darkHumorAdvice: String(localized: "感情の責任は一人で背負うものでも、押し付けるものでもありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "emotion_hostage",
            emoji: "🧸",
            typeName: String(localized: "感情人質型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: String(localized: "愛情・関係継続を条件に支配", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "「好き」を担保に、相手の自由時間を差し押さえています。", bundle: LanguageManager.appBundle),
                String(localized: "愛情を条件付き販売しているタイプの関係です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.intimateRelationship, .guiltManipulation, .refusalImpossible, .monitoringControl],
            darkHumorAdvice: String(localized: "恋愛はログインボーナスではないので、即レス義務はありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "memory_fraud_ghost",
            emoji: "👻",
            typeName: String(localized: "記憶改ざん妖怪型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: String(localized: "ガスライティング・感覚否定", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "覚えてないのではなく、こちらの記憶を書き換えにきています。", bundle: LanguageManager.appBundle),
                String(localized: "出来事ではなく、こちらの感覚そのものを否定してくるタイプです。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.gaslighting, .guiltManipulation],
            darkHumorAdvice: String(localized: "あなたの記憶は、相手の都合で書き換わるものではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "read_watching_crow",
            emoji: "🐦‍⬛",
            typeName: String(localized: "既読監視カラス型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral, .other],
            subCategories: [.digital],
            structureSummary: String(localized: "既読責め・返信強要・監視", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "既読の有無で機嫌が決まるタイプ。返信は人質です。", bundle: LanguageManager.appBundle),
                String(localized: "通知を見るたびに、安全圏が削られていく構造です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.monitoringControl, .persistentRepetition, .guiltManipulation],
            darkHumorAdvice: String(localized: "既読は感情の天気予報ではないので、機嫌の根拠にできません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "sulk_blackhole",
            emoji: "🕳",
            typeName: String(localized: "不機嫌ブラックホール型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: String(localized: "沈黙・不機嫌で相手を操作", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "不機嫌で空気の重力を上げてくるタイプの会話です。", bundle: LanguageManager.appBundle),
                String(localized: "沈黙を武器にしているので、こちらの呼吸が浅くなります。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.guiltManipulation, .intimateRelationship],
            darkHumorAdvice: String(localized: "沈黙は感情の説明から逃げる便利な道具にされがちです。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "restraint_overkill",
            emoji: "🔒",
            typeName: String(localized: "束縛セキュリティ過剰型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: String(localized: "位置情報・写真要求・交友関係制限", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "安全のためと言いつつ、行動範囲を制限する構造です。", bundle: LanguageManager.appBundle),
                String(localized: "信頼のなさをセキュリティ強化で覆っているタイプです。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.monitoringControl, .privacyIntrusion, .intimateRelationship],
            darkHumorAdvice: String(localized: "セキュリティは行動制限ではなく、信頼関係で組むものです。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "victim_position_lock",
            emoji: "🎭",
            typeName: String(localized: "被害者ポジション固定型", bundle: LanguageManager.appBundle),
            primaryCategories: [.moral],
            subCategories: [],
            structureSummary: String(localized: "自分を被害者にして相手を責める", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "常に被害者席に座って、加害の負担をこちらに置いてくるタイプです。", bundle: LanguageManager.appBundle),
                String(localized: "立場のすり替えが起きているので、責任の重心が常にずれます。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.guiltManipulation, .gaslighting, .intimateRelationship],
            darkHumorAdvice: String(localized: "被害者と加害者の席は、自分で勝手に決めるものではありません。", bundle: LanguageManager.appBundle)
        ),
    ]

    // MARK: - その他系
    private static let otherTypes: [HarassmentType] = [
        HarassmentType(
            id: "gender_fossil",
            emoji: "🦴",
            typeName: String(localized: "ジェンダー化石型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.gender],
            structureSummary: String(localized: "性別役割の押し付け", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "アップデートが止まっている価値観をそのまま押し付けてくるタイプです。", bundle: LanguageManager.appBundle),
                String(localized: "性別を理由にした要求が、令和を未読のまま届いています。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.roleStereotype, .dominance],
            darkHumorAdvice: String(localized: "アップデートしていない価値観は、押し付け用ではなく博物館用です。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "drink_primitive",
            emoji: "🍺",
            typeName: String(localized: "飲み会原始人型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.alcohol],
            structureSummary: String(localized: "飲酒強要・拒否への非難", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "飲める＝偉い、で物事を片付けてくるタイプの会話です。", bundle: LanguageManager.appBundle),
                String(localized: "場のテンションを飲酒で揃えようとする、原始的な圧の構造です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.alcoholCoercion, .dominance],
            darkHumorAdvice: String(localized: "飲める量で人を評価する時代は、本当にもう終わっています。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "customer_firebomb",
            emoji: "🔥",
            typeName: String(localized: "カスハラ火炎瓶型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.customer],
            structureSummary: String(localized: "客・取引先からの過剰要求・脅し", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "客の立場で爆弾を投げてくるタイプ。要求が燃料に変わっています。", bundle: LanguageManager.appBundle),
                String(localized: "SNS・本社・誠意のワードを武器に切り出してくる構造です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.customerAggression, .disadvantageThreat],
            darkHumorAdvice: String(localized: "正当な要求は、火炎瓶にしなくても伝わります。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "privacy_thief",
            emoji: "🕵️",
            typeName: String(localized: "プライバシー泥棒型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other, .moral],
            subCategories: [.privacy],
            structureSummary: String(localized: "私生活への過度な干渉", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "プライバシーの境界線を、軽い質問の顔で越えてきます。", bundle: LanguageManager.appBundle),
                String(localized: "私生活の在庫管理をしようとしてくるタイプの会話です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.privacyIntrusion, .monitoringControl],
            darkHumorAdvice: String(localized: "プライバシーは差し出す前提のメニューではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "lab_king",
            emoji: "🎓",
            typeName: String(localized: "研究室の王様型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.academic],
            structureSummary: String(localized: "成績・推薦・卒業権限を使った圧", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "学業の権限を切り札に出してくる、教室サイズの絶対王政です。", bundle: LanguageManager.appBundle),
                String(localized: "推薦・卒業をちらつかせる、出口を握って指示するタイプです。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.academicPower, .dominance, .disadvantageThreat],
            darkHumorAdvice: String(localized: "学業の権限は、相手の人生を握る道具ではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "life_event_stomper",
            emoji: "🍼",
            typeName: String(localized: "ライフイベント踏みつけ型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.maternity],
            structureSummary: String(localized: "妊娠・育児・介護への不利益示唆", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "妊娠・育児・介護を「評価のマイナス材料」に変換してくるタイプです。", bundle: LanguageManager.appBundle),
                String(localized: "ライフイベントを軽くまたいで、評価軸を変えてくる構造です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.maternityPenalty, .disadvantageThreat, .roleStereotype],
            darkHumorAdvice: String(localized: "ライフイベントは、評価で踏みつぶしていいものではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "screenshot_bomb",
            emoji: "📢",
            typeName: String(localized: "スクショ拡散爆弾型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.digital],
            structureSummary: String(localized: "晒し・スクショ悪用・拡散脅迫", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "拡散をちらつかせて従わせる、デジタル時代型の脅しです。", bundle: LanguageManager.appBundle),
                String(localized: "スクショ・晒しのワードで黙らせにくるタイプの会話です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.disadvantageThreat, .persistentRepetition, .customerAggression],
            darkHumorAdvice: String(localized: "拡散を交渉カードに使うのは、対等な関係ではありません。", bundle: LanguageManager.appBundle)
        ),
        HarassmentType(
            id: "group_freeze_beam",
            emoji: "🧊",
            typeName: String(localized: "グループ冷凍ビーム型", bundle: LanguageManager.appBundle),
            primaryCategories: [.other],
            subCategories: [.grouping],
            structureSummary: String(localized: "無視・仲間外れ・グループ内晒し", bundle: LanguageManager.appBundle),
            catchCopyTemplates: [
                String(localized: "グループの空気を凍らせて、特定の人だけ寒くしてくる構造です。", bundle: LanguageManager.appBundle),
                String(localized: "「無視でいい」を共通指示にしてくる、集団的な排除の形です。", bundle: LanguageManager.appBundle),
            ],
            triggerFactors: [.groupExclusion, .dominance],
            darkHumorAdvice: String(localized: "集団の温度差を武器にされる関係は、温まる前に離脱が安全です。", bundle: LanguageManager.appBundle)
        ),
    ]

    static func types(matching primary: HarassmentCategory) -> [HarassmentType] {
        all.filter { $0.primaryCategories.contains(primary) }
    }
}
