import Foundation

// MARK: - Detailed Statistics Analyzer
/// 詳細統計を計算するアナライザー
final class DetailedStatisticsAnalyzer {

    // MARK: - Word Lists

    /// 感謝の言葉
    private let thanksWords = [
        "ありがとう", "ありがと", "あざす", "あざっす", "サンキュー", "さんきゅー",
        "感謝", "助かる", "助かった", "嬉しい", "うれしい", "ありがたい",
        // en
        "thank you", "thanks", "thx", "ty", "appreciate",
        // es
        "gracias", "muchas gracias", "mil gracias", "te lo agradezco",
        // ko
        "고마워", "감사해요", "감사합니다", "ㄱㅅ",
        // zh (Simplified + Traditional)
        "谢谢", "感谢", "谢啦", "多谢",
        "謝謝", "感謝", "謝啦"
    ]

    /// 謝罪の言葉
    private let apologyWords = [
        "ごめん", "ごめんね", "すまん", "すまない", "申し訳", "わるい", "悪い",
        "すみません", "すいません", "ソーリー", "そーりー", "sorry",
        // en
        "my bad", "i'm sorry", "forgive me",
        // es
        "lo siento", "perdón", "perdona", "discúlpame",
        // ko
        "미안", "미안해", "죄송", "죄송해요", "ㅁㅇ",
        // zh (Simplified + Traditional)
        "对不起", "抱歉", "不好意思", "对不住",
        "對不起", "對不住"
    ]

    /// 挨拶の言葉
    private let greetingWords = [
        "おはよう", "おはよ", "こんにちは", "こんにちわ", "こんばんは", "こんばんわ",
        "おやすみ", "ただいま", "おかえり", "いってきます", "いってらっしゃい",
        "おつかれ", "お疲れ", "おつ", "乙",
        // en
        "good morning", "morning", "good night", "night", "hello", "hi", "hey", "bye", "see you",
        // es
        "buenos días", "buenas noches", "buenas tardes", "hola", "adiós", "chao",
        // ko
        "좋은아침", "안녕", "잘자", "수고", "바이",
        // zh (Simplified + Traditional)
        "早安", "晚安", "你好", "拜拜", "再见", "辛苦了",
        "再見"
    ]

    /// 愛の言葉
    private let loveWords = [
        "好き", "すき", "大好き", "だいすき", "愛してる", "あいしてる",
        "かわいい", "可愛い", "きれい", "綺麗", "イケメン", "かっこいい",
        "会いたい", "あいたい", "想ってる", "おもってる", "ちゅ", "ちゅー",
        "ハグ", "はぐ", "キス", "きす", "抱きしめ", "だきしめ",
        // en
        "love you", "love u", "i love you", "miss you", "cute", "beautiful", "babe", "baby",
        // es
        "te quiero", "te amo", "te extraño", "mi amor", "cariño", "corazón", "hermosa", "hermoso",
        // ko
        "사랑해", "좋아해", "보고싶어", "귀여워", "이뻐", "오빠", "자기야",
        // zh (Simplified + Traditional)
        "爱你", "喜欢你", "想你", "可爱", "宝贝", "亲爱的",
        "愛你", "喜歡你", "可愛", "寶貝", "親愛的"
    ]

    /// ポジティブな言葉
    private let positiveWords = [
        "嬉しい", "うれしい", "楽しい", "たのしい", "幸せ", "しあわせ",
        "最高", "素敵", "すてき", "いいね", "良い", "よい", "好き", "すき",
        "面白い", "おもしろい", "ワクワク", "わくわく", "期待", "やった",
        // en
        "happy", "fun", "great", "nice", "awesome", "amazing", "perfect",
        // es
        "genial", "increíble", "perfecto", "bueno", "feliz", "contento", "contenta",
        // ko
        "행복해", "좋아", "최고", "대박", "재밌어",
        // zh (Simplified + Traditional)
        "开心", "高兴", "快乐", "太好了", "棒", "666",
        "開心", "高興", "快樂"
    ]

    /// ネガティブな言葉
    private let negativeWords = [
        "悲しい", "かなしい", "辛い", "つらい", "しんどい", "疲れた", "つかれた",
        "嫌", "いや", "むかつく", "イライラ", "怒", "泣", "最悪", "だめ", "ダメ",
        "無理", "むり", "心配", "不安", "寂しい", "さみしい", "苦しい", "くるしい",
        // en
        "sad", "tired", "annoyed", "angry", "upset", "hate", "worst", "terrible", "depressed",
        // es
        "triste", "cansado", "cansada", "enfadado", "enfadada", "furioso", "horrible", "peor",
        // ko
        "슬퍼", "힘들어", "짜증", "싫어", "최악", "화나",
        // zh (Simplified + Traditional)
        "难过", "伤心", "累", "烦", "讨厌", "生气", "难受",
        "難過", "傷心", "煩", "討厭", "生氣", "難受"
    ]

    /// w系笑い表現パターン（lowercased）
    private let laughWPatterns = [
        "lol", "lmao", "lmfao", "rofl", "haha", "hahaha", "hehe", "hehehe", "lolol",
        "ㅋㅋ", "ㅋㅋㅋ", "ㅎㅎ", "ㅎㅎㅎ", "크크", "푸하하",
        "哈哈", "哈哈哈", "嘻嘻", "嘿嘿", "呵呵", "233", "2333", "23333", "hhh", "hhhh",
        "jaja", "jajaja", "jeje", "jejeje"
    ]

    /// 笑/草系笑い表現パターン
    private let laughKanjiPatterns = [
        "笑", "草", "ꉂꉂ", "ﾜﾗ", "ワラ", "わら"
    ]

