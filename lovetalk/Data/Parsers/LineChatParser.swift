import Foundation

// MARK: - LINE Chat Parser
/// LINEトーク履歴をパースする
final class LineChatParser {
    private let typeDetector = MessageTypeDetector()

    // MARK: - Regex Patterns

    /// 日付行パターン（例: "2024/1/15(月)"）
    private let dateLinePattern = #"^(\d{4})[/\.\-](\d{1,2})[/\.\-](\d{1,2})\(([日月火水木金土])\)\s*$"#

    /// 日付行パターン英語版（例: "2026.01.24 Saturday"）
    private let dateLinePatternEN = #"^(\d{4})[/\.\-](\d{1,2})[/\.\-](\d{1,2})\s+(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s*$"#

    /// 時刻パターン（24時間制: "21:30"）
    private let time24Pattern = #"^(\d{1,2}):(\d{2})$"#

    /// 時刻パターン（12時間制日本語: "午後9:30" / "午前10:00"）
    private let time12JPPattern = #"^(午前|午後)(\d{1,2}):(\d{2})$"#

    /// 時刻パターン（12時間制英語: "9:30 PM" / "10:00 AM"）
    private let time12ENPattern = #"^(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)$"#

    // MARK: - Public Methods

    /// トーク履歴テキストをパースしてChatSessionを生成
    func parse(_ text: String, title: String = "トーク履歴") throws -> ChatSession {
        // ストリーミング処理: 行配列を一括生成せず1行ずつ処理
        var chatNameFromHeader: String?
        var messages: [ChatMessage] = []
        var currentDate: Date?
        var participantCounts: [String: ParticipantCounter] = [:]
        var usesTabDelimiter = false
        var hasGroupSystemMessage = false
        var isFirstNonEmptyLine = true
        var linesCheckedForDelimiter = 0

        text.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { return }

            // 先頭行からチャット名を抽出
            if isFirstNonEmptyLine {
                isFirstNonEmptyLine = false
                chatNameFromHeader = self.extractChatName(from: trimmedLine)
            }

            // 最初の100行でデリミタ形式を判定
            if !usesTabDelimiter && linesCheckedForDelimiter < 100 {
                linesCheckedForDelimiter += 1
                let tabParts = line.split(separator: "\t", omittingEmptySubsequences: false)
                if tabParts.count >= 3 {
                    usesTabDelimiter = true
                }
            }

            // グループ特有のシステムメッセージを検出
            if !hasGroupSystemMessage && self.isGroupSpecificContent(trimmedLine) {
                hasGroupSystemMessage = true
            }

            // 日付行かチェック
            if let date = self.parseDateLine(trimmedLine) {
                currentDate = date
                return
            }

            // メッセージ行かチェック
            if let parsedMessage = self.parseMessageLine(trimmedLine, currentDate: currentDate, tabOnly: usesTabDelimiter) {
                messages.append(parsedMessage)

                // 参加者カウント更新（空の送信者名はスキップ）
                if !parsedMessage.senderName.isEmpty {
                    var counter = participantCounts[parsedMessage.senderName] ?? ParticipantCounter()
                    counter.update(with: parsedMessage.eventType)
                    participantCounts[parsedMessage.senderName] = counter
                }
            }
        }

        // ファントムparticipantを除外（システムメッセージのみの送信者）
        if participantCounts.count > 2 {
            let filtered = participantCounts.filter { _, counter in
                (counter.text + counter.sticker + counter.photo + counter.video + counter.call) > 0
            }
            if filtered.count >= 2 {
                participantCounts = filtered
            }
        }

        // 表示名変更によるparticipant重複を統合
        if participantCounts.count > 2 {
            let result = mergeNameChangedParticipants(
                messages: messages,
                participantCounts: participantCounts
            )
            messages = result.messages
            participantCounts = result.participantCounts
        }

        // パースノイズ除去（グループチャットでない場合のみ）
        // 3人目以降の参加者が全体メッセージ数の1%未満ならノイズとして除外
        if participantCounts.count > 2 && !hasGroupSystemMessage {
            let totalMessages = participantCounts.values.map(\.total).reduce(0, +)
            let threshold = max(1, Int(Double(totalMessages) * 0.01))
            let sortedByCount = participantCounts.sorted { $0.value.total > $1.value.total }

            // 上位2名は必ず保持、3人目以降はしきい値で判断
            var kept = Dictionary(uniqueKeysWithValues: sortedByCount.prefix(2).map { ($0.key, $0.value) })
            for (name, counter) in sortedByCount.dropFirst(2) {
                if counter.total >= threshold {
                    kept[name] = counter
                }
            }
            if kept.count >= 2 {
                participantCounts = kept
            }
        }

