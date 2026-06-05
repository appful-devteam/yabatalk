import Foundation

// MARK: - Board Block Service
/// ユーザーブロック管理（ローカル保存）
@MainActor
final class BoardBlockService: ObservableObject {
    static let shared = BoardBlockService()

    @Published private(set) var blockedUserIds: Set<String> = []

    private let storageKey = "board_blocked_user_ids"

    private init() {
        load()
    }

    // MARK: - Public

    func isBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }

    func block(_ userId: String) {
        blockedUserIds.insert(userId)
        save()
    }

    func unblock(_ userId: String) {
        blockedUserIds.remove(userId)
        save()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedUserIds = ids
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(blockedUserIds) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
