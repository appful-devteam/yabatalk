import Foundation

// MARK: - Detailed Statistics
/// 詳細統計データ
struct DetailedStatistics: Codable, Equatable {
    let callStatistics: CallStatistics
    let textAnalysis: TextAnalysis
    let phraseAnalysis: PhraseAnalysis
    let sentimentAnalysis: SentimentAnalysis
    let loveWordsAnalysis: LoveWordsAnalysis
    let habitsStatistics: HabitsStatistics?
    let actionsStatistics: ActionsStatistics?
    let recordsStatistics: RecordsStatistics?

    // カスタムデコーダ：古いデータとの互換性を保つ
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        callStatistics = try container.decode(CallStatistics.self, forKey: .callStatistics)
        textAnalysis = try container.decode(TextAnalysis.self, forKey: .textAnalysis)
        phraseAnalysis = try container.decode(PhraseAnalysis.self, forKey: .phraseAnalysis)
        sentimentAnalysis = try container.decode(SentimentAnalysis.self, forKey: .sentimentAnalysis)
        loveWordsAnalysis = try container.decode(LoveWordsAnalysis.self, forKey: .loveWordsAnalysis)
        // オプショナルフィールド：キーが存在しない場合はnilにする
        habitsStatistics = try container.decodeIfPresent(HabitsStatistics.self, forKey: .habitsStatistics)
        actionsStatistics = try container.decodeIfPresent(ActionsStatistics.self, forKey: .actionsStatistics)
        recordsStatistics = try container.decodeIfPresent(RecordsStatistics.self, forKey: .recordsStatistics)
    }

    // 通常のイニシャライザ
    init(
        callStatistics: CallStatistics,
        textAnalysis: TextAnalysis,
        phraseAnalysis: PhraseAnalysis,
        sentimentAnalysis: SentimentAnalysis,
        loveWordsAnalysis: LoveWordsAnalysis,
        habitsStatistics: HabitsStatistics?,
        actionsStatistics: ActionsStatistics?,
        recordsStatistics: RecordsStatistics?
    ) {
        self.callStatistics = callStatistics
        self.textAnalysis = textAnalysis
        self.phraseAnalysis = phraseAnalysis
        self.sentimentAnalysis = sentimentAnalysis
        self.loveWordsAnalysis = loveWordsAnalysis
        self.habitsStatistics = habitsStatistics
        self.actionsStatistics = actionsStatistics
        self.recordsStatistics = recordsStatistics
    }
}

// MARK: - Habits Statistics
/// 習慣統計（曜日別・時間帯別パターン）
struct HabitsStatistics: Codable, Equatable {
    /// 曜日別パターン
    let weekdayPatterns: [StoredWeekdayPattern]

    /// 時間帯別パターン
    let timePatterns: [StoredTimePattern]

    /// 最もアクティブな曜日名
    let mostActiveDay: String

    /// 最もアクティブな時間帯
    let mostActiveTime: String

    /// 保存された曜日名から現在の言語設定に合わせた曜日名を返す
    var localizedMostActiveDay: String {
        if let weekday = StoredWeekdayPattern.weekdayNumber(from: mostActiveDay) {
            return StoredWeekdayPattern.localizedDayName(for: weekday)
        }
        return mostActiveDay
    }
}

/// 保存用曜日パターン
struct StoredWeekdayPattern: Codable, Equatable, Identifiable {
    var id: Int { dayOfWeek }
    let dayOfWeek: Int // 1=日曜, 2=月曜, ... 7=土曜
    let selfCount: Int
    let partnerCount: Int

    var totalCount: Int { selfCount + partnerCount }

    var dayName: String {
        StoredWeekdayPattern.localizedDayName(for: dayOfWeek)
    }
}

/// 保存用時間帯パターン
struct StoredTimePattern: Codable, Equatable, Identifiable {
    var id: Int { startHour }
    let hourRange: String
    let startHour: Int
    let selfCount: Int
    let partnerCount: Int

    var totalCount: Int { selfCount + partnerCount }
}

// MARK: - Actions Statistics
/// 行動統計
struct ActionsStatistics: Codable, Equatable {
    /// 行動パターン
    let actionPatterns: [StoredActionPattern]
}