        // 参加者リスト生成
        let participants = participantCounts.map { name, counter in
            ChatParticipant(
                name: name,
                messageCount: counter.total,
                textMessageCount: counter.text,
                stickerCount: counter.sticker,
                photoCount: counter.photo,
                videoCount: counter.video,
                callCount: counter.call
            )
        }.sorted { $0.messageCount > $1.messageCount }

        // グループ通話の通話時間を算出（開始→終了のペアリング）
        messages = calculateGroupCallDurations(messages: messages)

        // バリデーション
        guard !messages.isEmpty else {
            throw AnalysisError.parsingFailed(reason: "メッセージが見つかりませんでした")
        }

        guard !participants.isEmpty else {
            throw AnalysisError.noParticipantsFound
        }

        // 1対1チェック（警告のみ、エラーにはしない）
        let isOneOnOne = participants.count == 2

        // ファイル名からトーク相手の名前を抽出
        let partnerNameFromTitle = extractPartnerName(from: title)

        // タイトル生成と自分の名前推定
        var sessionTitle: String
        var estimatedSelfName: String?

        if isOneOnOne {
            if let partnerName = partnerNameFromTitle,
               participants.contains(where: { $0.name == partnerName }) {
                sessionTitle = String(format: String(localized: "%@とのトーク", bundle: LanguageManager.appBundle), partnerName)
                estimatedSelfName = participants.first { $0.name != partnerName }?.name
            } else if let headerName = chatNameFromHeader,
                      participants.contains(where: { $0.name == headerName }) {
                sessionTitle = String(format: String(localized: "%@とのトーク", bundle: LanguageManager.appBundle), headerName)
                estimatedSelfName = participants.first { $0.name != headerName }?.name
            } else {
                let sortedByCount = participants.sorted { $0.messageCount < $1.messageCount }
                if sortedByCount.count >= 2 {
                    sessionTitle = String(format: String(localized: "%@とのトーク", bundle: LanguageManager.appBundle), sortedByCount[1].name)
                    estimatedSelfName = sortedByCount[0].name
                } else if let first = sortedByCount.first {
                    sessionTitle = String(format: String(localized: "%@とのトーク", bundle: LanguageManager.appBundle), first.name)
                    estimatedSelfName = nil
                } else {
                    sessionTitle = title
                    estimatedSelfName = nil
                }
            }
        } else {
            sessionTitle = chatNameFromHeader ?? title
        }

        // トーク内容の言語を自動検出
        let detectedLanguage = ChatLanguage.detect(from: messages)

