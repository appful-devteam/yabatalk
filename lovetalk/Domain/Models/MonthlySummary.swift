import Foundation

// MARK: - Monthly Summary
/// 月ごとの会話サマリー
struct MonthlySummary: Identifiable, Codable {
    let id: UUID
    let year: Int
    let month: Int
    let summary: String
    let messageCount: Int
    let generatedAt: Date
    
    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        summary: String,
        messageCount: Int,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.summary = summary
        self.messageCount = messageCount
        self.generatedAt = generatedAt
    }
    
    /// 表示用の年月文字列（表示言語に応じたフォーマット）
    var displayYearMonth: String {
        if LanguageManager.isJapanese {
            return "\(year)年\(month)月"
        }
        guard month >= 1, month <= 12 else { return "\(year)/\(month)" }
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        let monthName = formatter.shortMonthSymbols[month - 1].capitalized
        return "\(monthName) \(year)"
    }
    
    /// ソート用の値
    var sortKey: Int {
        year * 100 + month
    }
}

// MARK: - Summary State
/// サマリーの生成状態
enum SummaryState {
    case idle
    case loading
    case loaded([MonthlySummary])
    case error(String)
}

