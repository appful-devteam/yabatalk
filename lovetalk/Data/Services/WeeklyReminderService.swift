import Foundation
import UserNotifications

/// 週1回のリマインド通知を管理するサービス
/// アプリ起動時に次の4週分をスケジュールし、毎回異なるランダムメッセージを表示する
final class WeeklyReminderService {
    static let shared = WeeklyReminderService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let identifierPrefix = "weekly_reminder_"

    /// 通知を送る曜日（1=日曜, 2=月曜, ... 7=土曜）
    private let weekday = 1  // 日曜日
    /// 通知を送る時刻
    private let hour = 20
    private let minute = 0

    /// 先にスケジュールする週数
    private let weeksAhead = 4

    private init() {}

    // MARK: - 30 Notification Messages

    private let messages: [String] = [
        // 気づき・好奇心系
        "最近のトーク、雰囲気変わってない？💬",
        "返信パターンに気持ちが隠れてるかも…",
        "既読スルー？それとも駆け引き？🤔",
        "前回から関係性、変わったかも🔍",
        "トーク見返すと新しい発見があるかも",
        // 応援・共感系
        "恋してる自分、大事にしてね☺️",
        "考えすぎた日も、そばにいるよ",
        "今の気持ち、一人で抱えなくていいよ",
        "不安になるのは本気の証拠だよ",
        "あなたの恋、応援してるよ🌸",
        // ペルソナチャット系
        "\"あの人\"が話しかけたそうにしてるよ💭",
        "本人に聞けないこと、AIに相談してみる？",
        "次のメッセージ、AIで練習してみない？",
        "あの人ならなんて返すかな…？",
        "返信に迷ったらシミュレーションしてみて✨",
        // 掲示板系
        "同じ悩みの人の投稿、見てみない？",
        "みんなの恋バナ盛り上がってるよ👀",
        "あなたの経験が誰かの助けになるかも",
        "今週の人気投稿、共感できるかも…！",
        "一人で悩むよりみんなの声を聞こう💬",
        // 雑学・コラム風
        "返信が早い人ほど意識してるらしいよ",
        "\"笑\"と\"😂\"で印象が全然違うんだって",
        "質問が多いトークは脈ありのサインかも",
        "夜のLINEが長い相手、気になってるかも🌙",
        "通話の頻度で関係の深さがわかるかも",
        // 行動促進系
        "久しぶりにトーク分析してみない？",
        "新しいトーク履歴、分析してみよ📊",
        "週1の診断、今週もやってみない？",
        "恋の温度、今週はどうかな？🌡️",
        "今の恋愛スコア、気にならない…？",
    ]

    // MARK: - Public API

    /// アプリ起動時に呼ぶ。既存の週次通知をキャンセルし、次の4週分を再スケジュールする。
    func rescheduleIfAuthorized() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else {
                return
            }
            await cancelAll()
            scheduleNextWeeks()
        }
    }

    // MARK: - Private

    private func scheduleNextWeeks() {
        // 重複しないようランダムにメッセージを選択
        var indices = Array(messages.indices)
        indices.shuffle()

        for week in 0..<weeksAhead {
            let messageIndex = indices[week % indices.count]
            let content = UNMutableNotificationContent()
            content.title = "めろとーく"
            content.body = messages[messageIndex]
            content.sound = .default

            // 今週の通知日を計算し、weekオフセットを加算
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger: UNNotificationTrigger
            if week == 0 {
                // 今週分: カレンダートリガー（次の該当曜日・時刻）
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            } else {
                // 来週以降: 具体的な日付を計算
                if let nextDate = calcNextDate(weeksFromNow: week) {
                    let cal = Calendar.current
                    var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
                    comps.hour = hour
                    comps.minute = minute
                    trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                } else {
                    continue
                }
            }

            let identifier = "\(identifierPrefix)\(week)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notificationCenter.add(request) { error in
                if let error = error {
                    print("[WeeklyReminder] Failed to schedule week \(week): \(error.localizedDescription)")
                }
            }
        }
    }

    /// 指定週数後の通知曜日の日付を返す
    private func calcNextDate(weeksFromNow: Int) -> Date? {
        let calendar = Calendar.current
        // まず次の該当曜日を求める
        guard let nextWeekday = calendar.nextDate(
            after: Date(),
            matching: DateComponents(weekday: weekday),
            matchingPolicy: .nextTime
        ) else { return nil }

        // weeksFromNow 週分加算
        return calendar.date(byAdding: .weekOfYear, value: weeksFromNow - 1, to: nextWeekday)
    }

    private func cancelAll() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        if !ids.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