        return ChatSession(
            title: sessionTitle,
            messages: messages,
            participants: participants,
            estimatedSelfName: estimatedSelfName,
            detectedLanguage: detectedLanguage
        )
    }

    // MARK: - Private Methods

    /// LINEエクスポートヘッダー行からチャット名を抽出
    /// 例: "[LINE] グループ名のトーク履歴" → "グループ名"
    /// 例: "[LINE] 友達名とのトーク履歴" → "友達名"
    private func extractChatName(from line: String) -> String? {
        // "[LINE] " プレフィックスを除去
        guard line.hasPrefix("[LINE]") else { return nil }
        var name = String(line.dropFirst("[LINE]".count)).trimmingCharacters(in: .whitespaces)
        // サフィックスを除去（長い順にマッチ）
        let suffixes = [
            // Japanese
            "のトーク履歴", "とのトーク履歴", "のトーク", "とのトーク",
            // English
            " Chat History", " chat history", "'s Chat", "'s chat",
            // Korean
            "의 대화 기록", "과의 대화", "와의 대화", "의 대화",
            // Chinese (Simplified + Traditional)
            "的聊天记录", "的聊天紀錄", "的聊天"
        ]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// ファイル名からトーク相手の名前を抽出
    /// 例: "[LINE] 〇〇とのトーク.txt" → "〇〇"
    private func extractPartnerName(from filename: String) -> String? {
        let patterns = [
            #"\[LINE\]\s*(.+?)とのトーク"#,   // [LINE] 〇〇とのトーク
            #"^(.+?)とのトーク"#,              // 〇〇とのトーク
            #"\[LINE\]\s*Chat with (.+)"#,     // [LINE] Chat with Name
            #"^Chat with (.+)"#,               // Chat with Name
            #"\[LINE\]\s*(.+?)과의 대화"#,      // [LINE] 〇〇과의 대화
            #"\[LINE\]\s*(.+?)와의 대화"#,      // [LINE] 〇〇와의 대화
            #"\[LINE\]\s*(.+?)的聊天"#          // [LINE] 〇〇的聊天
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
               let nameRange = Range(match.range(at: 1), in: filename) {
                let name = String(filename[nameRange]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    return name
                }
            }
        }

        return nil
    }

    /// 日付行をパース（日本語形式 + 英語形式対応）
    private func parseDateLine(_ line: String) -> Date? {
        // 日本語形式: "2024/1/15(月)"
        let patterns = [dateLinePattern, dateLinePatternEN]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            guard let yearRange = Range(match.range(at: 1), in: line),
                  let monthRange = Range(match.range(at: 2), in: line),
                  let dayRange = Range(match.range(at: 3), in: line),
                  let year = Int(line[yearRange]),
                  let month = Int(line[monthRange]),
                  let day = Int(line[dayRange]) else {
                continue
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

        return nil
    }

    /// メッセージ行をパース（タブ区切り → スペース区切りの順で試行）
    /// tabOnly: trueの場合、スペース区切りフォールバックを無効化（複数行メッセージの誤パース防止）
    private func parseMessageLine(_ line: String, currentDate: Date?, tabOnly: Bool = false) -> ChatMessage? {
        // 1) タブ区切りを試行（標準LINEエクスポート形式）
        let tabParts = line.split(separator: "\t", omittingEmptySubsequences: false).map { String($0) }

        if tabParts.count >= 3 {
            let timePart = tabParts[0]
            let senderName = tabParts[1]
            let content = tabParts.dropFirst(2).joined(separator: "\t")

            if let timestamp = parseTime(timePart, baseDate: currentDate) {
                let trimmedSender = senderName.trimmingCharacters(in: .whitespaces)
                let eventType = typeDetector.detect(content)

                // 送信者が空の場合：システムメッセージまたはグループ通話終了のみ許可
                if trimmedSender.isEmpty {
                    if eventType == .call || eventType == .system {
                        let callDuration = typeDetector.extractCallDuration(content)
                        return ChatMessage(
                            timestamp: timestamp,
                            senderName: "",
                            content: content,
                            eventType: eventType,
                            rawLine: line,
                            callDurationSeconds: callDuration
                        )
                    }
                } else {
                    let callDuration = typeDetector.extractCallDuration(content)
                    return ChatMessage(
                        timestamp: timestamp,
                        senderName: senderName,
                        content: content,
                        eventType: eventType,
                        rawLine: line,
                        callDurationSeconds: callDuration
                    )
                }
            }
        }

        // タブ区切りファイルの場合、スペース区切りは試行しない（継続行の誤パース防止）
        guard !tabOnly else { return nil }

        // 2) スペース区切りを試行（英語版LINEエクスポート形式）
        // 形式: "HH:MM SenderName Content"
        // SenderNameはASCIIスペースを含まない（全角スペースは可）
        let spaceParts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false).map { String($0) }

        guard spaceParts.count >= 3 else { return nil }

        let timePart = spaceParts[0]
        let senderAndContent = spaceParts[1] + " " + spaceParts[2]

        guard let timestamp = parseTime(timePart, baseDate: currentDate) else {
            return nil
        }

        // SenderNameの境界を見つける: 最初のASCIIスペースで分割
        // LINE表示名はASCIIスペースを含まない（全角スペース U+3000 は含む場合あり）
        let remainder = spaceParts.dropFirst().joined(separator: " ")
        guard let firstSpace = remainder.firstIndex(of: " ") else { return nil }
        let senderName = String(remainder[remainder.startIndex..<firstSpace])
        let content = String(remainder[remainder.index(after: firstSpace)...])

        guard !senderName.isEmpty else { return nil }

        // ファントム送信者をスキップ（例: "☎ Missed call" → "☎"が送信者になる問題）
        if senderName == "☎" || senderName == "☎️" {
            return nil
        }

        let eventType = typeDetector.detect(content)
        let callDuration = typeDetector.extractCallDuration(content)

        return ChatMessage(
            timestamp: timestamp,
            senderName: senderName,
            content: content,
            eventType: eventType,
            rawLine: line,
            callDurationSeconds: callDuration
        )
    }

    /// 時刻文字列をパース（24時間制 / 12時間制日本語 / 12時間制英語 対応）
    private func parseTime(_ timeString: String, baseDate: Date?) -> Date? {
        let trimmed = timeString.trimmingCharacters(in: .whitespaces)
        var hour: Int?
        var minute: Int?

        // 1) 24時間制: "21:30"
        if let regex24 = try? NSRegularExpression(pattern: time24Pattern),
           let match = regex24.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let hRange = Range(match.range(at: 1), in: trimmed),
           let mRange = Range(match.range(at: 2), in: trimmed) {
            hour = Int(trimmed[hRange])
            minute = Int(trimmed[mRange])
        }

        // 2) 12時間制日本語: "午後9:30" / "午前10:00"
        if hour == nil,
           let regex12JP = try? NSRegularExpression(pattern: time12JPPattern),
           let match = regex12JP.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let periodRange = Range(match.range(at: 1), in: trimmed),
           let hRange = Range(match.range(at: 2), in: trimmed),
           let mRange = Range(match.range(at: 3), in: trimmed) {
            let period = String(trimmed[periodRange])
            var h = Int(trimmed[hRange]) ?? 0
            let m = Int(trimmed[mRange]) ?? 0
            // 午後 = PM: 12時以外は+12、午前12時は0時
            if period == "午後" && h != 12 { h += 12 }
            if period == "午前" && h == 12 { h = 0 }
            hour = h
            minute = m
        }

        // 3) 12時間制英語: "9:30 PM" / "10:00 AM"
        if hour == nil,
           let regex12EN = try? NSRegularExpression(pattern: time12ENPattern),
           let match = regex12EN.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let hRange = Range(match.range(at: 1), in: trimmed),
           let mRange = Range(match.range(at: 2), in: trimmed),
           let periodRange = Range(match.range(at: 3), in: trimmed) {
            let period = String(trimmed[periodRange]).uppercased()
            var h = Int(trimmed[hRange]) ?? 0
            let m = Int(trimmed[mRange]) ?? 0
            if period == "PM" && h != 12 { h += 12 }
            if period == "AM" && h == 12 { h = 0 }
            hour = h
            minute = m
        }

        guard let h = hour, let m = minute else { return nil }

        let calendar = Calendar.current
        let base = baseDate ?? Date()

        var components = calendar.dateComponents([.year, .month, .day], from: base)
        components.hour = h
        components.minute = m
        components.second = 0

        return calendar.date(from: components)
    }

    // MARK: - Group Call Duration

    /// グループ通話の開始→終了をペアリングして通話時間を算出
    private func calculateGroupCallDurations(messages: [ChatMessage]) -> [ChatMessage] {
        // 開始メッセージのインデックスを逆順で探す（最も近い開始とペアリング）
        var lastGroupCallStartTime: Date?
        var result = messages

        for i in 0..<result.count {
            let msg = result[i]

            // グループ通話開始を記録
            let groupCallStartPatterns = [
                "グループ通話が開始されました", "Group call started", "Group video chat started",
                "그룹 통화가 시작되었습니다", "群组通话已开始", "群組通話已開始"
            ]
            if msg.eventType == .system && groupCallStartPatterns.contains(where: { msg.content.contains($0) }) {
                lastGroupCallStartTime = msg.timestamp
                continue
            }

            // グループ通話終了 → 開始とペアリングして時間を算出
            if msg.eventType == .call && typeDetector.isGroupCallEnd(msg.content) {
                var duration: Int? = nil
                if let startTime = lastGroupCallStartTime {
                    let seconds = Int(msg.timestamp.timeIntervalSince(startTime))
                    if seconds > 0 {
                        duration = seconds
                    }
                }
                lastGroupCallStartTime = nil

                // callDurationSecondsを設定した新しいメッセージで置き換え
                result[i] = ChatMessage(
                    id: msg.id,
                    timestamp: msg.timestamp,
                    senderName: msg.senderName,
                    content: msg.content,
                    eventType: .call,
                    rawLine: msg.rawLine,
                    callDurationSeconds: duration
                )
            }
        }

        return result
    }

    // MARK: - Group Chat Detection

    /// グループチャット特有のシステムメッセージかどうか判定
    /// 1対1トークには存在しないメッセージパターンで判断する
    private func isGroupSpecificContent(_ line: String) -> Bool {
        let groupPatterns = [
            // Japanese
            "をグループに招待しました",
            "がグループに招待されました",
            "がグループに参加しました",
            "グループ名を変更しました",
            "が参加しました",
            "が退出しました",
            "グループ通話が開始されました",
            "グループ通話が終了しました",
            // English
            "was invited to the group",
            "joined the chat",
            "left the chat",
            "changed the group name",
            "Group call started",
            "Group call ended",
            // Korean
            "님을 초대했습니다",
            "님이 들어왔습니다",
            "님이 나갔습니다",
            "그룹명을 변경했습니다",
            // Chinese (Simplified + Traditional)
            "邀请了", "邀請了",
            "加入了聊天", "加入了聊天室",
            "离开了聊天", "離開了聊天",
            "更改了群组名称", "更改了群組名稱",
        ]
        return groupPatterns.contains { line.contains($0) }
    }

    // MARK: - Name Change Merge

    /// 表示名変更による参加者重複を統合
    /// 時間帯が重ならない参加者を同一人物と判定し、最新の名前に統合する
    private func mergeNameChangedParticipants(
        messages: [ChatMessage],
        participantCounts: [String: ParticipantCounter]
    ) -> (messages: [ChatMessage], participantCounts: [String: ParticipantCounter]) {
        // 各参加者のメッセージ時間範囲を算出
        var timeRanges: [String: (first: Date, last: Date)] = [:]
        for msg in messages {
            guard participantCounts.keys.contains(msg.senderName) else { continue }
            if let existing = timeRanges[msg.senderName] {
                timeRanges[msg.senderName] = (
                    first: min(existing.first, msg.timestamp),
                    last: max(existing.last, msg.timestamp)
                )
            } else {
                timeRanges[msg.senderName] = (first: msg.timestamp, last: msg.timestamp)
            }
        }

        // 最初のメッセージ時刻順にソート
        let sorted = timeRanges.sorted { $0.value.first < $1.value.first }

        // 貪欲法で2つの「人物スロット」に振り分け
        // 時間帯が重ならない参加者は同一人物（表示名変更）と判定
        var slots: [[String]] = []

        for (name, range) in sorted {
            var assigned = false
            for i in slots.indices {
                guard let lastInSlot = slots[i].last else { continue }
                if let lastRange = timeRanges[lastInSlot],
                   range.first >= lastRange.last {
                    slots[i].append(name)
                    assigned = true
                    break
                }
            }
            if !assigned {
                slots.append([name])
            }
        }

        // 2スロットに収まり、かつ統合が必要な場合のみマージ
        guard slots.count == 2, slots.contains(where: { $0.count > 1 }) else {
            return (messages, participantCounts)
        }

        // マージマップ構築: 旧名 → 最新名
        var mergeMap: [String: String] = [:]
        for slot in slots {
            guard let canonicalName = slot.last else { continue }
            for name in slot where name != canonicalName {
                mergeMap[name] = canonicalName
            }
        }

        // メッセージの送信者名を統合
        let mergedMessages = messages.map { msg -> ChatMessage in
            if let newName = mergeMap[msg.senderName] {
                return ChatMessage(
                    id: msg.id,
                    timestamp: msg.timestamp,
                    senderName: newName,
                    content: msg.content,
                    eventType: msg.eventType,
                    rawLine: msg.rawLine,
                    callDurationSeconds: msg.callDurationSeconds
                )
            }
            return msg
        }

        // 参加者カウントを再構築
        var newCounts: [String: ParticipantCounter] = [:]
        for msg in mergedMessages {
            var counter = newCounts[msg.senderName] ?? ParticipantCounter()
            counter.update(with: msg.eventType)
            newCounts[msg.senderName] = counter
        }

        return (mergedMessages, newCounts)
    }
}

// MARK: - Participant Counter
private struct ParticipantCounter {
    var total = 0
    var text = 0
    var sticker = 0
    var photo = 0
    var video = 0
    var call = 0

    mutating func update(with eventType: EventType) {
        total += 1
        switch eventType {
        case .text:
            text += 1
        case .sticker:
            sticker += 1
        case .photo:
            photo += 1
        case .video:
            video += 1
        case .call, .missedCall:
            call += 1
        case .system:
            break
        }
    }
}

// MARK: - Parser Result
struct ParserResult {
    let session: ChatSession
    let warnings: [ParserWarning]
}

struct ParserWarning {
    let lineNumber: Int
    let message: String
}
