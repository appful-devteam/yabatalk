import Foundation
import SwiftUI

// MARK: - Axis Score
/// 4軸のスコアを管理（点数化システム）
struct AxisScore: Codable, Equatable, Hashable {
    // MARK: - バランス軸（会話量の均衡）
    let balanceScore: Double
    let balanceRawValues: BalanceRawValues

    // MARK: - テンション軸（スタンプ・笑・絵文字の熱量）
    let tensionScore: Double
    let tensionRawValues: TensionRawValues

    // MARK: - レスポンス軸（返信ペースの相性）
    let responseScore: Double
    let responseRawValues: ResponseRawValues

    // MARK: - ワード軸（気持ちを伝える言葉の使用頻度）
    let wordScore: Double
    let wordRawValues: WordRawValues

    // MARK: - 信頼度
    let confidence: Double

    // MARK: - Computed Properties

    /// 総合スコア（4軸平均をスケーリング）
    /// 4軸平均は中央極限定理で圧縮されるため、実データ分布域[28,82]を[0,100]に展開
    var totalScore: Double {
        let rawTotal = (balanceScore + tensionScore + responseScore + wordScore) / 4.0
        return max(0, min(100, (rawTotal - 28.0) / 54.0 * 100.0))
    }

    /// タイプラベル（Type A〜E）
    var typeLabel: String {
        switch totalScore {
        case 80...: return "Type A"
        case 60..<80: return "Type B"
        case 40..<60: return "Type C"
        case 20..<40: return "Type D"
        default: return "Type E"
        }
    }

    /// タイプ画像アセット名 (アセット画像/最新アセット/new_score_images/ 由来の最新キャラ)
    var typeImageName: String {
        switch totalScore {
        case 80...: return "scorea"
        case 60..<80: return "scoreb"
        case 40..<60: return "scorec"
        case 20..<40: return "scored"
        default: return "scoree"
        }
    }

    /// スコア配列（レーダーチャート用）
    var scores: [Double] {
        [balanceScore, tensionScore, responseScore, wordScore]
    }

    /// 正規化されたスコア（0〜1）
    var normalizedScores: [Double] {
        scores.map { $0 / 100 }
    }

    /// 信頼度レベル
    var confidenceLevel: ConfidenceLevel {
        if confidence >= Constants.Analysis.ScoreThreshold.confidenceHigh {
            return .high
        } else if confidence >= Constants.Analysis.ScoreThreshold.confidenceMedium {
            return .medium
        } else {
            return .low
        }
    }

    /// 総合スコアの評価メッセージ
    var scoreMessage: String {
        switch totalScore {
        case 80...: return String(localized: "最高の相性です！", bundle: LanguageManager.appBundle)
        case 60..<80: return String(localized: "とても良い相性です", bundle: LanguageManager.appBundle)
        case 40..<60: return String(localized: "まずまずの相性です", bundle: LanguageManager.appBundle)
        case 20..<40: return String(localized: "改善の余地があります", bundle: LanguageManager.appBundle)
        default: return String(localized: "もう少し様子を見ましょう", bundle: LanguageManager.appBundle)
        }
    }

    /// 総合スコアの評価カラー
    var scoreColor: Color {
        switch totalScore {
        case 80...: return MeloColors.Status.success
        case 60..<80: return MeloColors.Brand.pinkDeep
        case 40..<60: return MeloColors.Status.warning
        default: return MeloColors.Text.secondary
        }
    }

    /// ランク連動カラー（ゲージリング用）
    var scoreRankColor: Color {
        switch totalScore {
        case 80...: return MeloColors.Status.success
        case 60..<80: return MeloColors.Member.partner
        case 40..<60: return MeloColors.Brand.pink
        case 20..<40: return MeloColors.Brand.pinkLight
        default: return MeloColors.Text.secondary
        }
    }

