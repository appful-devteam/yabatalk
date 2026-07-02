import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Board Block Service
/// ユーザーブロック管理。
///
/// **Firestore + ローカルキャッシュの二層構造**で、端末を変えても / 別アプリ
/// (LINE版 ↔ IG版) でも同じ Apple アカウントならブロックが引き継がれる。
/// - Firestore: `users/{uid}/blockedUsers/{targetUid}` が同期信号源
/// - UserDefaults: オフライン時の即応用キャッシュ
///
/// `isBlocked(_:)` / `block(_:)` / `unblock(_:)` は **同期 API のまま** で、
/// メモリ内 Set を即時更新（楽観的）し、Firestore 書き込みは fire-and-forget。
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
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[BoardBlock] block local-only (not signed in) target=\(userId)")
            return
        }
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users").document(uid)
                    .collection("blockedUsers").document(userId)
                    .setData(["createdAt": FieldValue.serverTimestamp()])
                print("[BoardBlock] block synced uid=\(uid) target=\(userId)")
            } catch {
                print("[BoardBlock] block sync failed: \(error.localizedDescription)")
            }
        }
    }

    func unblock(_ userId: String) {
        blockedUserIds.remove(userId)
        save()
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[BoardBlock] unblock local-only (not signed in) target=\(userId)")
            return
        }
        Task {
            do {
                try await Firestore.firestore()
                    .collection("users").document(uid)
                    .collection("blockedUsers").document(userId)
                    .delete()
                print("[BoardBlock] unblock synced uid=\(uid) target=\(userId)")
            } catch {
                print("[BoardBlock] unblock sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Firestore から最新のブロック一覧を取得し、ローカルとマージ（和集合）する。
    /// - サインイン直後 / 端末変更 / 別アプリで追加されたブロックを反映するため
    /// - ローカルにしか無い古いブロックは消さない（オフライン時に消えないよう union）
    func syncFromFirestore() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("blockedUsers").getDocuments()
            let remote = Set(snapshot.documents.map { $0.documentID })
            let merged = blockedUserIds.union(remote)
            if merged != blockedUserIds {
                blockedUserIds = merged
                save()
            }
            print("[BoardBlock] syncFromFirestore uid=\(uid) remote=\(remote.count) merged=\(blockedUserIds.count)")
        } catch {
            print("[BoardBlock] syncFromFirestore failed: \(error.localizedDescription)")
        }
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
