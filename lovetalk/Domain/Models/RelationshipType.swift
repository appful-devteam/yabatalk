import Foundation

// MARK: - Relationship Type
/// 16タイプの関係性分類
enum RelationshipType: String, CaseIterable {
    case BWSF, BWSL, BWJF, BWJL
    case BCSF, BCSL, BCJF, BCJL
    case UWSF, UWSL, UWJF, UWJL
    case UCSF, UCSL, UCJF, UCJL

    var tagline: String {
        switch self {
        case .BWSF: return String(localized: "宇宙一、贅沢な共鳴", bundle: LanguageManager.appBundle)
        case .BWSL: return String(localized: "最も温かい、日常の魔法", bundle: LanguageManager.appBundle)
        case .BWJF: return String(localized: "燃える情熱、終わらない夏", bundle: LanguageManager.appBundle)
        case .BWJL: return String(localized: "静かに支え合う、雨上がりの虹", bundle: LanguageManager.appBundle)
        case .BCSF: return String(localized: "風に揺れる、心地よい午後", bundle: LanguageManager.appBundle)
        case .BCSL: return String(localized: "深夜に語る、大人の共鳴", bundle: LanguageManager.appBundle)
        case .BCJF: return String(localized: "自由に弾ける、虹色の時間", bundle: LanguageManager.appBundle)
        case .BCJL: return String(localized: "凍てつく中で灯る、確かな温もり", bundle: LanguageManager.appBundle)
        case .UWSF: return String(localized: "太陽みたいに、いつもそばに", bundle: LanguageManager.appBundle)
        case .UWSL: return String(localized: "雨音の中に聞こえる、君の声", bundle: LanguageManager.appBundle)
        case .UWJF: return String(localized: "一夜限りの、魂の饗宴", bundle: LanguageManager.appBundle)
        case .UWJL: return String(localized: "帰る場所がある、その幸せ", bundle: LanguageManager.appBundle)
        case .UCSF: return String(localized: "2人だけの、とっておきの時間", bundle: LanguageManager.appBundle)
        case .UCSL: return String(localized: "謎めいた魅力に引き込まれて", bundle: LanguageManager.appBundle)
        case .UCJF: return String(localized: "運命が回す、2人のルーレット", bundle: LanguageManager.appBundle)
        case .UCJL: return String(localized: "星空の下、独りじゃない夜", bundle: LanguageManager.appBundle)
        }
    }

    var displayName: String {
        switch self {
        case .BWSF: return String(localized: "最高に満たされた関係", bundle: LanguageManager.appBundle)
        case .BWSL: return String(localized: "穏やかで温かい関係", bundle: LanguageManager.appBundle)
        case .BWJF: return String(localized: "情熱的で刺激的な関係", bundle: LanguageManager.appBundle)
        case .BWJL: return String(localized: "自由で信頼し合う関係", bundle: LanguageManager.appBundle)
        case .BCSF: return String(localized: "誠実で丁寧な関係", bundle: LanguageManager.appBundle)
        case .BCSL: return String(localized: "知的で落ち着いた関係", bundle: LanguageManager.appBundle)
        case .BCJF: return String(localized: "型にはまらない関係", bundle: LanguageManager.appBundle)
        case .BCJL: return String(localized: "静かに寄り添う関係", bundle: LanguageManager.appBundle)
        case .UWSF: return String(localized: "愛情深く尽くし合う関係", bundle: LanguageManager.appBundle)
        case .UWSL: return String(localized: "そっと寄り添う関係", bundle: LanguageManager.appBundle)
        case .UWJF: return String(localized: "感情がぶつかり合う関係", bundle: LanguageManager.appBundle)
        case .UWJL: return String(localized: "不器用だけど温かい関係", bundle: LanguageManager.appBundle)
        case .UCSF: return String(localized: "マイペースで心地よい関係", bundle: LanguageManager.appBundle)
        case .UCSL: return String(localized: "深くて謎めいた関係", bundle: LanguageManager.appBundle)
        case .UCJF: return String(localized: "予測不能でスリルな関係", bundle: LanguageManager.appBundle)
        case .UCJL: return String(localized: "言葉を超えた関係", bundle: LanguageManager.appBundle)
        }
    }