    /// ランク連動グラデーション（スコアテキスト用）
    var scoreRankGradient: LinearGradient {
        switch totalScore {
        case 80...: return LinearGradient(
            colors: [MeloColors.Status.success, MeloColors.Member.partner],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        case 60..<80: return LinearGradient(
            colors: [MeloColors.Member.partner, MeloColors.Member.partner],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        case 40..<60: return LinearGradient(
            colors: [MeloColors.Brand.pink, MeloColors.Brand.pinkLight],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        case 20..<40: return LinearGradient(
            colors: [MeloColors.Brand.pinkLight, MeloColors.Brand.pinkLight],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(
            colors: [MeloColors.Text.secondary, MeloColors.Gray.subButton],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// タイプのアルファベット（A〜E）
    var typeLetter: String {
        switch totalScore {
        case 80...: return "A"
        case 60..<80: return "B"
        case 40..<60: return "C"
        case 20..<40: return "D"
        default: return "E"
        }
    }

    /// 診断の特徴コメント（最大50文字）
    var diagnosisComment: String {
        let axisData: [(AxisType, Double)] = [
            (.balance, balanceScore),
            (.tension, tensionScore),
            (.response, responseScore),
            (.word, wordScore)
        ]
        let sorted = axisData.sorted { $0.1 > $1.1 }
        let strongest = sorted.first!
        let weakest = sorted.last!

        // 全軸が高い場合
        if weakest.1 >= 70 {
            return String(localized: "全ての軸がバランスよく高い、理想的な関係です", bundle: LanguageManager.appBundle)
        }

        // 全軸が低い場合
        if strongest.1 < 40 {
            return String(localized: "まだ関係が深まっていない段階かもしれません", bundle: LanguageManager.appBundle)
        }

        // 差が大きい場合: 強みと弱みの両方を言及
        let gap = strongest.1 - weakest.1
        if gap >= 30 {
            return String(format: String(localized: "%@は良好ですが、%@に課題がありそうです", bundle: LanguageManager.appBundle), strongest.0.displayName, weakest.0.displayName)
        }

        // 弱い軸に焦点
        if weakest.1 < 40 {
            return String(format: String(localized: "%@がやや低めです。%@の傾向が見られます", bundle: LanguageManager.appBundle), weakest.0.displayName, weakest.0.lowLabel)
        }

        // 強い軸に焦点
        if strongest.1 >= 70 {
            return String(format: String(localized: "%@が特に優れています。%@な関係です", bundle: LanguageManager.appBundle), strongest.0.displayName, strongest.0.highLabel)
        }

        // 中間帯
        return String(format: String(localized: "%@と%@のバランスを意識すると良さそうです", bundle: LanguageManager.appBundle), strongest.0.displayName, weakest.0.displayName)
    }

    /// 軸タイプごとのスコアを取得
    func score(for axisType: AxisType) -> Double {
        switch axisType {
        case .balance: return balanceScore
        case .tension: return tensionScore
        case .response: return responseScore
        case .word: return wordScore
        }
    }
}

// MARK: - Axis Type
enum AxisType: String, CaseIterable, Codable {
    case balance = "balance"
    case tension = "tension"
    case response = "response"
    case word = "word"

    var displayName: String {
        switch self {
        case .balance: return String(localized: "トーク量", bundle: LanguageManager.appBundle)
        case .tension: return String(localized: "会話テンション", bundle: LanguageManager.appBundle)
        case .response: return String(localized: "返信ペース", bundle: LanguageManager.appBundle)
        case .word: return String(localized: "思いやり度", bundle: LanguageManager.appBundle)
        }
    }

    var englishDisplayName: String {
        switch self {
        case .balance: return "Balance"
        case .tension: return "Voltage"
        case .response: return "Timing"
        case .word: return "Depth"
        }
    }

    var englishHighLabel: String {
        switch self {
        case .balance: return "Equal"
        case .tension: return "Voltage"
        case .response: return "Syncro"
        case .word: return "Deep"
        }
    }

    var englishLowLabel: String {
        switch self {
        case .balance: return "Gap"
        case .tension: return "Cool"
        case .response: return "Async"
        case .word: return "Light"
        }
    }

    var description: String {
        switch self {
        case .balance: return String(localized: "メッセージのやり取りの均衡", bundle: LanguageManager.appBundle)
        case .tension: return String(localized: "スタンプ・笑・絵文字の熱量", bundle: LanguageManager.appBundle)
        case .response: return String(localized: "返信ペースの相性", bundle: LanguageManager.appBundle)
        case .word: return String(localized: "気持ちを伝える言葉の頻度", bundle: LanguageManager.appBundle)
        }
    }

    var detailDescription: String {
        switch self {
        case .balance:
            return String(localized: "トーク量とは、お互いのトークやスタンプなどの送り合った回数が同じであるほど高く評価されます。これは、相手との良好なコミュニケーションを維持する指標です。スコアが高ければ、一方的なやり取りが少なく、バランスよくトークをし合えているということでしょう。", bundle: LanguageManager.appBundle)
        case .tension:
            return String(localized: "会話テンションとは、スタンプや絵文字、「笑」などの感情表現の豊かさから、2人のコミュニケーションの熱量を測る指標です。スコアが高いほど、感情豊かで温かみのあるやり取りが多いことを意味します。", bundle: LanguageManager.appBundle)
        case .response:
            return String(localized: "返信ペースとは、お互いの返信スピードのバランスを測る指標です。どちらか一方だけが早く返信するのではなく、2人の返信速度が近いほど高く評価されます。スコアが高ければ、同じくらいの熱量でやり取りしている証拠でしょう。", bundle: LanguageManager.appBundle)
        case .word:
            return String(localized: "思いやり度とは、「好き」「ありがとう」「おはよう」「頑張って」など、気持ちを伝える言葉の使用頻度を測る指標です。スコアが高いほど、言葉で気持ちをしっかり伝え合えている関係であることを示します。", bundle: LanguageManager.appBundle)
        }
    }

    var icon: String {
        switch self {
        case .balance: return "arrow.left.arrow.right"
        case .tension: return "flame.fill"
        case .response: return "timer"
        case .word: return "text.bubble"
        }
    }

    var color: Color {
        switch self {
        case .balance: return MeloColors.Axis.volume
        case .tension: return MeloColors.Axis.temperature
        case .response: return MeloColors.Axis.rhythm
        case .word: return MeloColors.Axis.word
        }
    }

    var highLabel: String {
        switch self {
        case .balance: return String(localized: "均等", bundle: LanguageManager.appBundle)
        case .tension: return String(localized: "熱い", bundle: LanguageManager.appBundle)
        case .response: return String(localized: "合っている", bundle: LanguageManager.appBundle)
        case .word: return String(localized: "豊か", bundle: LanguageManager.appBundle)
        }
    }

    var lowLabel: String {
        switch self {
        case .balance: return String(localized: "偏り", bundle: LanguageManager.appBundle)
        case .tension: return String(localized: "落ち着き", bundle: LanguageManager.appBundle)
        case .response: return String(localized: "ズレあり", bundle: LanguageManager.appBundle)
        case .word: return String(localized: "少なめ", bundle: LanguageManager.appBundle)
        }
    }

    /// スコアからグレードを算出
    static func grade(for score: Double) -> String {
        switch score {
        case 80...: return "S"
        case 60..<80: return "A"
        case 40..<60: return "B"
        case 20..<40: return "C"
        default: return "D"
        }
    }
}

// MARK: - Confidence Level
enum ConfidenceLevel: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high: return String(localized: "信頼度: 高", bundle: LanguageManager.appBundle)
        case .medium: return String(localized: "信頼度: 中", bundle: LanguageManager.appBundle)
        case .low: return String(localized: "信頼度: 低", bundle: LanguageManager.appBundle)
        }
    }

    var description: String {
        switch self {
        case .high: return String(localized: "十分なデータがあります", bundle: LanguageManager.appBundle)
        case .medium: return String(localized: "もう少しデータがあると精度が上がります", bundle: LanguageManager.appBundle)
        case .low: return String(localized: "まだ様子見かも", bundle: LanguageManager.appBundle)
        }
    }

    var color: Color {
        switch self {
        case .high: return MeloColors.Status.success
        case .medium: return MeloColors.Status.warning
        case .low: return MeloColors.Text.secondary
        }
    }
}

// MARK: - Raw Values

/// バランス軸の生データ
struct BalanceRawValues: Codable, Equatable, Hashable {
    let textSendRatio: Double
    let blockInitiationRatio: Double
    let chaseMessageDifference: Int
    let selfMessageCount: Int
    let partnerMessageCount: Int
}

/// テンション軸の生データ（スタンプ・笑・絵文字・感嘆符・メディア）
struct TensionRawValues: Codable, Equatable, Hashable {
    let stickerRate: Double
    let laughRate: Double
    let emojiRate: Double
    let exclamationRate: Double
    let mediaRate: Double
    let stickerCount: Int
    let laughCount: Int
    let emojiCount: Int
    let exclamationCount: Int
    let mediaCount: Int
}

/// レスポンス軸の生データ
struct ResponseRawValues: Codable, Equatable, Hashable {
    let selfReplyMedian: TimeInterval
    let partnerReplyMedian: TimeInterval
    let replySpeedDifference: TimeInterval
    let selfReplyCount: Int
    let partnerReplyCount: Int
    var selfReplyP25: TimeInterval?
    var selfReplyP75: TimeInterval?
    var partnerReplyP25: TimeInterval?
    var partnerReplyP75: TimeInterval?
    var compositeDifference: TimeInterval?
}

/// ワード軸の生データ（8カテゴリのワード検出率）
struct WordRawValues: Codable, Equatable, Hashable {
    let lovePhraseRate: Double
    let gratitudeRate: Double
    let careRate: Double
    let greetingRate: Double
    let encouragementRate: Double
    let affirmationRate: Double
    let missingRate: Double
    let futureRate: Double
    let totalWordHits: Int
    let totalTextMessages: Int
}

// MARK: - Legacy Compatibility
typealias VolumeRawValues = BalanceRawValues