/// 保存用行動パターン
struct StoredActionPattern: Codable, Equatable, Identifiable {
    var id: String { type }
    let type: String
    let selfCount: Int
    let partnerCount: Int
    let description: String
    /// グループチャット時のメンバー別カウント（後方互換のためオプショナル）
    var memberCounts: [String: Int]?

    var totalCount: Int { selfCount + partnerCount }

    /// typeキー（英語ID）からローカライズされた表示名を返す
    var displayType: String {
        Self.localizedType(type)
    }

    /// typeキー → ローカライズ表示名（静的メソッド）
    /// 新データ（英語キー）と旧データ（日本語キー）の両方に対応
    static func localizedType(_ type: String) -> String {
        // 旧データの日本語文字列 → 英語キーに変換
        let jaToKey: [String: String] = [
            "テキスト": "textMessage",
            "スタンプ": "sticker",
            "写真": "photo",
            "動画": "video",
            "通話": "call",
            "質問": "question",
            "提案": "proposal",
            "感情表現": "emotionalMessage"
        ]
        let key = jaToKey[type] ?? type

        switch key {
        case "textMessage": return String(localized: "テキスト", bundle: LanguageManager.appBundle)
        case "sticker": return String(localized: "スタンプ", bundle: LanguageManager.appBundle)
        case "photo": return String(localized: "写真", bundle: LanguageManager.appBundle)
        case "video": return String(localized: "動画", bundle: LanguageManager.appBundle)
        case "call": return String(localized: "通話", bundle: LanguageManager.appBundle)
        case "question": return String(localized: "質問", bundle: LanguageManager.appBundle)
        case "proposal": return String(localized: "提案", bundle: LanguageManager.appBundle)
        case "emotionalMessage": return String(localized: "感情表現", bundle: LanguageManager.appBundle)
        default: return type
        }
    }
}

// MARK: - Records Statistics
/// 記録統計
struct RecordsStatistics: Codable, Equatable {
    /// 総メッセージ数
    let totalMessages: Int

    /// 解析期間（日数）
    let totalDays: Int

    /// 1日平均メッセージ数
    let averagePerDay: Double

    /// 最長連続日数
    let longestStreak: Int

    /// 自分のメッセージ比率
    let selfRatio: Double

    /// 最もアクティブな曜日
    let mostActiveDay: String

    /// 最もアクティブな時間帯
    let mostActiveTime: String

    // MARK: - Fun Statistics（オプショナル：後方互換）

    /// 自分の最速返信タイム（秒）
    var fastestSelfReply: TimeInterval?

    /// 相手の最速返信タイム（秒）
    var fastestPartnerReply: TimeInterval?

    /// 深夜トーク率（0:00-5:00のメッセージ割合, 0〜1）
    var lateNightRate: Double?

    /// 既読スルー推定回数（自分→相手: 3時間以上未返信）
    var estimatedSelfReadIgnore: Int?

    /// 既読スルー推定回数（相手→自分: 3時間以上未返信）
    var estimatedPartnerReadIgnore: Int?

    /// グループチャット時: メンバー別最速返信タイム（後方互換のためオプショナル）
    var memberFastestReply: [String: TimeInterval]?

    /// グループチャット時: メンバー別既読スルー回数（後方互換のためオプショナル）
    var memberReadIgnoreCount: [String: Int]?

    /// 保存された曜日名から現在の言語設定に合わせた曜日名を返す
    var localizedMostActiveDay: String {
        if let weekday = StoredWeekdayPattern.weekdayNumber(from: mostActiveDay) {
            return StoredWeekdayPattern.localizedDayName(for: weekday)
        }
        return mostActiveDay
    }
}