    // Pre-compiled regex and lowercased word lists for performance
    private lazy var wwRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "[wWｗＷ]{2,}")
    private lazy var wwRegexLower: NSRegularExpression? = try? NSRegularExpression(pattern: "[wｗ]{2,}")
    private lazy var lowercasedPositiveWords: [String] = sentimentPositiveWords.map { $0.lowercased() }
    private lazy var lowercasedNegativeWords: [String] = sentimentNegativeWords.map { $0.lowercased() }

    /// w系笑い表現を含むかチェック（lowercased済みのcontentを受け取る）
    private func containsWLaugh(_ content: String) -> Bool {
        for pattern in laughWPatterns {
            if content.contains(pattern) { return true }
        }
        if let regex = wwRegexLower,
           regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            return true
        }
        return false
    }

    /// 笑/草系笑い表現を含むかチェック
    private func containsKanjiLaugh(_ content: String) -> Bool {
        for pattern in laughKanjiPatterns {
            if content.contains(pattern) { return true }
        }
        return false
    }

    /// 笑い表現を含むかチェック（全パターン統合）
    private func containsLaughExpression(_ content: String) -> Bool {
        containsWLaugh(content) || containsKanjiLaugh(content)
    }

    // MARK: - Public Methods

    func analyze(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String,
        allParticipantNames: [String]? = nil,
        originalMessages: [ChatMessage]? = nil
    ) -> DetailedStatistics {
        let isGroup = (allParticipantNames?.count ?? 0) > 2
        let callStats = analyzeCallStatistics(messages: messages, selfName: selfName)
        let textAnalysis = analyzeText(messages: messages, selfName: selfName, allParticipantNames: allParticipantNames)
        var phraseAnalysis = analyzePhrases(messages: messages, selfName: selfName, partnerName: partnerName)
        let sentimentAnalysis = analyzeSentiment(messages: messages)
        var loveWordsAnalysis = analyzeLoveWords(messages: messages, selfName: selfName, partnerName: partnerName)
        let habitsStatistics = analyzeHabits(messages: messages, selfName: selfName)
        let actionsStatistics = analyzeActions(messages: messages, selfName: selfName, allParticipantNames: allParticipantNames)
        let recordsStatistics = analyzeRecords(messages: messages, selfName: selfName, allParticipantNames: allParticipantNames)

        // グループ時: メンバー別フレーズ・愛情表現を計算
        if isGroup, let names = allParticipantNames {
            phraseAnalysis.memberAnalyses = analyzeMemberPhrases(messages: messages, participantNames: names)
            loveWordsAnalysis.memberAnalyses = analyzeMemberLoveWords(messages: messages, participantNames: names)
        }

        return DetailedStatistics(
            callStatistics: callStats,
            textAnalysis: textAnalysis,
            phraseAnalysis: phraseAnalysis,
            sentimentAnalysis: sentimentAnalysis,
            loveWordsAnalysis: loveWordsAnalysis,
            habitsStatistics: habitsStatistics,
            actionsStatistics: actionsStatistics,
            recordsStatistics: recordsStatistics
        )
    }

    // MARK: - Private Methods

    /// 通話統計を分析
    private func analyzeCallStatistics(messages: [ChatMessage], selfName: String) -> CallStatistics {
        let callMessages = messages.filter { $0.eventType == .call }
        let missedCallMessages = messages.filter { $0.eventType == .missedCall }

        let totalCallCount = callMessages.count
        let totalCallDuration = callMessages.compactMap { $0.callDurationSeconds }.reduce(0, +)

        // 最長通話を検索
        var longestDuration = 0
        var longestCallDate: Date? = nil

        for message in callMessages {
            if let duration = message.callDurationSeconds, duration > longestDuration {
                longestDuration = duration
                longestCallDate = message.timestamp
            }
        }

        // 発信者のカウント
        let selfInitiatedCalls = callMessages.filter { $0.senderName == selfName }.count
        let partnerInitiatedCalls = callMessages.filter { $0.senderName != selfName }.count

        // 1日の最大通話回数
        let calendar = Calendar.current
        var dailyCounts: [DateComponents: Int] = [:]
        for message in callMessages {
            let day = calendar.dateComponents([.year, .month, .day], from: message.timestamp)
            dailyCounts[day, default: 0] += 1
        }
        let maxDailyCallCount = dailyCounts.values.max() ?? 0

        return CallStatistics(
            totalCallCount: totalCallCount,
            totalCallDuration: totalCallDuration,
            longestCallDuration: longestDuration,
            longestCallDate: longestCallDate,
            missedCallCount: missedCallMessages.count,
            selfInitiatedCallCount: selfInitiatedCalls,
            partnerInitiatedCallCount: partnerInitiatedCalls,
            maxDailyCallCount: maxDailyCallCount
        )
    }

    /// テキスト分析（個人別カウント付き）
    private func analyzeText(messages: [ChatMessage], selfName: String, allParticipantNames: [String]? = nil) -> TextAnalysis {
        let textMessages = messages.filter { $0.eventType == .text }

        // 全体カウント
        var thanksCount = 0, apologyCount = 0, questionMarkCount = 0
        var exclamationMarkCount = 0, laughWCount = 0, laughKanjiCount = 0, greetingCount = 0

        // 個人別カウント
        var selfThanks = 0, selfApology = 0, selfQuestion = 0
        var selfExclamation = 0, selfLaughW = 0, selfLaughKanji = 0, selfGreeting = 0
        var partnerThanks = 0, partnerApology = 0, partnerQuestion = 0
        var partnerExclamation = 0, partnerLaughW = 0, partnerLaughKanji = 0, partnerGreeting = 0

        // グループ時: メンバー別カウント
        let isGroup = (allParticipantNames?.count ?? 0) > 2
        var memberThanks: [String: Int] = [:]
        var memberApology: [String: Int] = [:]
        var memberQuestion: [String: Int] = [:]
        var memberExclamation: [String: Int] = [:]
        var memberLaughW: [String: Int] = [:]
        var memberLaughKanji: [String: Int] = [:]
        var memberGreeting: [String: Int] = [:]

        for message in textMessages {
            let content = message.content.lowercased()
            let isSelf = message.senderName == selfName

            let sender = message.senderName

            // 感謝の言葉
            for word in thanksWords {
                if content.contains(word.lowercased()) {
                    thanksCount += 1
                    if isSelf { selfThanks += 1 } else { partnerThanks += 1 }
                    if isGroup { memberThanks[sender, default: 0] += 1 }
                    break
                }
            }

            // 謝罪の言葉
            for word in apologyWords {
                if content.contains(word.lowercased()) {
                    apologyCount += 1
                    if isSelf { selfApology += 1 } else { partnerApology += 1 }
                    if isGroup { memberApology[sender, default: 0] += 1 }
                    break
                }
            }

            // 挨拶の言葉
            for word in greetingWords {
                if content.contains(word.lowercased()) {
                    greetingCount += 1
                    if isSelf { selfGreeting += 1 } else { partnerGreeting += 1 }
                    if isGroup { memberGreeting[sender, default: 0] += 1 }
                    break
                }
            }

            // 記号のカウント
            let qCount = content.filter { $0 == "?" || $0 == "？" }.count
            let eCount = content.filter { $0 == "!" || $0 == "！" }.count
            questionMarkCount += qCount
            exclamationMarkCount += eCount
            if isSelf { selfQuestion += qCount; selfExclamation += eCount }
            else { partnerQuestion += qCount; partnerExclamation += eCount }
            if isGroup { memberQuestion[sender, default: 0] += qCount; memberExclamation[sender, default: 0] += eCount }

            // 笑い表現のカウント（w系と笑/草系を分離）
            let hasW = containsWLaugh(content)
            let hasKanji = containsKanjiLaugh(content)
            if hasW {
                laughWCount += 1
                if isSelf { selfLaughW += 1 } else { partnerLaughW += 1 }
                if isGroup { memberLaughW[sender, default: 0] += 1 }
            }
            if hasKanji {
                laughKanjiCount += 1
                if isSelf { selfLaughKanji += 1 } else { partnerLaughKanji += 1 }
                if isGroup { memberLaughKanji[sender, default: 0] += 1 }
            }
        }

        var result = TextAnalysis(
            thanksCount: thanksCount,
            apologyCount: apologyCount,
            questionMarkCount: questionMarkCount,
            exclamationMarkCount: exclamationMarkCount,
            laughWCount: laughWCount,
            laughKanjiCount: laughKanjiCount,
            greetingCount: greetingCount
        )
        result.selfCounts = TextPersonCounts(
            thanksCount: selfThanks, apologyCount: selfApology,
            questionMarkCount: selfQuestion, exclamationMarkCount: selfExclamation,
            laughWCount: selfLaughW, laughKanjiCount: selfLaughKanji,
            greetingCount: selfGreeting
        )
        result.partnerCounts = TextPersonCounts(
            thanksCount: partnerThanks, apologyCount: partnerApology,
            questionMarkCount: partnerQuestion, exclamationMarkCount: partnerExclamation,
            laughWCount: partnerLaughW, laughKanjiCount: partnerLaughKanji,
            greetingCount: partnerGreeting
        )

        // グループ時: メンバー別TextPersonCountsを構築
        if isGroup, let names = allParticipantNames {
            var memberCountsDict: [String: TextPersonCounts] = [:]
            for name in names {
                memberCountsDict[name] = TextPersonCounts(
                    thanksCount: memberThanks[name, default: 0],
                    apologyCount: memberApology[name, default: 0],
                    questionMarkCount: memberQuestion[name, default: 0],
                    exclamationMarkCount: memberExclamation[name, default: 0],
                    laughWCount: memberLaughW[name, default: 0],
                    laughKanjiCount: memberLaughKanji[name, default: 0],
                    greetingCount: memberGreeting[name, default: 0]
                )
            }
            result.memberCounts = memberCountsDict
        }

        return result
    }

    /// フレーズ分析
    private func analyzePhrases(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String
    ) -> PhraseAnalysis {
        let textMessages = messages.filter { $0.eventType == .text }

        // 3文字以上のフレーズを抽出
        var selfPhrases: [String: Int] = [:]
        var partnerPhrases: [String: Int] = [:]

        for message in textMessages {
            let phrases = extractPhrases(from: message.content)

            if message.senderName == selfName {
                for phrase in phrases {
                    selfPhrases[phrase, default: 0] += 1
                }
            } else {
                for phrase in phrases {
                    partnerPhrases[phrase, default: 0] += 1
                }
            }
        }

        // 上位5件を取得
        let selfTop = selfPhrases.sorted { $0.value > $1.value }
            .prefix(5)
            .map { PhraseCount(phrase: $0.key, count: $0.value) }

        let partnerTop = partnerPhrases.sorted { $0.value > $1.value }
            .prefix(5)
            .map { PhraseCount(phrase: $0.key, count: $0.value) }

        // 共通フレーズ（両方が使っているもの）
        var commonPhrases: [String: Int] = [:]
        for (phrase, selfCount) in selfPhrases {
            if let partnerCount = partnerPhrases[phrase] {
                commonPhrases[phrase] = selfCount + partnerCount
            }
        }

        let commonTop = commonPhrases.sorted { $0.value > $1.value }
            .prefix(5)
            .map { PhraseCount(phrase: $0.key, count: $0.value) }

        return PhraseAnalysis(
            selfTopPhrases: Array(selfTop),
            partnerTopPhrases: Array(partnerTop),
            commonPhrases: Array(commonTop)
        )
    }

    /// テキストからフレーズを抽出（多言語対応）
    private func extractPhrases(from text: String) -> [String] {
        var phrases: [String] = []

        // 1. 日本語: ひらがな/カタカナ/漢字の連続（3〜10文字）
        let jaPattern = "[\\p{Hiragana}\\p{Katakana}\\p{Han}ー]{3,10}"
        phrases.append(contentsOf: extractByRegex(text: text, pattern: jaPattern))

        // 2. 韓国語: ハングルの連続（2〜10文字）
        let koPattern = "[\\p{Hangul}]{2,10}"
        phrases.append(contentsOf: extractByRegex(text: text, pattern: koPattern))

        // 3. 英語: 2〜3語のフレーズ（バイグラム/トライグラム）を抽出
        phrases.append(contentsOf: extractEnglishPhrases(from: text))

        // 4. 中国語: 漢字の連続（日本語パターンでカバー済みだが、2文字もフレーズとして拾う）
        let zhPattern = "[\\p{Han}]{2}"
        phrases.append(contentsOf: extractByRegex(text: text, pattern: zhPattern))

        return phrases.filter { !isCommonWord($0) }
    }

    /// 正規表現でフレーズを抽出するヘルパー
    private func extractByRegex(text: String, pattern: String) -> [String] {
        guard let regex = RegexCache.shared.regex(pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    /// 英語フレーズを2〜3語の n-gram で抽出
    private func extractEnglishPhrases(from text: String) -> [String] {
        // アルファベットを含まない場合はスキップ
        guard text.unicodeScalars.contains(where: { (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value) }) else {
            return []
        }

        // 句読点・記号を除去してトークン化（regex はキャッシュ済みを再利用）
        let lowered = text.lowercased()
        let cleaned: String
        if let regex = RegexCache.shared.regex("[^a-z'\\s]") {
            let range = NSRange(lowered.startIndex..., in: lowered)
            cleaned = regex.stringByReplacingMatches(in: lowered, range: range, withTemplate: " ")
        } else {
            cleaned = lowered
        }
        let words = cleaned.split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 1 && !$0.allSatisfy({ $0 == "'" }) }

        guard words.count >= 2 else { return [] }

        var phrases: [String] = []

        // バイグラム（2語）
        for i in 0..<(words.count - 1) {
            let bigram = "\(words[i]) \(words[i+1])"
            // 両方がストップワードならスキップ
            if enStopWords.contains(words[i]) && enStopWords.contains(words[i+1]) { continue }
            phrases.append(bigram)
        }

        // トライグラム（3語）
        for i in 0..<(words.count - 2) {
            let trigram = "\(words[i]) \(words[i+1]) \(words[i+2])"
            // 全てストップワードならスキップ
            let meaningful = [words[i], words[i+1], words[i+2]].filter { !enStopWords.contains($0) }
            if meaningful.isEmpty { continue }
            phrases.append(trigram)
        }

        return phrases
    }

    /// 英語ストップワード（フレーズ n-gram フィルタ用）
    private let enStopWords: Set<String> = [
        "i", "me", "my", "we", "us", "our", "you", "your",
        "he", "him", "his", "she", "her", "it", "its", "they", "them", "their",
        "a", "an", "the", "is", "am", "are", "was", "were", "be", "been", "being",
        "do", "does", "did", "has", "have", "had", "will", "would", "shall", "should",
        "can", "could", "may", "might", "must",
        "to", "of", "in", "on", "at", "by", "for", "with", "from", "up", "out",
        "and", "or", "but", "not", "no", "so", "if", "as", "than",
        "that", "this", "what", "which", "who", "how", "when", "where", "why",
        "just", "got", "get", "like", "don't", "it's", "i'm", "don", "that's",
        "there", "about", "been", "would", "into", "also", "then", "here",
        "all", "some", "any", "each", "very", "too", "much", "more"
    ]

    /// 一般的すぎる単語かどうか（日本語・韓国語・中国語用）
    private func isCommonWord(_ word: String) -> Bool {
        return commonWordsSet.contains(word)
    }

    private let commonWordsSet: Set<String> = [
        // ja
        "これ", "それ", "あれ", "どれ", "ここ", "そこ", "あそこ",
        "この", "その", "あの", "どの", "こう", "そう", "ああ", "どう",
        "です", "ます", "でした", "ました", "ない", "ある", "いる",
        "する", "なる", "できる", "思う", "言う", "行く", "来る",
        "www", "ｗｗｗ", "けど", "から", "だけ", "まだ", "もう",
        "ちょっと", "やっぱ", "なんか", "それは", "これは",
        // ko
        "그래", "근데", "그런", "이런", "저런", "그거", "이거", "저거",
        "하는", "되는", "있는", "없는",
        // zh (Simplified + Traditional)
        "的", "了", "是", "在", "我", "你", "他", "她", "们", "們", "这", "這", "那",
        "不", "也", "都", "就", "还", "還", "有", "没", "沒", "会", "會", "吧", "啊", "呢"
    ]

    /// 感情分析（拡張版：絵文字・スタンプ・カジュアル表現対応）
    private func analyzeSentiment(messages: [ChatMessage]) -> SentimentAnalysis {
        var positiveCount = 0
        var negativeCount = 0
        var neutralCount = 0

        for message in messages {
            // システムメッセージは除外
            if message.eventType == .system { continue }

            let sentiment = detectSentimentEnhanced(message)

            switch sentiment {
            case .positive:
                positiveCount += 1
            case .negative:
                negativeCount += 1
            case .neutral:
                neutralCount += 1
            }
        }

        let total = max(1, positiveCount + negativeCount + neutralCount)
        let positiveRatio = Double(positiveCount) / Double(total)
        let negativeRatio = Double(negativeCount) / Double(total)
        let neutralRatio = Double(neutralCount) / Double(total)

        return SentimentAnalysis(
            positiveRatio: positiveRatio,
            negativeRatio: negativeRatio,
            neutralRatio: neutralRatio,
            positiveCount: positiveCount,
            negativeCount: negativeCount,
            neutralCount: neutralCount
        )
    }

    private enum Sentiment {
        case positive, negative, neutral
    }

    // MARK: - Sentiment Word Lists (Extended)

    private let sentimentPositiveWords = [
        // 感情系
        "嬉しい", "うれしい", "楽しい", "たのしい", "幸せ", "しあわせ",
        "最高", "素敵", "すてき", "いいね", "良い", "よい",
        "面白い", "おもしろい", "ワクワク", "わくわく", "期待", "やった",
        // 好意・愛情
        "好き", "すき", "大好き", "だいすき", "愛してる", "あいしてる",
        "かわいい", "可愛い", "きれい", "綺麗", "かっこいい", "イケメン",
        "会いたい", "あいたい",
        // 感謝
        "ありがとう", "ありがと", "あざす", "あざっす", "サンキュー", "さんきゅー",
        "感謝", "助かる", "助かった", "ありがたい",
        // 挨拶（ポジティブニュアンス）
        "おはよう", "おはよ", "おやすみ", "おつかれ", "お疲れ", "おつ",
        "おかえり", "ただいま", "いってきます", "いってらっしゃい",
        // カジュアルポジティブ
        "ウケる", "うける", "ヤバい", "やばい", "ヤバ", "やば",
        "マジ", "まじ", "すご", "すごい", "スゴい", "スゴ",
        "神", "最強", "天才", "優勝", "尊い", "とうとい",
        "推せる", "おしゃ", "エモい", "えもい",
        "いいな", "いいなぁ", "いいなあ", "いいよ", "いいよー",
        "了解", "りょ", "りょうかい", "おっけー", "おけ", "オッケー",
        "OK", "ok", "オケ", "おk",
        "わかった", "分かった", "うん", "うんうん",
        // 笑い系
        "笑", "ワロタ", "わろた", "草", "くさ",
        // 応援・褒め
        "頑張", "がんば", "ガンバ", "ファイト", "応援",
        "偉い", "えらい", "上手", "じょうず",
        // 楽しみ
        "楽しみ", "たのしみ", "待ち遠しい",
        // リアクション
        "なるほど", "たしかに", "確かに", "それな", "わかる", "分かる",
        // en
        "happy", "excited", "love", "amazing", "awesome", "wonderful", "beautiful",
        "perfect", "great", "nice", "cool", "fun", "glad", "thankful", "proud",
        "lol", "haha", "yay", "omg", "wow",
        // ko
        "좋아", "최고", "대박", "행복", "사랑", "감사", "기뻐", "재밌어",
        "멋져", "ㅋㅋ", "ㅎㅎ", "화이팅", "굿",
        // zh (Simplified + Traditional)
        "开心", "高兴", "快乐", "棒", "厉害", "喜欢", "爱", "感谢",
        "哈哈", "666", "好的", "没问题",
        "開心", "高興", "快樂", "厲害", "喜歡", "愛", "感謝", "沒問題"
    ]

    private let sentimentNegativeWords = [
        // 悲しみ・辛さ
        "悲しい", "かなしい", "辛い", "つらい", "しんどい",
        "疲れた", "つかれた", "だるい", "ダルい",
        // 怒り・不満
        "嫌", "いや", "むかつく", "イライラ", "いらいら",
        "怒", "腹立つ", "ムカつく", "ふざけ", "うざい", "ウザい",
        "きもい", "キモい", "気持ち悪い",
        // 否定
        "最悪", "だめ", "ダメ", "無理", "むり",
        "ありえない", "ありえん", "信じられない",
        // 不安・心配
        "心配", "不安", "怖い", "こわい", "恐い",
        // 寂しさ
        "寂しい", "さみしい", "さびしい", "孤独",
        // 苦しみ
        "苦しい", "くるしい", "痛い", "いたい",
        // 後悔・謝罪（ネガティブ文脈）
        "後悔", "失敗", "ミス",
        // カジュアルネガティブ
        "めんどくさい", "めんどい", "メンドイ",
        "やだ", "ヤダ", "嫌だ", "いやだ",
        "つまんない", "つまらない", "退屈",
        "病む", "やむ", "病み", "しにたい", "死にたい",
        "泣く", "泣いた", "泣ける", "泣き",
        // en
        "sad", "angry", "upset", "hate", "annoyed", "tired", "stressed", "depressed",
        "lonely", "bored", "terrible", "horrible", "awful", "worst", "ugh", "frustrated",
        // ko
        "슬퍼", "화나", "짜증", "힘들어", "싫어", "외로워", "지쳐", "최악", "우울", "불안",
        // zh (Simplified + Traditional)
        "难过", "難過", "生气", "生氣", "烦", "煩", "累", "讨厌", "討厭",
        "伤心", "傷心", "孤单", "孤單", "无聊", "無聊", "糟糕", "焦虑", "焦慮", "崩溃", "崩潰"
    ]

    /// ポジティブ絵文字パターン
    private let positiveEmojiSet: Set<Character> = [
        "😊", "😄", "😃", "😁", "😆", "🥰", "😍", "🤩", "😘", "😗",
        "😙", "😚", "🥺", "😻", "💕", "💖", "💗", "💓", "💞", "💘",
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🤍", "🖤", "❣️", "💝",
        "♥️", "😂", "🤣", "😹", "👍", "👏", "🙌", "🎉", "🎊",
        "✨", "⭐", "🌟", "💫", "🔥", "💪", "🤗", "😎", "🥳",
        "🌸", "🌺", "🌻", "🌹", "💐", "🍀", "🌈",
        "🫶", "🫂", "😊", "🤭", "☺️", "🙈", "💯", "⚡"
    ]

    /// ネガティブ絵文字パターン
    private let negativeEmojiSet: Set<Character> = [
        "😢", "😭", "😿", "😞", "😔", "😟", "😕", "🙁", "☹️",
        "😣", "😖", "😫", "😩", "😤", "😠", "😡", "🤬",
        "💔", "😰", "😨", "😱", "😥", "😓", "👎"
    ]

    private func detectSentimentEnhanced(_ message: ChatMessage) -> Sentiment {
        // スタンプ・写真・動画は基本的にポジティブ（感情表現として使われる）
        switch message.eventType {
        case .sticker:
            return .positive
        case .photo, .video:
            return .positive
        case .call:
            return .positive
        case .missedCall:
            return .neutral
        case .text:
            break
        default:
            return .neutral
        }

        let content = message.content
        let lowered = content.lowercased()

        var positiveScore: Double = 0
        var negativeScore: Double = 0

        // 1. キーワードマッチ（重み: 各+2.0）
        for word in lowercasedPositiveWords {
            if lowered.contains(word) {
                positiveScore += 2.0
            }
        }
        for word in lowercasedNegativeWords {
            if lowered.contains(word) {
                negativeScore += 2.0
            }
        }

        // 2+3. 絵文字検出 + Unicode絵文字レンジ（1回のループで処理）
        for scalar in content.unicodeScalars {
            let c = Character(scalar)
            if positiveEmojiSet.contains(c) {
                positiveScore += 1.5
            } else if negativeEmojiSet.contains(c) {
                negativeScore += 1.5
            }

            let v = scalar.value
            if (0x1F600...0x1F64F).contains(v) ||  // Emoticons
               (0x1F300...0x1F5FF).contains(v) ||  // Misc Symbols
               (0x1F680...0x1F6FF).contains(v) ||  // Transport
               (0x1F900...0x1F9FF).contains(v) ||  // Supplemental
               (0x1FA00...0x1FA6F).contains(v) ||  // Chess, Extended-A
               (0x2600...0x26FF).contains(v) ||    // Misc Symbols
               (0x2700...0x27BF).contains(v) {     // Dingbats
                positiveScore += 0.5
            }
        }

        // 4. 笑い表現カウント（重み: +1.0ずつ）
        let kanjiLaughCount = content.components(separatedBy: "笑").count - 1
        positiveScore += Double(kanjiLaughCount) * 1.0
        // 連続w（2文字以上）のみカウント（英単語中の w 誤検出を防止）
        if let regex = wwRegex {
            let wwCount = regex.numberOfMatches(in: content, range: NSRange(content.startIndex..., in: content))
            positiveScore += Double(min(wwCount, 5)) * 1.0
        }

        // 5. 感嘆符（重み: +0.5ずつ、上限3）
        let exclamationCount = content.filter { $0 == "!" || $0 == "！" }.count
        positiveScore += Double(min(exclamationCount, 3)) * 0.5

        // 6. ハートマーク文字列（♡ ♥ ハート）
        if content.contains("♡") || content.contains("♥") || content.contains("ハート") {
            positiveScore += 1.5
        }

        // 判定（閾値ベース）
        if positiveScore >= 1.0 && positiveScore > negativeScore {
            return .positive
        } else if negativeScore >= 1.0 && negativeScore > positiveScore {
            return .negative
        } else {
            return .neutral
        }
    }

    /// 愛の言葉分析
    private func analyzeLoveWords(
        messages: [ChatMessage],
        selfName: String,
        partnerName: String
    ) -> LoveWordsAnalysis {
        let textMessages = messages.filter { $0.eventType == .text }

        var selfLoveWordCounts: [String: Int] = [:]
        var partnerLoveWordCounts: [String: Int] = [:]

        for message in textMessages {
            let content = message.content.lowercased()

            for word in loveWords {
                let lowercasedWord = word.lowercased()
                if content.contains(lowercasedWord) {
                    if message.senderName == selfName {
                        selfLoveWordCounts[word, default: 0] += 1
                    } else {
                        partnerLoveWordCounts[word, default: 0] += 1
                    }
                }
            }
        }

        let selfTop = selfLoveWordCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { PhraseCount(phrase: $0.key, count: $0.value) }

        let partnerTop = partnerLoveWordCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { PhraseCount(phrase: $0.key, count: $0.value) }

        let selfTotal = selfLoveWordCounts.values.reduce(0, +)
        let partnerTotal = partnerLoveWordCounts.values.reduce(0, +)

        return LoveWordsAnalysis(
            selfLoveWords: Array(selfTop),
            partnerLoveWords: Array(partnerTop),
            selfTotalCount: selfTotal,
            partnerTotalCount: partnerTotal
        )
    }

    /// 習慣統計を分析
    private func analyzeHabits(
        messages: [ChatMessage],
        selfName: String
    ) -> HabitsStatistics {
        let nonSystemMessages = messages.filter { $0.eventType != .system }
        let calendar = Calendar.current

        // 曜日別パターン
        var selfWeekdayCounts = [Int: Int]()
        var partnerWeekdayCounts = [Int: Int]()

        for message in nonSystemMessages {
            let weekday = calendar.component(.weekday, from: message.timestamp)

            if message.senderName == selfName {
                selfWeekdayCounts[weekday, default: 0] += 1
            } else {
                partnerWeekdayCounts[weekday, default: 0] += 1
            }
        }

        let weekdayPatterns = (1...7).map { day in
            StoredWeekdayPattern(
                dayOfWeek: day,
                selfCount: selfWeekdayCounts[day, default: 0],
                partnerCount: partnerWeekdayCounts[day, default: 0]
            )
        }

        // 時間帯別パターン
        let timeRanges = [
            (0, "0-3"),
            (3, "3-6"),
            (6, "6-9"),
            (9, "9-12"),
            (12, "12-15"),
            (15, "15-18"),
            (18, "18-21"),
            (21, "21-24")
        ]

        var selfTimeCounts = [Int: Int]()
        var partnerTimeCounts = [Int: Int]()

        for message in nonSystemMessages {
            let hour = calendar.component(.hour, from: message.timestamp)
            let rangeIndex = hour / 3

            if message.senderName == selfName {
                selfTimeCounts[rangeIndex, default: 0] += 1
            } else {
                partnerTimeCounts[rangeIndex, default: 0] += 1
            }
        }

        let timePatterns = timeRanges.enumerated().map { index, range in
            StoredTimePattern(
                hourRange: range.1,
                startHour: range.0,
                selfCount: selfTimeCounts[index, default: 0],
                partnerCount: partnerTimeCounts[index, default: 0]
            )
        }

        // 最もアクティブな曜日
        let mostActiveDay = weekdayPatterns.max(by: { $0.totalCount < $1.totalCount })?.dayName ?? "-"

        // 最もアクティブな時間帯
        let mostActiveTime = timePatterns.max(by: { $0.totalCount < $1.totalCount })?.hourRange ?? "-"

        return HabitsStatistics(
            weekdayPatterns: weekdayPatterns,
            timePatterns: timePatterns,
            mostActiveDay: mostActiveDay,
            mostActiveTime: mostActiveTime
        )
    }

    /// 行動統計を分析（1回のループで全カウント）
    private func analyzeActions(
        messages: [ChatMessage],
        selfName: String,
        allParticipantNames: [String]? = nil
    ) -> ActionsStatistics {
        let isGroup = (allParticipantNames?.count ?? 0) > 2

        var selfText = 0, partnerText = 0
        var selfSticker = 0, partnerSticker = 0
        var selfPhoto = 0, partnerPhoto = 0
        var selfVideo = 0, partnerVideo = 0
        var selfCall = 0, partnerCall = 0
        var selfQuestion = 0, partnerQuestion = 0
        var selfProposal = 0, partnerProposal = 0
        var selfEmotional = 0, partnerEmotional = 0

        // グループ時のメンバー別カウント用辞書（actionType -> memberName -> count）
        var memberText: [String: Int] = [:]
        var memberSticker: [String: Int] = [:]
        var memberPhoto: [String: Int] = [:]
        var memberVideo: [String: Int] = [:]
        var memberCall: [String: Int] = [:]
        var memberQuestion: [String: Int] = [:]
        var memberProposal: [String: Int] = [:]
        var memberEmotional: [String: Int] = [:]

        for msg in messages {
            let isSelf = msg.senderName == selfName
            let sender = msg.senderName

            switch msg.eventType {
            case .text:
                if isSelf { selfText += 1 } else { partnerText += 1 }
                if isGroup { memberText[sender, default: 0] += 1 }
                if msg.isQuestion {
                    if isSelf { selfQuestion += 1 } else { partnerQuestion += 1 }
                    if isGroup { memberQuestion[sender, default: 0] += 1 }
                }
                if msg.containsProposal {
                    if isSelf { selfProposal += 1 } else { partnerProposal += 1 }
                    if isGroup { memberProposal[sender, default: 0] += 1 }
                }
                if msg.hasEmotionalSymbols {
                    if isSelf { selfEmotional += 1 } else { partnerEmotional += 1 }
                    if isGroup { memberEmotional[sender, default: 0] += 1 }
                }
            case .sticker:
                if isSelf { selfSticker += 1 } else { partnerSticker += 1 }
                if isGroup { memberSticker[sender, default: 0] += 1 }
            case .photo:
                if isSelf { selfPhoto += 1 } else { partnerPhoto += 1 }
                if isGroup { memberPhoto[sender, default: 0] += 1 }
            case .video:
                if isSelf { selfVideo += 1 } else { partnerVideo += 1 }
                if isGroup { memberVideo[sender, default: 0] += 1 }
            case .call, .missedCall:
                if isSelf { selfCall += 1 } else { partnerCall += 1 }
                if isGroup { memberCall[sender, default: 0] += 1 }
            default:
                break
            }
        }

        let patterns: [StoredActionPattern] = [
            StoredActionPattern(type: "textMessage", selfCount: selfText, partnerCount: partnerText, description: String(localized: "送ったテキストメッセージ", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberText : nil),
            StoredActionPattern(type: "sticker", selfCount: selfSticker, partnerCount: partnerSticker, description: String(localized: "送ったスタンプ", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberSticker : nil),
            StoredActionPattern(type: "photo", selfCount: selfPhoto, partnerCount: partnerPhoto, description: String(localized: "送った写真", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberPhoto : nil),
            StoredActionPattern(type: "video", selfCount: selfVideo, partnerCount: partnerVideo, description: String(localized: "送った動画", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberVideo : nil),
            StoredActionPattern(type: "call", selfCount: selfCall, partnerCount: partnerCall, description: String(localized: "通話_action", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberCall : nil),
            StoredActionPattern(type: "question", selfCount: selfQuestion, partnerCount: partnerQuestion, description: String(localized: "質問を含むメッセージ", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberQuestion : nil),
            StoredActionPattern(type: "proposal", selfCount: selfProposal, partnerCount: partnerProposal, description: String(localized: "提案を含むメッセージ", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberProposal : nil),
            StoredActionPattern(type: "emotionalMessage", selfCount: selfEmotional, partnerCount: partnerEmotional, description: String(localized: "感情表現を含むメッセージ", bundle: LanguageManager.appBundle), memberCounts: isGroup ? memberEmotional : nil),
        ]

        return ActionsStatistics(actionPatterns: patterns)
    }

    /// 記録統計を分析
    private func analyzeRecords(
        messages: [ChatMessage],
        selfName: String,
        allParticipantNames: [String]? = nil
    ) -> RecordsStatistics {
        let nonSystemMessages = messages.filter { $0.eventType != .system }
        let totalMessages = nonSystemMessages.count
        let calendar = Calendar.current

        // 日数計算
        guard let firstDate = nonSystemMessages.first?.timestamp,
              let lastDate = nonSystemMessages.last?.timestamp else {
            return RecordsStatistics(
                totalMessages: 0,
                totalDays: 0,
                averagePerDay: 0,
                longestStreak: 0,
                selfRatio: 0.5,
                mostActiveDay: "-",
                mostActiveTime: "-"
            )
        }

        let totalDays = max(1, calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)

        // 1日平均
        let averagePerDay = Double(totalMessages) / Double(totalDays)

        // 自分の比率
        let selfMessages = nonSystemMessages.filter { $0.senderName == selfName }.count
        let selfRatio = totalMessages > 0 ? Double(selfMessages) / Double(totalMessages) : 0.5

        // 最長連続日数
        let longestStreak = calculateLongestStreak(messages: nonSystemMessages)

        // 曜日・時間帯パターン
        var weekdayCounts = [Int: Int]()
        var timeCounts = [Int: Int]()

        for message in nonSystemMessages {
            let weekday = calendar.component(.weekday, from: message.timestamp)
            weekdayCounts[weekday, default: 0] += 1

            let hour = calendar.component(.hour, from: message.timestamp)
            let rangeIndex = hour / 3
            timeCounts[rangeIndex, default: 0] += 1
        }

        let mostActiveWeekday = weekdayCounts.max(by: { $0.value < $1.value })?.key ?? 1
        let mostActiveDay = StoredWeekdayPattern.localizedDayName(for: mostActiveWeekday)

        let timeRanges = ["0-3", "3-6", "6-9", "9-12", "12-15", "15-18", "18-21", "21-24"]
        let mostActiveTimeIndex = timeCounts.max(by: { $0.value < $1.value })?.key ?? 0
        let mostActiveTime = timeRanges[mostActiveTimeIndex]

        // --- Fun Statistics ---

        // 最速返信タイム & 既読スルー推定
        var fastestSelfReply: TimeInterval?
        var fastestPartnerReply: TimeInterval?
        var selfReadIgnore = 0
        var partnerReadIgnore = 0
        let readIgnoreThreshold: TimeInterval = 3 * 60 * 60

        // グループ時: メンバー別トラッキング
        let isGroup = (allParticipantNames?.count ?? 0) > 2
        var memberFastReply: [String: TimeInterval] = [:]
        var memberReadIgnore: [String: Int] = [:]

        for i in 1..<nonSystemMessages.count {
            let prev = nonSystemMessages[i - 1]
            let curr = nonSystemMessages[i]
            guard prev.senderName != curr.senderName else { continue }

            let interval = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard interval > 0, interval <= 24 * 60 * 60 else { continue }

            if curr.senderName == selfName {
                if fastestSelfReply == nil || interval < fastestSelfReply! {
                    fastestSelfReply = interval
                }
                if interval >= readIgnoreThreshold {
                    selfReadIgnore += 1
                }
            } else {
                if fastestPartnerReply == nil || interval < fastestPartnerReply! {
                    fastestPartnerReply = interval
                }
                if interval >= readIgnoreThreshold {
                    partnerReadIgnore += 1
                }
            }

            // グループ時: メンバー別最速返信・既読スルー
            if isGroup {
                let sender = curr.senderName
                if let existing = memberFastReply[sender] {
                    if interval < existing { memberFastReply[sender] = interval }
                } else {
                    memberFastReply[sender] = interval
                }
                if interval >= readIgnoreThreshold {
                    memberReadIgnore[sender, default: 0] += 1
                }
            }
        }

        // 深夜トーク率（0:00-5:00）
        let lateNightCount = nonSystemMessages.filter { $0.isLateNightMessage }.count
        let lateNightRate = totalMessages > 0 ? Double(lateNightCount) / Double(totalMessages) : 0

        var stats = RecordsStatistics(
            totalMessages: totalMessages,
            totalDays: totalDays,
            averagePerDay: averagePerDay,
            longestStreak: longestStreak,
            selfRatio: selfRatio,
            mostActiveDay: mostActiveDay,
            mostActiveTime: mostActiveTime
        )
        stats.fastestSelfReply = fastestSelfReply
        stats.fastestPartnerReply = fastestPartnerReply
        stats.lateNightRate = lateNightRate
        stats.estimatedSelfReadIgnore = selfReadIgnore
        stats.estimatedPartnerReadIgnore = partnerReadIgnore
        stats.memberFastestReply = isGroup ? memberFastReply : nil
        stats.memberReadIgnoreCount = isGroup ? memberReadIgnore : nil
        return stats
    }

    // MARK: - Group Chat Member Analysis

    /// メンバー別フレーズ分析
    private func analyzeMemberPhrases(
        messages: [ChatMessage],
        participantNames: [String]
    ) -> [MemberPhraseAnalysis] {
        let textMessages = messages.filter { $0.eventType == .text }

        return participantNames.map { memberName in
            let memberMessages = textMessages.filter { $0.senderName == memberName }
            var phraseCounts: [String: Int] = [:]

            for message in memberMessages {
                let phrases = extractPhrases(from: message.content)
                for phrase in phrases {
                    phraseCounts[phrase, default: 0] += 1
                }
            }

            let topPhrases = phraseCounts.sorted { $0.value > $1.value }
                .prefix(5)
                .map { PhraseCount(phrase: $0.key, count: $0.value) }

            return MemberPhraseAnalysis(
                memberName: memberName,
                topPhrases: Array(topPhrases)
            )
        }
    }

    /// メンバー別愛情表現分析
    private func analyzeMemberLoveWords(
        messages: [ChatMessage],
        participantNames: [String]
    ) -> [MemberLoveWordsEntry] {
        let textMessages = messages.filter { $0.eventType == .text }

        return participantNames.map { memberName in
            let memberMessages = textMessages.filter { $0.senderName == memberName }
            var wordCounts: [String: Int] = [:]

            for message in memberMessages {
                let content = message.content.lowercased()
                for word in loveWords {
                    let lowercasedWord = word.lowercased()
                    if content.contains(lowercasedWord) {
                        wordCounts[word, default: 0] += 1
                    }
                }
            }

            let topWords = wordCounts.sorted { $0.value > $1.value }
                .prefix(5)
                .map { PhraseCount(phrase: $0.key, count: $0.value) }
            let totalCount = wordCounts.values.reduce(0, +)

            return MemberLoveWordsEntry(
                memberName: memberName,
                loveWords: Array(topWords),
                totalCount: totalCount
            )
        }
    }

    /// 最長連続日数を計算
    private func calculateLongestStreak(messages: [ChatMessage]) -> Int {
        let calendar = Calendar.current
        var dates = Set<String>()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for message in messages {
            dates.insert(formatter.string(from: message.timestamp))
        }

        guard dates.count > 1 else { return dates.count }

        let sortedDates = dates.sorted()
        var longestStreak = 1
        var currentStreak = 1

        for i in 1..<sortedDates.count {
            guard let prevDate = formatter.date(from: sortedDates[i-1]),
                  let currDate = formatter.date(from: sortedDates[i]) else { continue }

            let daysDiff = calendar.dateComponents([.day], from: prevDate, to: currDate).day ?? 0

            if daysDiff == 1 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        return longestStreak
    }
}
