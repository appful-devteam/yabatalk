import Foundation

extension Date {
    // MARK: - Formatting

    /// 「2024年1月15日」形式
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = LanguageManager.isJapanese ? "yyyy年M月d日" : "MMM d, yyyy"
        return formatter.string(from: self)
    }

    /// 「1/15」形式
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "M/d"
        return formatter.string(from: self)
    }

    /// 「1/15(月)」形式
    var shortDateWithWeekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = LanguageManager.isJapanese ? "M/d(E)" : "M/d (E)"
        return formatter.string(from: self)
    }

    /// 「21:30」形式
    var timeString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "H:mm"
        return formatter.string(from: self)
    }

    /// 「2024/1/15 21:30」形式
    var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "yyyy/M/d H:mm"
        return formatter.string(from: self)
    }

    /// 相対的な日時表現（「今日」「昨日」「3日前」など）
    var relativeString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            return String(localized: "今日", bundle: LanguageManager.appBundle)
        } else if calendar.isDateInYesterday(self) {
            return String(localized: "昨日", bundle: LanguageManager.appBundle)
        } else {
            let components = calendar.dateComponents([.day], from: self, to: now)
            if let days = components.day, days < 7 {
                return String(format: String(localized: "%d日前", bundle: LanguageManager.appBundle), days)
            } else {
                return shortDateWithWeekdayString
            }
        }
    }

    // MARK: - Components

    /// 時間（0-23）
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// 分
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }

    /// 曜日（1=日曜, 7=土曜）
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// 曜日名
    var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }

    // MARK: - Time Periods

    /// 夜間判定（22:00-26:00 = 22:00-02:00）
    var isNightTime: Bool {
        let hour = self.hour
        return hour >= 22 || hour < 2
    }

    /// 深夜判定（0:00-5:00）
    var isLateNight: Bool {
        let hour = self.hour
        return hour >= 0 && hour < 5
    }

    /// 時間帯カテゴリ
    enum TimePeriod: String, CaseIterable {
        case lateNight = "lateNight"
        case morning = "morning"
        case daytime = "daytime"
        case evening = "evening"
        case night = "night"

        var displayName: String {
            switch self {
            case .lateNight: return String(localized: "深夜", bundle: LanguageManager.appBundle)
            case .morning: return String(localized: "朝", bundle: LanguageManager.appBundle)
            case .daytime: return String(localized: "日中", bundle: LanguageManager.appBundle)
            case .evening: return String(localized: "夕方", bundle: LanguageManager.appBundle)
            case .night: return String(localized: "夜", bundle: LanguageManager.appBundle)
            }
        }

        var hourRange: ClosedRange<Int> {
            switch self {
            case .lateNight: return 0...4
            case .morning: return 5...9
            case .daytime: return 10...17
            case .evening: return 18...21
            case .night: return 22...23
            }
        }
    }

    var timePeriod: TimePeriod {
        let hour = self.hour
        switch hour {
        case 0..<5: return .lateNight
        case 5..<10: return .morning
        case 10..<18: return .daytime
        case 18..<22: return .evening
        default: return .night
        }
    }

    // MARK: - Calculations

    /// 日付の開始（00:00:00）
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// 日付の終了（23:59:59）
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// n日前
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    /// 2つの日付間の日数
    func daysBetween(_ other: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startOfDay, to: other.startOfDay)
        return abs(components.day ?? 0)
    }

    /// 2つの日付間の時間差（秒）
    func secondsBetween(_ other: Date) -> TimeInterval {
        abs(self.timeIntervalSince(other))
    }

    /// 2つの日付間の分差
    func minutesBetween(_ other: Date) -> Int {
        Int(secondsBetween(other) / 60)
    }

    // MARK: - Parsing

    /// LINE履歴の日付行をパース（例: "2024/1/15(月)"）
    static func fromLineDateLine(_ string: String) -> Date? {
        let pattern = #"(\d{4})/(\d{1,2})/(\d{1,2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }

        guard let yearRange = Range(match.range(at: 1), in: string),
              let monthRange = Range(match.range(at: 2), in: string),
              let dayRange = Range(match.range(at: 3), in: string),
              let year = Int(string[yearRange]),
              let month = Int(string[monthRange]),
              let day = Int(string[dayRange]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0

        return Calendar.current.date(from: components)
    }

    /// LINE履歴の時刻をパース（例: "21:30"）
    static func fromLineTimePart(_ timeString: String, baseDate: Date) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }
}