extension StoredWeekdayPattern {
    /// dayOfWeek数値から現在の言語設定に合わせた曜日名を返す
    static func localizedDayName(for dayOfWeek: Int) -> String {
        guard dayOfWeek >= 1, dayOfWeek <= 7 else { return "" }
        let weekdays: [String]
        let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? "ja"
        switch stored {
        case "en":
            weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        case "es":
            weekdays = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]
        case "ko":
            weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        case "zh-Hans":
            weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        default: // ja
            weekdays = ["日", "月", "火", "水", "木", "金", "土"]
        }
        return weekdays[dayOfWeek - 1]
    }

    /// 保存された曜日名（任意の言語）からdayOfWeek数値に逆引き
    static func weekdayNumber(from name: String) -> Int? {
        let nameToWeekday: [String: Int] = [
            // Japanese
            "日": 1, "月": 2, "火": 3, "水": 4, "木": 5, "金": 6, "土": 7,
            // English
            "Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7,
            // Spanish
            "Dom": 1, "Lun": 2, "Mar": 3, "Mié": 4, "Jue": 5, "Vie": 6, "Sáb": 7,
            // Korean
            "일": 1, "월": 2, "화": 3, "수": 4, "목": 5, "금": 6, "토": 7,
            // Chinese
            "一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7,
        ]
        if let result = nameToWeekday[name] {
            return result
        }
        // 過去に保存された "_weekday" サフィックス付きキーに対応
        if name.hasSuffix("_weekday") {
            let stripped = String(name.dropLast("_weekday".count))
            return nameToWeekday[stripped]
        }
        return nil
    }
}

// MARK: - Call Statistics
/// 通話統計
struct CallStatistics: Codable, Equatable {
    /// 通話回数の合計
    let totalCallCount: Int

    /// 通話時間の合計（秒）
    let totalCallDuration: Int

    /// 最長通話時間（秒）
    let longestCallDuration: Int

    /// 最長通話の日付
    let longestCallDate: Date?

    /// 通話をキャンセルした回数（不在着信）
    let missedCallCount: Int

    /// 自分が発信した回数
    let selfInitiatedCallCount: Int

    /// 相手が発信した回数
    let partnerInitiatedCallCount: Int

    /// 1日の最大通話回数
    let maxDailyCallCount: Int

    // MARK: - Codable (後方互換性)
    enum CodingKeys: String, CodingKey {
        case totalCallCount, totalCallDuration, longestCallDuration, longestCallDate
        case missedCallCount, selfInitiatedCallCount, partnerInitiatedCallCount
        case maxDailyCallCount
    }

    init(totalCallCount: Int, totalCallDuration: Int, longestCallDuration: Int, longestCallDate: Date?, missedCallCount: Int, selfInitiatedCallCount: Int, partnerInitiatedCallCount: Int, maxDailyCallCount: Int = 0) {
        self.totalCallCount = totalCallCount
        self.totalCallDuration = totalCallDuration
        self.longestCallDuration = longestCallDuration
        self.longestCallDate = longestCallDate
        self.missedCallCount = missedCallCount
        self.selfInitiatedCallCount = selfInitiatedCallCount
        self.partnerInitiatedCallCount = partnerInitiatedCallCount
        self.maxDailyCallCount = maxDailyCallCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCallCount = try container.decode(Int.self, forKey: .totalCallCount)
        totalCallDuration = try container.decode(Int.self, forKey: .totalCallDuration)
        longestCallDuration = try container.decode(Int.self, forKey: .longestCallDuration)
        longestCallDate = try container.decodeIfPresent(Date.self, forKey: .longestCallDate)
        missedCallCount = try container.decode(Int.self, forKey: .missedCallCount)
        selfInitiatedCallCount = try container.decode(Int.self, forKey: .selfInitiatedCallCount)
        partnerInitiatedCallCount = try container.decode(Int.self, forKey: .partnerInitiatedCallCount)
        maxDailyCallCount = try container.decodeIfPresent(Int.self, forKey: .maxDailyCallCount) ?? 0
    }

    // MARK: - Computed Properties

    /// 通話時間の合計（フォーマット済み）
    var formattedTotalDuration: String {
        formatDuration(totalCallDuration)
    }

    /// 最長通話時間（フォーマット済み）
    var formattedLongestDuration: String {
        formatDuration(longestCallDuration)
    }

    /// 最長通話の日付（フォーマット済み）
    var formattedLongestCallDate: String? {
        guard let date = longestCallDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }

