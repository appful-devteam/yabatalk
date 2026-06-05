import Foundation
import SwiftUI

// MARK: - Data Models

struct InAppAnnouncement: Decodable, Identifiable {
    let id: String
    let trigger: String
    let title: String
    let message: String
    let isEnabled: Bool?
    let priority: Int?
    let imageName: String?
    let primaryButtonTitle: String?
    let primaryButtonUrl: String?
    let secondaryButtonTitle: String?
    let allowDontShowAgain: Bool?
    let maxDisplayCount: Int?
    let repeatIntervalHours: Double?
    let startAt: Date?
    let endAt: Date?
}

struct AnnouncementDisplayState: Codable {
    var displayCount: Int = 0
    var lastDisplayedAt: Date?
    var optedOut: Bool = false
}

struct AnnouncementConfig: Decodable {
    let maxDisplayPerTrigger: Int?
    let announcements: [InAppAnnouncement]
}

// MARK: - Notification Name
extension Notification.Name {
    static let triggerAnnouncement = Notification.Name("triggerAnnouncement")
}

// MARK: - AnnouncementManager

@MainActor
final class AnnouncementManager: ObservableObject {
    static let shared = AnnouncementManager()

    @Published var activeAnnouncement: InAppAnnouncement?

    private var config: AnnouncementConfig?
    private var configLastFetchedAt: Date?
    private var displayStates: [String: AnnouncementDisplayState] = [:]
    private var queue: [InAppAnnouncement] = []
    private var hasTriggeredOnLaunchThisSession = false
    private var maxDisplayPerTrigger: Int = 1

    private let configCacheDuration: TimeInterval = 5 * 60 // 5分キャッシュ

    private init() {
        loadDisplayStates()
    }

    // MARK: - Trigger

