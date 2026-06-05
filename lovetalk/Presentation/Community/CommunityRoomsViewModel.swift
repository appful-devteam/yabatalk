import Foundation
import SwiftUI
import Combine

@MainActor
final class CommunityRoomsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var rooms: [CommunityRoom] = []
    @Published var joinedRoomIds: Set<String> = []
    @Published var selectedTab: CommunityRoomTab = .search
    @Published var searchQuery: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? = nil

    /// 端末ローカルで参加日時を保持。「参加中」タブの新規参加順ソート用。
    /// 永続化キー: "community_room_joined_at_v1" (UserDefaults)
    @Published private var joinedAtMap: [String: Date] = [:]

    private static let joinedAtStorageKey = "community_room_joined_at_v1"

    // MARK: - Dependencies

    private let repository: CommunityRoomRepository
    /// 直近に観測した uid。auth state listener で uid が変わったら再ロードする。
    private var lastObservedUid: String?
    private var authCancellable: AnyCancellable?

    nonisolated init(repository: CommunityRoomRepository = InMemoryCommunityRoomRepository()) {
        self.repository = repository
        Task { @MainActor in
            self.loadJoinedAtMap()
            self.observeAuthState()
        }
    }

    /// サインイン状態が変わった時 (匿名→Apple、ログイン復元など) に自動で
    /// 再ロードして isJoined を再評価する。これがないと、init 時に currentUser が
    /// 未確定だった場合 / 後から uid が変わった場合に「参加中」タブが空のままになる。
    private func observeAuthState() {
        authCancellable = BoardAuthService.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .sink { [weak self] newUid in
                guard let self else { return }
                if self.lastObservedUid != newUid {
                    self.lastObservedUid = newUid
                    if !self.rooms.isEmpty {
                        self.forceReload()
                    }
                }
            }
    }

    private func forceReload() {
        isLoading = false
        joinedRoomIds.removeAll()
        load()
    }

    private func loadJoinedAtMap() {
        guard let data = UserDefaults.standard.data(forKey: Self.joinedAtStorageKey),
              let dict = try? JSONDecoder().decode([String: Date].self, from: data) else { return }
        self.joinedAtMap = dict
    }

    private func saveJoinedAtMap() {
        if let data = try? JSONEncoder().encode(joinedAtMap) {
            UserDefaults.standard.set(data, forKey: Self.joinedAtStorageKey)
        }
    }

    // MARK: - Derived

    /// 選択タブと検索キーワードに応じた表示対象。
    var displayedRooms: [CommunityRoom] {
        let resolved = rooms.map { room -> CommunityRoom in
            var updated = room
            updated.isJoined = joinedRoomIds.contains(room.id) || room.isJoined
            return updated
        }

        let byTab: [CommunityRoom]
        switch selectedTab {
        case .search:
            // 既に参加済みの部屋は「参加中」タブで見れるので、探すタブからは除外。
            // テーマ部屋は「参加中」タブで常時見れるので、探すタブには出さない。
            let candidates = resolved.filter {
                !$0.isJoined && !CommunityThemeRoom.isThemeRoomId($0.id)
            }
            // おすすめ順: 投稿数 × 2 + 参加人数 のスコア降順 (人気部屋を上に)
            // 同点時は participantCount → title でタイブレーク
            byTab = candidates.sorted { lhs, rhs in
                let l = popularityScore(lhs)
                let r = popularityScore(rhs)
                if l != r { return l > r }
                if lhs.participantCount != rhs.participantCount {
                    return lhs.participantCount > rhs.participantCount
                }
                return lhs.title < rhs.title
            }
        case .joined:
            // テーマ部屋は参加状態を持たず誰でもアクセス可能なので、
            // 「参加中」タブにもデフォルトで表示する。
            // 並び順: 自分が参加した部屋(新規参加順 = joinedAt 降順) → テーマ部屋(末尾)。
            // joinedAt 未記録の部屋は .distantPast にフォールバック (リスト末尾)。
            let themeRooms = resolved.filter { CommunityThemeRoom.isThemeRoomId($0.id) }
            let joinedUserRooms = resolved
                .filter { (room: CommunityRoom) -> Bool in
                    room.isJoined && !CommunityThemeRoom.isThemeRoomId(room.id)
                }
                .sorted { (lhs: CommunityRoom, rhs: CommunityRoom) -> Bool in
                    let lhsKey = joinedAtMap[lhs.id] ?? .distantPast
                    let rhsKey = joinedAtMap[rhs.id] ?? .distantPast
                    return lhsKey > rhsKey
                }
            byTab = joinedUserRooms + themeRooms
        case .created:
            let myId = BoardAuthService.shared.currentUser?.id
            byTab = resolved.filter { room in
                guard let myId, let owner = room.ownerId else { return false }
                return owner == myId
            }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return byTab }
        return byTab.filter { room in
            room.title.localizedStandardContains(query)
                || room.subtitle.localizedStandardContains(query)
        }
    }

    /// おすすめスコア。投稿数を参加人数より重く扱う(投稿が活発な部屋ほど "活気がある"指標)。
    private func popularityScore(_ room: CommunityRoom) -> Int {
        room.postCount * 2 + room.participantCount
    }

    // MARK: - Search

    func clearSearch() {
        searchQuery = ""
    }

    // MARK: - Actions

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetched = try await repository.fetchRooms()
                // 既存投稿テーマ (PostTheme) を仮想的な相談部屋として一覧の先頭に並べる。
                // 重複は ID で除外 (テーマ部屋 id は theme: prefix なので通常衝突しない)。
                let themeRooms = CommunityThemeRoom.all
                let existingIds = Set(fetched.map(\.id))
                let prepended = themeRooms.filter { !existingIds.contains($0.id) }
                self.rooms = prepended + fetched
                // 初期ロード時に Repository 側で保持されている参加状態を同期
                let serverJoinedIds = fetched.filter { $0.isJoined }.map { $0.id }
                self.joinedRoomIds.formUnion(serverJoinedIds)
                // joinedAt 未記録の参加部屋には fallback で現時点を入れて以後の並びを安定化。
                let now = Date()
                for id in serverJoinedIds where joinedAtMap[id] == nil {
                    joinedAtMap[id] = now
                }
                saveJoinedAtMap()
                self.isLoading = false

                // おすすめ並びに必要な投稿数を非同期で並列取得 → rooms に反映
                await refreshPostCounts()
                // テーマ部屋の参加状態を Firestore から同期 (LINE↔IG クロスアプリ共有用)。
                await syncJoinedThemeRoomsFromFirestore()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// 各部屋の投稿数を並列取得して `rooms[].postCount` に反映する。
    /// ロード完了後の追加情報なので失敗しても画面表示自体には影響しない。
    func refreshPostCounts() async {
        let snapshot = rooms
        // [roomId: 集計値] を並列で生成
        let counts: [String: Int] = await withTaskGroup(of: (String, Int).self) { group in
            for room in snapshot {
                group.addTask {
                    let count: Int
                    if let label = CommunityThemeRoom.themeLabel(forRoomId: room.id) {
                        count = (try? await BoardFirestoreService.shared.countPosts(forThemeLabel: label)) ?? 0
                    } else {
                        count = (try? await BoardFirestoreService.shared.countPosts(forCommunityRoomId: room.id)) ?? 0
                    }
                    return (room.id, count)
                }
            }
            var dict: [String: Int] = [:]
            for await (id, count) in group {
                dict[id] = count
            }
            return dict
        }

        // 反映 (id 一致するものだけ更新、配列順序は維持)
        rooms = rooms.map { room in
            var updated = room
            if let c = counts[room.id] { updated.postCount = c }
            return updated
        }
    }

    func toggleJoin(_ room: CommunityRoom) {
        // テーマ部屋 (id="theme:...") は Firestore の community_rooms には書けない (permission denied)。
        // 代わりに users/{uid}.joinedThemeRoomIds に保存することで LINE↔IG クロスアプリ共有を実現。
        if CommunityThemeRoom.isThemeRoomId(room.id) {
            let willJoin = !joinedRoomIds.contains(room.id)
            if willJoin {
                joinedRoomIds.insert(room.id)
                joinedAtMap[room.id] = Date()
            } else {
                joinedRoomIds.remove(room.id)
                joinedAtMap.removeValue(forKey: room.id)
            }
            saveJoinedAtMap()
            Task {
                if let userId = BoardAuthService.shared.currentUser?.id {
                    if willJoin {
                        await BoardFirestoreService.shared.joinThemeRoom(userId: userId, themeRoomId: room.id)
                    } else {
                        await BoardFirestoreService.shared.leaveThemeRoom(userId: userId, themeRoomId: room.id)
                    }
                }
            }
            return
        }

        let willJoin = !joinedRoomIds.contains(room.id)
        // 楽観的更新
        if willJoin {
            joinedRoomIds.insert(room.id)
            joinedAtMap[room.id] = Date()
        } else {
            joinedRoomIds.remove(room.id)
            joinedAtMap.removeValue(forKey: room.id)
        }
        saveJoinedAtMap()
        Task {
            do {
                if willJoin {
                    try await repository.joinRoom(id: room.id)
                } else {
                    try await repository.leaveRoom(id: room.id)
                }
            } catch {
                // 失敗したらロールバック
                if willJoin {
                    self.joinedRoomIds.remove(room.id)
                    self.joinedAtMap.removeValue(forKey: room.id)
                } else {
                    self.joinedRoomIds.insert(room.id)
                    self.joinedAtMap[room.id] = Date()
                }
                self.saveJoinedAtMap()
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Firestore に保存されたテーマ部屋の参加状態を読み込んでマージする。
    /// 同じ Apple ID で LINE版/IG版にログインした際、片方で参加したテーマ部屋が
    /// もう片方でも参加中扱いになる。
    func syncJoinedThemeRoomsFromFirestore() async {
        guard let userId = BoardAuthService.shared.currentUser?.id else { return }
        let remoteIds = await BoardFirestoreService.shared.fetchJoinedThemeRoomIds(userId: userId)

        var didChange = false
        for id in remoteIds where CommunityThemeRoom.isThemeRoomId(id) {
            if !joinedRoomIds.contains(id) {
                joinedRoomIds.insert(id)
                didChange = true
            }
            if joinedAtMap[id] == nil {
                joinedAtMap[id] = Date()
                didChange = true
            }
        }
        if didChange {
            saveJoinedAtMap()
        }

        // local にあって remote に無い → remote にも push
        let localThemeIds = joinedRoomIds.filter { CommunityThemeRoom.isThemeRoomId($0) }
        let remoteSet = Set(remoteIds)
        let toPush = localThemeIds.subtracting(remoteSet)
        for id in toPush {
            await BoardFirestoreService.shared.joinThemeRoom(userId: userId, themeRoomId: id)
        }
    }

    func selectTab(_ tab: CommunityRoomTab) {
        selectedTab = tab
    }

    // MARK: - Create

    /// 新しい相談部屋を作成し、一覧に追加する。作成者は自動的に参加状態になる。
    /// - Returns: 作成に成功した場合は新しい部屋、失敗時は nil。
    func createRoom(
        title: String,
        subtitle: String,
        iconImageData: Data?,
        headerImageData: Data?
    ) async -> CommunityRoom? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください"
            return nil
        }
        let ownerId = BoardAuthService.shared.currentUser?.id
        do {
            let newRoom = try await repository.createRoom(
                title: trimmedTitle,
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                iconImageData: iconImageData,
                headerImageData: headerImageData,
                ownerId: ownerId
            )
            rooms.insert(newRoom, at: 0)
            joinedRoomIds.insert(newRoom.id)
            joinedAtMap[newRoom.id] = Date()
            saveJoinedAtMap()
            return newRoom
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Owner-only Room Management

    /// 部屋を削除。オーナーのみ呼び出し可能。権限チェックは呼び出し側でも行うこと。
    /// - Returns: 削除に成功した場合 true。
    @discardableResult
    func deleteRoom(_ room: CommunityRoom) async -> Bool {
        guard room.isOwnedBy(userId: BoardAuthService.shared.currentUser?.id) else {
            errorMessage = "削除権限がありません"
            return false
        }
        do {
            try await repository.deleteRoom(id: room.id)
            rooms.removeAll { $0.id == room.id }
            joinedRoomIds.remove(room.id)
            joinedAtMap.removeValue(forKey: room.id)
            saveJoinedAtMap()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 部屋情報（タイトル / 説明文）の更新。オーナーのみ。
    @discardableResult
    func updateRoomInfo(roomId: String, title: String, subtitle: String) async -> CommunityRoom? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "タイトルを入力してください"
            return nil
        }
        guard let room = rooms.first(where: { $0.id == roomId }),
              room.isOwnedBy(userId: BoardAuthService.shared.currentUser?.id) else {
            errorMessage = "編集権限がありません"
            return nil
        }
        do {
            let updated = try await repository.updateRoomInfo(
                id: roomId,
                title: trimmedTitle,
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if let idx = rooms.firstIndex(where: { $0.id == roomId }) {
                rooms[idx] = updated
            }
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// 指定ユーザーのブロック状態をトグル。オーナーのみ。
    @discardableResult
    func toggleBlock(roomId: String, userId: String) async -> CommunityRoom? {
        guard let room = rooms.first(where: { $0.id == roomId }),
              room.isOwnedBy(userId: BoardAuthService.shared.currentUser?.id) else {
            errorMessage = "ブロック権限がありません"
            return nil
        }
        var newList = room.blockedUserIds
        if newList.contains(userId) {
            newList.removeAll { $0 == userId }
        } else {
            newList.append(userId)
        }
        do {
            let updated = try await repository.updateBlockList(id: roomId, blockedUserIds: newList)
            if let idx = rooms.firstIndex(where: { $0.id == roomId }) {
                rooms[idx] = updated
            }
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// 直近の状態で対応する Room を返す（詳細ビューからのシート更新反映用）。
    func latestRoom(id: String) -> CommunityRoom? {
        rooms.first(where: { $0.id == id })
    }
}