    /// 平均通話時間（秒）
    var averageCallDuration: Int {
        guard totalCallCount > 0 else { return 0 }
        return totalCallDuration / totalCallCount
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String(format: String(localized: "%d秒", bundle: LanguageManager.appBundle), seconds)
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            if secs > 0 {
                return String(format: String(localized: "%d分%d秒", bundle: LanguageManager.appBundle), minutes, secs)
            } else {
                return String(format: String(localized: "%d分", bundle: LanguageManager.appBundle), minutes)
            }
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if minutes > 0 {
                return String(format: String(localized: "%d時間%d分", bundle: LanguageManager.appBundle), hours, minutes)
            } else {
                return String(format: String(localized: "%d時間", bundle: LanguageManager.appBundle), hours)
            }
        }
    }
}

// MARK: - Text Analysis
/// テキスト分析
struct TextAnalysis: Codable, Equatable {
    /// 感謝の言葉を使用した回数
    let thanksCount: Int

    /// 謝罪の言葉を使用した回数
    let apologyCount: Int

    /// 「？」を使用した回数
    let questionMarkCount: Int

    /// 「！」を使用した回数
    let exclamationMarkCount: Int

    /// 「w」を使用した回数
    let laughWCount: Int

    /// 「笑」を使用した回数
    let laughKanjiCount: Int

    /// 挨拶の言葉を使用した回数
    let greetingCount: Int

    /// 笑いの合計（w + 笑）
    var totalLaughCount: Int {
        laughWCount + laughKanjiCount
    }

    // MARK: - Per-Person Breakdown（オプショナル：後方互換）
    var selfCounts: TextPersonCounts?
    var partnerCounts: TextPersonCounts?

    /// グループチャット時のメンバー別カウント（後方互換のためオプショナル）
    var memberCounts: [String: TextPersonCounts]?
}

/// 個人別テキスト分析カウント
struct TextPersonCounts: Codable, Equatable {
    let thanksCount: Int
    let apologyCount: Int
    let questionMarkCount: Int
    let exclamationMarkCount: Int
    let laughWCount: Int
    let laughKanjiCount: Int
    let greetingCount: Int

    var totalLaughCount: Int {
        laughWCount + laughKanjiCount
    }
}

// MARK: - Phrase Analysis
/// フレーズ分析
struct PhraseAnalysis: Codable, Equatable {
    /// 自分がよく使うフレーズ（上位5件）
    let selfTopPhrases: [PhraseCount]

    /// 相手がよく使うフレーズ（上位5件）
    let partnerTopPhrases: [PhraseCount]

    /// 2人がよく使う共通フレーズ（上位5件）
    let commonPhrases: [PhraseCount]

    /// グループチャット時のメンバー別フレーズ分析（後方互換のためオプショナル）
    var memberAnalyses: [MemberPhraseAnalysis]?
}

/// フレーズと使用回数
struct PhraseCount: Codable, Equatable, Identifiable {
    var id: String { phrase }
    let phrase: String
    let count: Int
}

// MARK: - Sentiment Analysis
/// 感情分析
struct SentimentAnalysis: Codable, Equatable {
    /// ポジティブなメッセージの割合（0〜1）
    let positiveRatio: Double

    /// ネガティブなメッセージの割合（0〜1）
    let negativeRatio: Double

    /// 中立なメッセージの割合（0〜1）
    let neutralRatio: Double

    /// ポジティブなメッセージ数
    let positiveCount: Int

    /// ネガティブなメッセージ数
    let negativeCount: Int

    /// 中立なメッセージ数
    let neutralCount: Int

    // MARK: - Computed Properties

    var positivePercentage: Int {
        Int(positiveRatio * 100)
    }

    var negativePercentage: Int {
        Int(negativeRatio * 100)
    }

    var neutralPercentage: Int {
        Int(neutralRatio * 100)
    }
}

// MARK: - Love Words Analysis
/// 愛の言葉分析
struct LoveWordsAnalysis: Codable, Equatable {
    /// 自分が使った愛の言葉（上位5件）
    let selfLoveWords: [PhraseCount]

    /// 相手が使った愛の言葉（上位5件）
    let partnerLoveWords: [PhraseCount]

    /// 自分が使った愛の言葉の合計回数
    let selfTotalCount: Int

    /// 相手が使った愛の言葉の合計回数
    let partnerTotalCount: Int

    /// グループチャット時のメンバー別愛情表現（後方互換のためオプショナル）
    var memberAnalyses: [MemberLoveWordsEntry]?
}