    func trigger(_ name: String, isFirstLaunch: Bool = false) {
        // 初回起動時はスキップ（オンボーディング優先）
        if isFirstLaunch { return }

        // on_launchは1セッション1回
        if name == "on_launch" {
            if hasTriggeredOnLaunchThisSession { return }
            hasTriggeredOnLaunchThisSession = true
        }

        Task {
            await loadConfigIfNeeded()

            guard let config = config else { return }

            let matching = config.announcements
                .filter { $0.trigger == name }
                .filter { isEligible($0) }
                .sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }

            // 条件を満たす全てのお知らせを順番に表示
            enqueue(matching)
        }
    }

    // MARK: - Eligibility

    private func isEligible(_ announcement: InAppAnnouncement) -> Bool {
        // enabled check
        if announcement.isEnabled == false {
            print("[AnnouncementManager] \(announcement.id): skipped (disabled)")
            return false
        }

        // date range check
        let now = Date()
        if let startAt = announcement.startAt, now < startAt {
            print("[AnnouncementManager] \(announcement.id): skipped (before start_at: \(startAt))")
            return false
        }
        if let endAt = announcement.endAt, now > endAt {
            print("[AnnouncementManager] \(announcement.id): skipped (after end_at: \(endAt))")
            return false
        }

        let state = displayStates[announcement.id] ?? AnnouncementDisplayState()

        // opt-out check
        if state.optedOut {
            print("[AnnouncementManager] \(announcement.id): skipped (opted out)")
            return false
        }

        // max display count check
        if let maxCount = announcement.maxDisplayCount, state.displayCount >= maxCount {
            print("[AnnouncementManager] \(announcement.id): skipped (displayed \(state.displayCount)/\(maxCount))")
            return false
        }

        // repeat interval check
        if let intervalHours = announcement.repeatIntervalHours,
           let lastDisplayed = state.lastDisplayedAt {
            let intervalSeconds = intervalHours * 3600
            if now.timeIntervalSince(lastDisplayed) < intervalSeconds {
                print("[AnnouncementManager] \(announcement.id): skipped (interval not elapsed)")
                return false
            }
        }

        print("[AnnouncementManager] \(announcement.id): eligible")
        return true
    }

    // MARK: - Queue Management

    private func enqueue(_ announcements: [InAppAnnouncement]) {
        queue.append(contentsOf: announcements)
        presentNextIfNeeded()
    }

    private func presentNextIfNeeded() {
        guard activeAnnouncement == nil, !queue.isEmpty else { return }

        let announcement = queue.removeFirst()
        activeAnnouncement = announcement

        // 表示状態を更新
        var state = displayStates[announcement.id] ?? AnnouncementDisplayState()
        state.displayCount += 1
        state.lastDisplayedAt = Date()
        displayStates[announcement.id] = state
        saveDisplayStates()
    }

    // MARK: - Actions

    func dismissCurrent(dontShowAgain: Bool = false) {
        guard let current = activeAnnouncement else { return }

        if dontShowAgain {
            var state = displayStates[current.id] ?? AnnouncementDisplayState()
            state.optedOut = true
            displayStates[current.id] = state
            saveDisplayStates()
        }

        activeAnnouncement = nil

        // 次のキューがあれば少し遅延して表示
        if !queue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.presentNextIfNeeded()
            }
        }
    }

    func handlePrimaryAction() -> URL? {
        guard let current = activeAnnouncement,
              let urlString = current.primaryButtonUrl,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    // MARK: - Push → Popup Linkage

    func handlePushAnnouncement(id announcementId: String) {
        Task {
            await loadConfigIfNeeded()

            guard let config = config else { return }

            if let announcement = config.announcements.first(where: { $0.id == announcementId }) {
                queue.insert(announcement, at: 0)
                if activeAnnouncement == nil {
                    presentNextIfNeeded()
                }
            }
        }
    }

    // MARK: - Config Loading

    private func loadConfigIfNeeded() async {
        if let lastFetched = configLastFetchedAt,
           Date().timeIntervalSince(lastFetched) < configCacheDuration,
           config != nil {
            return
        }

        guard let jsonString = await RemoteConfigService.shared.string(
            forKey: Constants.RemoteConfigKeys.inAppAnnouncements
        ) else { return }

        decodeConfig(jsonString)
    }

    private func decodeConfig(_ jsonString: String) {
        // 念のため、ダブルクォート囲み・エスケープされたJSON文字列に防御的対応
        var cleanedString = jsonString
        if cleanedString.hasPrefix("\"") && cleanedString.hasSuffix("\"") {
            cleanedString = String(cleanedString.dropFirst().dropLast())
            cleanedString = cleanedString.replacingOccurrences(of: "\\\"", with: "\"")
            cleanedString = cleanedString.replacingOccurrences(of: "\\\\", with: "\\")
        }

        // JSON文字列内のリテラル改行・余分な空白を除去
        cleanedString = sanitizeJsonString(cleanedString)

        guard let data = cleanedString.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // ISO8601日付デコード（タイムゾーン付き対応）
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let formatterNoFraction = ISO8601DateFormatter()
        formatterNoFraction.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = formatter.date(from: dateString) {
                return date
            }
            if let date = formatterNoFraction.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        do {
            let decoded = try decoder.decode(AnnouncementConfig.self, from: data)
            config = decoded
            configLastFetchedAt = Date()
            if let max = decoded.maxDisplayPerTrigger {
                maxDisplayPerTrigger = max
            }
            print("[AnnouncementManager] Loaded \(decoded.announcements.count) announcements")
        } catch {
            print("[AnnouncementManager] Failed to decode config: \(error)")
        }
    }

    // MARK: - Display State Persistence

    private func loadDisplayStates() {
        guard let data = UserDefaults.standard.data(
            forKey: Constants.StorageKeys.announcementDisplayStates
        ) else { return }

        do {
            displayStates = try JSONDecoder().decode(
                [String: AnnouncementDisplayState].self, from: data
            )
        } catch {
            print("[AnnouncementManager] Failed to load display states: \(error)")
        }
    }

    private func saveDisplayStates() {
        do {
            let data = try JSONEncoder().encode(displayStates)
            UserDefaults.standard.set(data, forKey: Constants.StorageKeys.announcementDisplayStates)
        } catch {
            print("[AnnouncementManager] Failed to save display states: \(error)")
        }
    }

    // MARK: - JSON Sanitization

    /// JSON文字列内のリテラル改行と余分な空白を除去
    private func sanitizeJsonString(_ input: String) -> String {
        var result = ""
        var inString = false
        var escaped = false
        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if escaped {
                result.append(c)
                escaped = false
                i += 1
                continue
            }

            if c == "\\" && inString {
                escaped = true
                result.append(c)
                i += 1
                continue
            }

            if c == "\"" {
                inString.toggle()
                result.append(c)
                i += 1
                continue
            }

            if inString {
                // 文字列内のリテラル改行を \n に置換し、続く空白を除去
                if c == "\n" || c == "\r" {
                    result.append("\\")
                    result.append("n")
                    i += 1
                    // 改行後の連続空白をスキップ
                    while i < chars.count && (chars[i] == " " || chars[i] == "\t") {
                        i += 1
                    }
                    continue
                }
                result.append(c)
            } else {
                result.append(c)
            }
            i += 1
        }

        return result
    }
}