    var description: String {
        switch self {
        case .BWSF:
            return String(localized: "あなたたちは、互いの存在が鏡のように響き合う「奇跡的な同期」の中にいます。言葉にしなくても伝わる空気感と、言葉にすることで加速する熱量の両方を手に入れており、コミュニティの中でも「誰も入り込めない最強の二人」として羨望の的になっているでしょう。何気ない一言にもお互い反応し合えるリズムは、長く一緒にいる二人だけが持てる宝物です。", bundle: LanguageManager.appBundle)
        case .BWSL:
            return String(localized: "お互いの感情を大切にしながら、安定したペースで関係を育てている二人。言葉の温かさと気遣いが自然に行き交うので、特別なイベントがなくても日常そのものが心地よい時間になっています。気を張らずに本音で話せる安心感があり、長く一緒にいるほど絆が深まる、地に足のついたカップルです。", bundle: LanguageManager.appBundle)
        case .BWJF:
            return String(localized: "情熱的で勢いのある二人。会話のテンポが良く、感情表現も豊かで、お互いを乗せ合いながら毎日を盛り上げています。新しいことへの好奇心を共有し、刺激的な経験を一緒に取り込んでいくスタイルなので、関係に飽きが来ない代わりに消耗もしやすい、エネルギッシュなカップルです。", bundle: LanguageManager.appBundle)
        case .BWJL:
            return String(localized: "穏やかな信頼関係の中で、互いの世界を尊重し合う二人。普段はそれぞれのペースで自由に過ごしながら、必要な時にはすっと手を差し伸べる優しさが関係の土台になっています。べったり依存し合うのではなく、自立した個人同士が選び合っているからこそ、長く心地よく続いていく成熟した形のカップルです。", bundle: LanguageManager.appBundle)
        case .BCSF:
            return String(localized: "落ち着いた空気感の中にも確かな絆がある二人。会話の量より質を大切にし、一つひとつのやり取りに丁寧さと温かみを込めています。派手なリアクションは少なくても、相手の言葉をしっかり受け止めて返すスタイルなので、お互いに「ちゃんと向き合ってもらえている」という安心感を持って関係を育てているカップルです。", bundle: LanguageManager.appBundle)
        case .BCSL:
            return String(localized: "深い理解と静かな共感で結ばれた二人。言葉数は多くなくても、互いの気持ちを汲み取る力に長けており、目線や短いひと言だけで通じ合えます。表面的な盛り上がりよりも、本質的な部分でのつながりを大切にしているからこそ、時間が経つほど絆の重みが増していく、大人びた関係性のカップルです。", bundle: LanguageManager.appBundle)
        case .BCJF:
            return String(localized: "自由でクリエイティブな関係。世間の「カップルらしさ」の枠にとらわれず、二人だけの独特なコミュニケーションスタイルを楽しんでいます。突拍子もないアイデアやノリで盛り上がれる柔軟さが魅力で、毎日同じ景色にならないからこそ常に新鮮さが続く、型にはまらないカップルです。", bundle: LanguageManager.appBundle)
        case .BCJL:
            return String(localized: "互いの空間を大切にしながら、深い部分でつながっている二人。べったりした距離感は好まず、それぞれの時間を尊重し合うことで成熟した信頼関係を築いています。静かな時間を共有することに価値を感じ、無言で同じ空間にいるだけでも満たされる、落ち着いた大人のカップルです。", bundle: LanguageManager.appBundle)
        case .UWSF:
            return String(localized: "一方がリードし、もう一方がサポートする、役割が自然に分かれているバランスの取れた関係。感情豊かで温度の高いやり取りの中で、お互いに安心感を作り合っています。与える側と受け取る側がはっきりしているからこそ機能している関係なので、たまに役割を交換してみると更に強く長く続く、思いやりの濃いカップルです。", bundle: LanguageManager.appBundle)
        case .UWSL:
            return String(localized: "感性が豊かで、ロマンチックな空気を大切にする二人。相手への思いやりが会話の端々に表れていて、雨の日にそっと傘を差し出すような優しさが二人の関係の核になっています。激しく言葉をぶつけ合うタイプではないので、本音を言葉にする勇気が増えるほど、より深く満たされる関係になっていくカップルです。", bundle: LanguageManager.appBundle)
        case .UWJF:
            return String(localized: "情熱のままに突き進む二人。テンションの高い会話が特徴で、一緒にいると時間があっという間に過ぎていきます。喜びも不満もストレートにぶつけ合うので、感情の波は大きい代わりに本音の関係を築けています。穏やかな凪の時間を二人で楽しめるようになると、一夜限りの熱が永遠に灯り続ける、燃えるカップルです。", bundle: LanguageManager.appBundle)
        case .UWJL:
            return String(localized: "日常の何気ないやり取りの中に愛情を感じられる関係。「おかえり」「いってらっしゃい」のひと言の温かさを知っている二人で、派手な言葉や劇的な出来事がなくても、毎日の小さな積み重ねが安心の源になっています。不器用な伝え方でも気持ちはちゃんと届いている、確かに帰れる場所のあるカップルです。", bundle: LanguageManager.appBundle)
        case .UCSF:
            return String(localized: "マイペースだけど確かな愛情がある二人。それぞれの時間や趣味を大切にしながら、心地よい距離感で寄り添っています。同じカフェで別々の本を読むような並行した過ごし方が落ち着く一方で、いざという時にはちゃんと言葉で気持ちを伝え合える、自立と愛情が共存しているカップルです。", bundle: LanguageManager.appBundle)
        case .UCSL:
            return String(localized: "深い知性と静かな情熱で結ばれた二人。表面的な会話は得意ではありませんが、稀に交わす本音の言葉には重みと真実があり、本質的な部分でのつながりを大切にしています。相手のミステリアスな部分にも惹かれ続ける、奥行きのあるカップルです。", bundle: LanguageManager.appBundle)
        case .UCJF:
            return String(localized: "予測不能な展開を楽しむ二人。普段はクールに見えるのに、ふとした瞬間に感情が溢れ出すギャップが二人らしさです。互いを刺激し合い、新しい発見が絶えないスリリングな関係なので、刺激的な代わりに不安定にもなりがち。一つだけ「揺るがない約束」を持つと、嵐の中でも灯台のように関係を導いてくれる、ドラマチックなカップルです。", bundle: LanguageManager.appBundle)
        case .UCJL:
            return String(localized: "内省的で、互いの内面世界を深く理解し合う二人。連絡の頻度は多くなくても、同じ星空を別々の場所から見上げているような静かな共感で結ばれています。言葉にしなくても通じ合える特別な絆があり、人に説明できない二人だけの世界を持っているカップルです。", bundle: LanguageManager.appBundle)
        }
    }

