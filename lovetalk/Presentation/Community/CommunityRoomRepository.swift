import Foundation
import SwiftUI

// MARK: - Repository Protocol
//
// 抽象化により、テスト時はインメモリ実装、本番では Firestore 実装に差し替える。
// ViewModel はこのプロトコルにのみ依存する。
protocol CommunityRoomRepository {
    func fetchRooms() async throws -> [CommunityRoom]
    func joinRoom(id: String) async throws
    func leaveRoom(id: String) async throws
    func createRoom(
        title: String,
        subtitle: String,
        iconImageData: Data?,
        headerImageData: Data?,
        ownerId: String?
    ) async throws -> CommunityRoom

    /// 部屋を削除（オーナーのみ呼び出す前提。権限チェックは呼び出し元で行う）。
    func deleteRoom(id: String) async throws

    /// 部屋の基本情報（タイトル / 説明文）を更新。
    func updateRoomInfo(id: String, title: String, subtitle: String) async throws -> CommunityRoom

    /// 部屋のブロックリストを更新（追加・削除を含む置き換え）。
    func updateBlockList(id: String, blockedUserIds: [String]) async throws -> CommunityRoom
}

// MARK: - Firestore-Backed Implementation
//
// 既存の名前 `InMemoryCommunityRoomRepository` を維持しつつ、内部実装は
// Firestore (CommunityRoomFirestoreService) に差し替えた。理由は ViewModel の
// デフォルト引数や利用箇所を変更せずに済ませるため。
//
// 動作:
// - 起動時 / `fetchRooms()` 時: Firestore から取得 → 失敗 / 空ならシード部屋を表示。
//   シード部屋は **書き込まない** (UI 用の静的データ)。
// - 作成・参加・離脱・編集はすべて Firestore に直接書き込み、即時に取得し直して反映。
// - `joinRoom` / `leaveRoom` は サインイン済み (BoardAuthService の uid) の場合のみ
//   Firestore に書き込む。未サインインだと UI 上のローカル状態のみ更新される。
final class InMemoryCommunityRoomRepository: CommunityRoomRepository {
    init() {}

    /// シード部屋の id 集合 (サーバには存在しないため、参加/編集等は無効化)。
    private static let seedRoomIds: Set<String> = Set(defaultRooms.map(\.id))

    private static func isSeedRoom(_ id: String) -> Bool {
        seedRoomIds.contains(id)
    }

    // MARK: - Local Cache (Firestore 失敗時の保険)
    //
    // Firestore 書き込みが Security Rules や接続失敗で落ちても、
    // 少なくとも作成者本人の端末では作成済みルームが消えないように
    // Documents/community_user_rooms.json にローカルキャッシュする。
    // fetchRooms 時は Firestore 結果と union (重複は Firestore 優先)。

    private struct PersistedRoomDTO: Codable {
        let id: String
        var title: String
        var subtitle: String
        let participantCount: Int
        let iconImageData: Data?
        let headerImageData: Data?
        var isJoined: Bool
        var ownerId: String?
        var blockedUserIds: [String]
    }

