import Foundation

extension String {
    // MARK: - Emotional Analysis

    /// 感情記号を含むか（!?絵文字）
    var hasEmotionalSymbols: Bool {
        contains("!") || contains("！") ||
        contains("?") || contains("？") ||
        containsEmoji
    }

    /// 絵文字を含むか
    var containsEmoji: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            // Emoticons
            case 0x1F600...0x1F64F,
                // Misc Symbols and Pictographs
                0x1F300...0x1F5FF,
                // Transport and Map
                0x1F680...0x1F6FF,
                // Misc symbols
                0x2600...0x26FF,
                // Dingbats
                0x2700...0x27BF,
                // Flags
                0x1F1E0...0x1F1FF,
                // Supplemental Symbols and Pictographs
                0x1F900...0x1F9FF,
                // Symbols and Pictographs Extended-A
                0x1FA00...0x1FA6F,
                // Symbols and Pictographs Extended-B
                0x1FA70...0x1FAFF:
                return true
            default:
                return false
            }
        }
    }

    /// 感情記号の数
    var emotionalSymbolCount: Int {
        var count = 0
        count += filter { $0 == "!" || $0 == "！" }.count
        count += filter { $0 == "?" || $0 == "？" }.count
        count += unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x1F600...0x1F64F, 0x1F300...0x1F5FF,
                0x1F680...0x1F6FF, 0x2600...0x26FF,
                0x2700...0x27BF, 0x1F1E0...0x1F1FF,
                0x1F900...0x1F9FF, 0x1FA00...0x1FA6F,
                0x1FA70...0x1FAFF:
                return true
            default:
                return false
            }
        }.count
        return count
    }

    // MARK: - Question/Proposal Detection

    /// 質問かどうか（?で終わる）
    var isQuestion: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("?") || trimmed.hasSuffix("？")
    }

    /// 提案パターンを含むか（多言語対応）
    var containsProposal: Bool {
        let patterns = [
            // Japanese
            "しよう", "しない？", "しない?",
            "行こう", "行かない？", "行かない?",
            "食べよう", "食べない？", "食べない?",
            "見よう", "見ない？", "見ない?",
            "どう？", "どう?", "いかが",
            "〜ない？", "〜ない?",
            // English
            "let's ", "shall we", "wanna ", "want to ",
            "how about", "what about", "why don't we",
            "should we", "we could",
            // Spanish
            "vamos a", "quieres ", "te gustaría",
            "qué tal si", "por qué no",
            // Korean
            "할래?", "할래？", "할까?", "할까？",
            "갈래?", "갈래？", "같이",
            "하자", "가자", "볼래",
            // Chinese (Simplified + Traditional)
            "我们去", "我們去", "一起去", "要不要",
            "去不去", "好不好", "怎么样", "怎麼樣",
            "吃不吃", "看不看"
        ]
        let lower = lowercased()
        return patterns.contains { lower.contains($0.lowercased()) }
    }

    // MARK: - LINE Event Type Detection

    /// スタンプメッセージか
    var isSticker: Bool {
        ["[スタンプ]", "Stickers", "[스티커]", "[贴图]", "[貼圖]", "[Sticker]"].contains(self)
    }

    /// 写真メッセージか
    var isPhoto: Bool {
        ["[写真]", "Photos", "[사진]", "[照片]", "[Photo]"].contains(self)
    }

    /// 動画メッセージか
    var isVideo: Bool {
        ["[動画]", "Videos", "[동영상]", "[视频]", "[視頻]", "[影片]", "[Video]"].contains(self)
    }

    /// 通話メッセージか
    var isCall: Bool {
        hasPrefix("☎") && (contains("通話時間") || contains("Call time") || contains("통화시간") || contains("通话时间") || contains("通話時間"))
    }

    /// 不在着信か
    var isMissedCall: Bool {
        ["☎ 不在着信", "☎不在着信", "Missed call", "☎ 부재중 전화", "☎ 未接来电", "☎ 未接來電"].contains(self)
    }

    /// 通話時間を抽出（秒単位）
    var callDurationSeconds: Int? {
        guard isCall else { return nil }

        // "☎ 通話時間 1:23:45" / "☎ Call time 1:23:45" etc.
        let pattern = #"☎\s*(?:通話時間|Call time|통화시간|通话时间|通話時間)\s*(\d+:)?(\d+):(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else {
            return nil
        }

        var hours = 0
        var minutes = 0
        var seconds = 0

        // 時間がある場合
        if let hourRange = Range(match.range(at: 1), in: self) {
            let hourString = String(self[hourRange]).replacingOccurrences(of: ":", with: "")
            hours = Int(hourString) ?? 0
        }

        if let minuteRange = Range(match.range(at: 2), in: self) {
            minutes = Int(self[minuteRange]) ?? 0
        }

        if let secondRange = Range(match.range(at: 3), in: self) {
            seconds = Int(self[secondRange]) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    /// システムメッセージか
    var isSystemMessage: Bool {
        let systemPatterns = [
            // Japanese
            "が参加しました", "が退出しました", "グループ名を変更しました",
            "がグループに招待されました", "を削除しました",
            "アルバムを作成しました", "ノートを作成しました",
            // English
            "joined the chat", "left the chat", "changed the group name",
            "was invited to the group", "unsent a message",
            "created an album", "created a note",
            // Korean
            "님이 들어왔습니다", "님이 나갔습니다", "그룹명을 변경했습니다",
            // Chinese (Simplified + Traditional)
            "加入了聊天", "离开了聊天", "更改了群组名称",
            "離開了聊天", "更改了群組名稱", "邀請了", "收回了訊息"
        ]
        return systemPatterns.contains { contains($0) }
    }

    // MARK: - Utilities

    /// 空白をトリム
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 空でないか
    var isNotEmpty: Bool {
        !isEmpty
    }

    /// テキストの長さ（絵文字も1文字としてカウント）
    var textLength: Int {
        count
    }
}