    /// タイプ別マスコット画像名。
    /// アセット名は日本語のタイプ名そのまま (例: 「最高に満たされた関係」)。
    /// → タイプ名と画像ファイル名が一致しているので、コードと画像の対応関係が一目でわかる。
    var imageName: String {
        // displayName と完全一致するアセットを返す。
        // 多言語化していてもキー (タイプ名) は日本語固定で使うため、Locale 非依存で参照する。
        switch self {
        case .BWSF: return "最高に満たされた関係"
        case .BWSL: return "穏やかで温かい関係"
        case .BWJF: return "情熱的で刺激的な関係"
        case .BWJL: return "自由で信頼し合う関係"
        case .BCSF: return "誠実で丁寧な関係"
        case .BCSL: return "知的で落ち着いた関係"
        case .BCJF: return "型にはまらない関係"
        case .BCJL: return "静かに寄り添う関係"
        case .UWSF: return "愛情深く尽くし合う関係"
        case .UWSL: return "そっと寄り添う関係"
        case .UWJF: return "感情がぶつかり合う関係"
        case .UWJL: return "不器用だけど温かい関係"
        case .UCSF: return "マイペースで心地よい関係"
        case .UCSL: return "深くて謎めいた関係"
        case .UCJF: return "予測不能でスリルな関係"
        case .UCJL: return "言葉を超えた関係"
        }
    }

    /// 軸スコアからRelationshipTypeを判定
    static func from(axisScore: AxisScore) -> RelationshipType {
        let b = axisScore.balanceScore >= 50 ? "B" : "U"
        let w = axisScore.tensionScore >= 50 ? "W" : "C"
        let s = axisScore.responseScore >= 50 ? "S" : "J"
        let f = axisScore.wordScore >= 50 ? "F" : "L"
        let code = b + w + s + f
        return RelationshipType(rawValue: code) ?? .BWSF
    }

    /// 各軸のHigh/Lowラベル
    static func axisHighLowLabels(for axisScore: AxisScore) -> [String] {
        return [
            axisScore.balanceScore >= 50 ? "High" : "Low",
            axisScore.tensionScore >= 50 ? "High" : "Low",
            axisScore.responseScore >= 50 ? "High" : "Low",
            axisScore.wordScore >= 50 ? "High" : "Low"
        ]
    }

    /// HHHH形式のコード表示
    static func highLowCode(for axisScore: AxisScore) -> String {
        let labels = axisHighLowLabels(for: axisScore)
        return labels.map { String($0.prefix(1)) }.joined()
    }
}
