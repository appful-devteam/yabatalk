import Foundation

// MARK: - Message Type Detector
/// メッセージの種類を判定
struct MessageTypeDetector {

    /// メッセージ内容からイベントタイプを判定
    func detect(_ content: String) -> EventType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // スタンプ
        if isSticker(trimmed) {
            return .sticker
        }

        // 写真
        if isPhoto(trimmed) {
            return .photo
        }

        // 動画
        if isVideo(trimmed) {
            return .video
        }

        // 通話（1対1 + グループ通話終了）
        if isCall(trimmed) {
            return .call
        }

        // 不在着信
        if isMissedCall(trimmed) {
            return .missedCall
        }

        // グループ通話開始（通話としてカウントしない、終了で1回カウント）
        if isGroupCallStart(trimmed) {
            return .system
        }

        // システムメッセージ
        if isSystemMessage(trimmed) {
            return .system
        }

        // その他はテキスト
        return .text
    }

    /// 通話時間を抽出（秒）
    func extractCallDuration(_ content: String) -> Int? {
        guard isCall(content) else { return nil }

        // パターン: "☎ 通話時間 1:23:45" / "☎ 通話時間 23:45" / "1:23:45" / "23:45"
        // パターン1が先にマッチするため、パターン2でHH:MM:SSの部分マッチは起きない
        let patterns = [
            #"(\d+):(\d+):(\d+)"#,  // 時:分:秒
            #"(\d+):(\d+)"#         // 分:秒（プレフィックス付きでもマッチ）
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {

                if match.numberOfRanges == 4 {
                    if let hourRange = Range(match.range(at: 1), in: content),
                       let minuteRange = Range(match.range(at: 2), in: content),
                       let secondRange = Range(match.range(at: 3), in: content),
                       let hours = Int(content[hourRange]),
                       let minutes = Int(content[minuteRange]),
                       let seconds = Int(content[secondRange]) {
                        return hours * 3600 + minutes * 60 + seconds
                    }
                } else if match.numberOfRanges == 3 {
                    if let minuteRange = Range(match.range(at: 1), in: content),
                       let secondRange = Range(match.range(at: 2), in: content),
                       let minutes = Int(content[minuteRange]),
                       let seconds = Int(content[secondRange]) {
                        return minutes * 60 + seconds
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func isSticker(_ content: String) -> Bool {
        ["[スタンプ]", "Stickers", "[스티커]", "[贴图]", "[貼圖]", "[Sticker]"].contains(content)
    }

    private func isPhoto(_ content: String) -> Bool {
        ["[写真]", "Photos", "[사진]", "[照片]", "[Photo]"].contains(content)
    }

    private func isVideo(_ content: String) -> Bool {
        ["[動画]", "Videos", "[동영상]", "[视频]", "[視頻]", "[影片]", "[Video]"].contains(content)
    }

    private func isCall(_ content: String) -> Bool {
        // 1対1通話: "☎ 通話時間 HH:MM:SS" / "☎ Call time HH:MM:SS"
        if content.hasPrefix("☎") && (content.contains("通話時間") || content.contains("Call time") || content.contains("통화시간") || content.contains("通话时间") || content.contains("通話時間")) {
            return true
        }
        // 英語版: 通話時間のみ（例: "1:04:49", "23:45"）
        if let regex = try? NSRegularExpression(pattern: #"^\d{1,2}:\d{2}:\d{2}$"#),
           regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            return true
        }
        // グループ通話終了: "グループ通話が終了しました。" / "Group call ended" / "Group video chat ended"
        if isGroupCallEnd(content) {
            return true
        }
        return false
    }

    /// グループ通話開始の判定
    private func isGroupCallStart(_ content: String) -> Bool {
        let patterns = [
            "グループ通話が開始されました",
            "Group call started",
            "Group video chat started"
        ]
        return patterns.contains { content.contains($0) }
    }

    /// グループ通話終了の判定
    func isGroupCallEnd(_ content: String) -> Bool {
        let patterns = [
            "グループ通話が終了しました",
            "Group call ended",
            "Group video chat ended"
        ]
        return patterns.contains { content.contains($0) }
    }

    private func isMissedCall(_ content: String) -> Bool {
        ["☎ 不在着信", "☎不在着信", "Missed call", "☎ 부재중 전화", "☎ 未接来电", "☎ 未接來電"].contains(content)
    }

    private func isSystemMessage(_ content: String) -> Bool {
        let systemPatterns = [
            // 日本語
            "が参加しました",
            "が退出しました",
            "グループ名を変更しました",
            "がグループに招待されました",
            "を削除しました",
            "アルバムを作成しました",
            "ノートを作成しました",
            "アルバムに写真を追加しました",
            "投票を作成しました",
            "イベントを作成しました",
            "メッセージの送信を取り消しました",
            "通話をキャンセルしました",
            "トークBGMが変更されました",
            "がグループのプロフィール画像を変更しました",
            "ⓘ Decrypting...",
            // 英語
            "unsent a message",
            "deleted this message",
            "changed the group name",
            "was invited to the group",
            "joined the chat",
            "left the chat",
            "created an album",
            "created a note",
            "added photos to the album",
            "created a poll",
            "created an event",
            "canceled the call",
            // 韓国語
            "님이 들어왔습니다",
            "님이 나갔습니다",
            "그룹명을 변경했습니다",
            "님을 초대했습니다",
            "메시지를 취소했습니다",
            "앨범을 만들었습니다",
            "노트를 작성했습니다",
            "투표를 만들었습니다",
            "전화를 취소했습니다",
            // 中国語（簡体字）
            "加入了聊天",
            "离开了聊天",
            "更改了群组名称",
            "邀请了",
            "撤回了一条消息",
            "创建了相册",
            "创建了笔记",
            "取消了通话",
            // 中国語（繁体字）
            "加入了聊天室",
            "離開了聊天",
            "更改了群組名稱",
            "邀請了",
            "收回了訊息",
            "建立了相簿",
            "建立了記事本",
            "取消了通話",
            // タイ語
            "เข้าร่วมแชท",
            "ออกจากแชท",
            "ยกเลิกข้อความ",
            "เปลี่ยนชื่อกลุ่ม",
        ]
        return systemPatterns.contains { content.contains($0) }
    }
}