    private static var cacheFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("community_user_rooms.json")
    }

    private static func loadLocalCache() -> [CommunityRoom] {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let dtos = try? JSONDecoder().decode([PersistedRoomDTO].self, from: data) else {
            return []
        }
        return dtos.map { dto in
            CommunityRoom(
                id: dto.id,
                title: dto.title,
                subtitle: dto.subtitle,
                participantCount: dto.participantCount,
                imageURL: nil,
                iconImageData: dto.iconImageData,
                headerImageData: dto.headerImageData,
                isJoined: dto.isJoined,
                iconColor: MeloColors.Brand.pink,
                ownerId: dto.ownerId,
                blockedUserIds: dto.blockedUserIds
            )
        }
    }

    private static func saveLocalCache(_ rooms: [CommunityRoom]) {
        let userRooms = rooms.filter { !isSeedRoom($0.id) }
        let dtos = userRooms.map { room in
            PersistedRoomDTO(
                id: room.id,
                title: room.title,
                subtitle: room.subtitle,
                participantCount: room.participantCount,
                iconImageData: room.iconImageData,
                headerImageData: room.headerImageData,
                isJoined: room.isJoined,
                ownerId: room.ownerId,
                blockedUserIds: room.blockedUserIds
            )
        }
        if let data = try? JSONEncoder().encode(dtos) {
            try? data.write(to: cacheFileURL, options: .atomic)
        }
    }

    private static func upsertCache(_ room: CommunityRoom) {
        var current = loadLocalCache()
        current.removeAll { $0.id == room.id }
        current.insert(room, at: 0)
        saveLocalCache(current)
    }

    private static func removeFromCache(id: String) {
        var current = loadLocalCache()
        current.removeAll { $0.id == id }
        saveLocalCache(current)
    }

    func fetchRooms() async throws -> [CommunityRoom] {
        let cached = Self.loadLocalCache()
        do {
            let remote = try await CommunityRoomFirestoreService.shared.fetchRooms()
            // Firestore + ローカルキャッシュを union (Firestore 側を優先 / 重複削除)。
            // ネットワーク or Security Rules で remote が空なら、キャッシュとシードを返す。
            var merged: [CommunityRoom] = []
            var seenIds = Set<String>()
            for r in remote {
                merged.append(r); seenIds.insert(r.id)
            }
            for r in cached where !seenIds.contains(r.id) {
                merged.append(r); seenIds.insert(r.id)
            }
            // remote+cache 共に空なら シード を表示。
            if merged.isEmpty { return Self.defaultRooms }
            // シードは常に末尾に並べる (User がまだ何も作っていない初回 UX 用)。
            for seed in Self.defaultRooms where !seenIds.contains(seed.id) {
                merged.append(seed)
            }
            return merged
        } catch {
            // ネットワーク・権限失敗時: ローカルキャッシュ + シードを返して
            // 作成者だけでも自分のルームを見られるようにする。
            let merged = cached + Self.defaultRooms.filter { d in !cached.contains { $0.id == d.id } }
            return merged.isEmpty ? Self.defaultRooms : merged
        }
    }

    func joinRoom(id: String) async throws {
        guard !Self.isSeedRoom(id),
              let uid = await BoardAuthService.shared.currentUser?.id else { return }
        try await CommunityRoomFirestoreService.shared.joinRoom(roomId: id, userId: uid)
    }

    func leaveRoom(id: String) async throws {
        guard !Self.isSeedRoom(id),
              let uid = await BoardAuthService.shared.currentUser?.id else { return }
        try await CommunityRoomFirestoreService.shared.leaveRoom(roomId: id, userId: uid)
    }

    func createRoom(
        title: String,
        subtitle: String,
        iconImageData: Data?,
        headerImageData: Data?,
        ownerId: String?
    ) async throws -> CommunityRoom {
        // Firestore 書き込みを試みる。失敗してもローカルにはキャッシュして
        // 作成者の端末ではルームが消えないようにする。
        do {
            let created = try await CommunityRoomFirestoreService.shared.createRoom(
                title: title,
                subtitle: subtitle,
                iconImageData: iconImageData,
                headerImageData: headerImageData,
                ownerId: ownerId
            )
            Self.upsertCache(created)
            return created
        } catch {
            // Firestore 失敗時: ローカルにのみ作成。
            let local = CommunityRoom(
                id: "local_" + UUID().uuidString.prefix(8).lowercased(),
                title: title,
                subtitle: subtitle,
                participantCount: 1,
                imageURL: nil,
                iconImageData: iconImageData,
                headerImageData: headerImageData,
                isJoined: true,
                iconColor: MeloColors.Brand.pink,
                ownerId: ownerId,
                blockedUserIds: []
            )
            Self.upsertCache(local)
            return local
        }
    }

    func deleteRoom(id: String) async throws {
        guard !Self.isSeedRoom(id) else {
            throw NSError(
                domain: "CommunityRoomRepository",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "シード部屋は削除できません"]
            )
        }
        // Firestore 削除を試行 (失敗しても継続して キャッシュからも削除)。
        do {
            try await CommunityRoomFirestoreService.shared.deleteRoom(id: id)
        } catch {
            // ネットワーク or 権限エラーは握りつぶし、ローカルからの削除は確実に行う。
        }
        Self.removeFromCache(id: id)
    }

    func updateRoomInfo(id: String, title: String, subtitle: String) async throws -> CommunityRoom {
        guard !Self.isSeedRoom(id) else {
            throw NSError(
                domain: "CommunityRoomRepository",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "シード部屋は編集できません"]
            )
        }
        let updated = try await CommunityRoomFirestoreService.shared.updateRoomInfo(
            id: id, title: title, subtitle: subtitle
        )
        Self.upsertCache(updated)
        return updated
    }

    func updateBlockList(id: String, blockedUserIds: [String]) async throws -> CommunityRoom {
        guard !Self.isSeedRoom(id) else {
            throw NSError(
                domain: "CommunityRoomRepository",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "シード部屋では設定できません"]
            )
        }
        let updated = try await CommunityRoomFirestoreService.shared.updateBlockList(
            id: id, blockedUserIds: blockedUserIds
        )
        Self.upsertCache(updated)
        return updated
    }

    // MARK: - Seed Data
    //
    // ハードコードのシード部屋は廃止 (ヤミトーク=darkmerotalk と同じく空)。
    // ユーザー作成の相談部屋は project `darkmerotalk` の `community_rooms`
    // コレクションを yabatalk / ヤミトークで共有しているため、Firestore から
    // 取得した実部屋のみを表示する。定型のテーマ別相談部屋 (CommunityThemeRoom)
    // は `PostTheme` 由来の仮想部屋として ViewModel 側で一覧に追加される。
    static let defaultRooms: [CommunityRoom] = []
}
