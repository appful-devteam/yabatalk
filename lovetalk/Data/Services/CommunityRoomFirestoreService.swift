import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI
import UIKit

// MARK: - Community Room Firestore Service
//
// 相談部屋 (Community Room) と部屋内投稿 (CommunityRoomPost) の Firestore 永続化レイヤ。
// パターンは BoardFirestoreService に倣う。
//
// スキーマ:
//   community_rooms/{roomId}
//     - title:            String
//     - subtitle:         String
//     - ownerId:          String?
//     - participantCount: Int
//     - blockedUserIds:   [String]
//     - joinedUserIds:    [String]
//     - iconImageBase64:  String?      (画像が < 512KB の場合のみ)
//     - iconImageURL:     String?      (Storage アップロード時)
//     - headerImageBase64:String?
//     - headerImageURL:   String?
//     - createdAt:        Timestamp
//     - updatedAt:        Timestamp
//
//   community_rooms/{roomId}/posts/{postId}
//     - roomId:           String
//     - authorId:         String?
//     - authorName:       String
//     - authorAvatarSymbol: String
//     - authorAvatarColor:  String   (hex)
//     - authorMbti:       String?
//     - relationshipTag:  String?
//     - body:             String
//     - imageURL:         String?
//     - reactionOptions:  [String]
//     - reactionCounts:   [String:Int]
//     - bookmarkCount:    Int
//     - commentCount:     Int
//     - likeCount:        Int
//     - viewCount:        Int
//     - postedAt:         Timestamp
//
//   community_rooms/{roomId}/posts/{postId}/likes/{userId}    -> presence == liked
//   community_rooms/{roomId}/posts/{postId}/bookmarks/{userId}-> presence == bookmarked
//   community_rooms/{roomId}/posts/{postId}/reactions/{userId}-> { option: String }
@MainActor
final class CommunityRoomFirestoreService {
    static let shared = CommunityRoomFirestoreService()

    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Collection References

    private var roomsCollection: CollectionReference { db.collection("community_rooms") }
    private func postsCollection(roomId: String) -> CollectionReference {
        roomsCollection.document(roomId).collection("posts")
    }
    private func likesCollection(roomId: String, postId: String) -> CollectionReference {
        postsCollection(roomId: roomId).document(postId).collection("likes")
    }
    private func bookmarksCollection(roomId: String, postId: String) -> CollectionReference {
        postsCollection(roomId: roomId).document(postId).collection("bookmarks")
    }
    private func repliesCollection(roomId: String, postId: String) -> CollectionReference {
        postsCollection(roomId: roomId).document(postId).collection("replies")
    }

    private func replyLikesCollection(roomId: String, postId: String, replyId: String) -> CollectionReference {
        repliesCollection(roomId: roomId, postId: postId).document(replyId).collection("likes")
    }

    private func reactionsCollection(roomId: String, postId: String) -> CollectionReference {
        postsCollection(roomId: roomId).document(postId).collection("reactions")
    }

    // MARK: - Image Encoding

    /// 画像 Data を可能なら Base64 文字列に。512KB を超える場合は JPEG 圧縮を試す。
    /// それでも 512KB を超える場合は Storage にアップロードして URL を返す (storageURL)。
    private struct EncodedImage {
        let base64: String?
        let storageURL: String?
    }

    private func encodeImage(
        _ data: Data,
        roomId: String,
        uploadType: R2StorageService.UploadType
    ) async throws -> EncodedImage {
        let cap = 512 * 1024
        // まず無圧縮で試す (Firestore に直接埋め込み = R2 を使わない経路)
        if data.count <= cap {
            return EncodedImage(base64: data.base64EncodedString(), storageURL: nil)
        }
        // JPEG 圧縮で再挑戦 (こちらも Firestore 直埋め)
        if let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.6),
           compressed.count <= cap {
            return EncodedImage(base64: compressed.base64EncodedString(), storageURL: nil)
        }
        // それでも大きい場合は R2 にアップロード
        let upload = (UIImage(data: data)?.jpegData(compressionQuality: 0.6)) ?? data
        let result = try await R2StorageService.shared.uploadImage(
            data: upload,
            type: uploadType,
            ownerId: roomId
        )
        // 同じ key で上書きされるため CDN のキャッシュ回避用にバージョン付き URL を返す
        let urlWithCacheBust = "\(result.url.absoluteString)?v=\(Int(Date().timeIntervalSince1970))"
        return EncodedImage(base64: nil, storageURL: urlWithCacheBust)
    }

    // MARK: - Decode Helpers

    /// Firestore ドキュメントから CommunityRoom を復元 (欠損フィールドに寛容)。
    private func decodeRoom(id: String, data: [String: Any]) -> CommunityRoom {
        let title = data["title"] as? String ?? ""
        let subtitle = data["subtitle"] as? String ?? ""
        let participantCount = data["participantCount"] as? Int ?? 1
        let ownerId = data["ownerId"] as? String
        let blocked = data["blockedUserIds"] as? [String] ?? []
        let joined = data["joinedUserIds"] as? [String] ?? []
        let iconBase64 = data["iconImageBase64"] as? String
        let iconURL = data["iconImageURL"] as? String
        let headerBase64 = data["headerImageBase64"] as? String
        let headerURL = data["headerImageURL"] as? String

        // Base64 を Data に復号 (URL 経由はクライアントで非同期取得が必要 -> 現行モデルは Data
        // を直接持つ前提なので URL 系は imageURL に格納する)。
        let iconData: Data? = iconBase64.flatMap { Data(base64Encoded: $0) }
        let headerData: Data? = headerBase64.flatMap { Data(base64Encoded: $0) }

        // Auth.auth().currentUser は keychain から同期復元されるので、
        // BoardAuthService.shared.currentUser (listener 経由で非同期設定) より
        // 確実に取得できる。fetchRooms の race condition を回避。
        let myId = Auth.auth().currentUser?.uid ?? BoardAuthService.shared.currentUser?.id
        let isJoined = myId.map { joined.contains($0) } ?? false

        return CommunityRoom(
            id: id,
            title: title,
            subtitle: subtitle,
            participantCount: participantCount,
            imageURL: iconURL ?? headerURL,
            iconImageData: iconData,
            headerImageData: headerData,
            isJoined: isJoined,
            iconColor: MeloColors.Brand.pink,
            ownerId: ownerId,
            blockedUserIds: blocked
        )
    }

    /// 投稿ドキュメントから CommunityRoomPost を復元。
    private func decodePost(id: String, roomId: String, data: [String: Any]) -> CommunityRoomPost? {
        let authorName = data["authorName"] as? String ?? ""
        let body = data["body"] as? String ?? ""
        let postedAt = (data["postedAt"] as? Timestamp)?.dateValue() ?? Date()
        var post = CommunityRoomPost(
            id: id,
            roomId: roomId,
            authorId: data["authorId"] as? String,
            authorName: authorName,
            authorAvatarSymbol: data["authorAvatarSymbol"] as? String ?? "person.fill",
            authorAvatarColor: data["authorAvatarColor"] as? String ?? "F19EC2",
            authorMbti: data["authorMbti"] as? String,
            relationshipTag: data["relationshipTag"] as? String,
            body: body,
            imageURL: data["imageURL"] as? String,
            reactionOptions: data["reactionOptions"] as? [String] ?? [],
            reactionCounts: data["reactionCounts"] as? [String: Int] ?? [:],
            bookmarkCount: data["bookmarkCount"] as? Int ?? 0,
            commentCount: data["commentCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            viewCount: data["viewCount"] as? Int ?? 0,
            postedAt: postedAt,
            isLiked: false,
            isBookmarked: false,
            selectedReaction: nil
        )
        post.themes = data["themes"] as? [String] ?? []
        post.authorProfileImageURL = data["authorProfileImageURL"] as? String
        if let cardDict = data["diagnosisCard"] as? [String: Any] {
            post.diagnosisCard = BoardFirestoreService.decodeDiagnosisCard(cardDict)
        }
        return post
    }

    // MARK: - Rooms: Fetch

    /// すべての公開部屋を新しい順に取得。
    func fetchRooms() async throws -> [CommunityRoom] {
        let snapshot = try await roomsCollection
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.map { doc in
            decodeRoom(id: doc.documentID, data: doc.data())
        }
    }

    // MARK: - Rooms: Create

    /// 新しい相談部屋を作成。アイコン/ヘッダー画像は base64 もしくは Storage URL に保存。
    func createRoom(
        title: String,
        subtitle: String,
        iconImageData: Data?,
        headerImageData: Data?,
        ownerId: String?
    ) async throws -> CommunityRoom {
        let id = "room_" + UUID().uuidString.prefix(8).lowercased()
        let now = Timestamp(date: Date())

        var data: [String: Any] = [
            "title": title,
            "subtitle": subtitle,
            "participantCount": 1,
            "blockedUserIds": [String](),
            "joinedUserIds": ownerId.map { [$0] } ?? [String](),
            "createdAt": now,
            "updatedAt": now
        ]
        if let ownerId {
            data["ownerId"] = ownerId
        }

        if let icon = iconImageData {
            let encoded = try await encodeImage(icon, roomId: id, uploadType: .roomIcon)
            if let b64 = encoded.base64 { data["iconImageBase64"] = b64 }
            if let url = encoded.storageURL { data["iconImageURL"] = url }
        }
        if let header = headerImageData {
            let encoded = try await encodeImage(header, roomId: id, uploadType: .roomHeader)
            if let b64 = encoded.base64 { data["headerImageBase64"] = b64 }
            if let url = encoded.storageURL { data["headerImageURL"] = url }
        }

        try await roomsCollection.document(id).setData(data)

        return CommunityRoom(
            id: id,
            title: title,
            subtitle: subtitle,
            participantCount: 1,
            imageURL: data["iconImageURL"] as? String ?? data["headerImageURL"] as? String,
            iconImageData: iconImageData,
            headerImageData: headerImageData,
            isJoined: true,
            iconColor: MeloColors.Brand.pink,
            ownerId: ownerId,
            blockedUserIds: []
        )
    }

    // MARK: - Rooms: Delete

    /// 部屋を削除。配下の posts サブコレクションも順次削除する (Firestore に再帰削除は無いため)。
    func deleteRoom(id: String) async throws {
        // 子: posts (および likes/bookmarks/reactions) を削除
        let postSnapshot = try await postsCollection(roomId: id).getDocuments()
        for postDoc in postSnapshot.documents {
            let postId = postDoc.documentID
            // 各投稿の子コレクションを削除
            for sub in ["likes", "bookmarks", "reactions"] {
                let subSnap = try? await postsCollection(roomId: id)
                    .document(postId)
                    .collection(sub)
                    .getDocuments()
                if let subSnap {
                    for d in subSnap.documents {
                        try? await d.reference.delete()
                    }
                }
            }
            try? await postDoc.reference.delete()
        }
        try await roomsCollection.document(id).delete()
    }

    // MARK: - Rooms: Update Info

    func updateRoomInfo(id: String, title: String, subtitle: String) async throws -> CommunityRoom {
        try await roomsCollection.document(id).updateData([
            "title": title,
            "subtitle": subtitle,
            "updatedAt": Timestamp(date: Date())
        ])
        // 更新済みドキュメントを再取得して返す
        let doc = try await roomsCollection.document(id).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "CommunityRoomFirestoreService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "部屋が見つかりません"])
        }
        return decodeRoom(id: id, data: data)
    }

    // MARK: - Rooms: Update Block List

    func updateBlockList(id: String, blockedUserIds: [String]) async throws -> CommunityRoom {
        try await roomsCollection.document(id).updateData([
            "blockedUserIds": blockedUserIds,
            "updatedAt": Timestamp(date: Date())
        ])
        let doc = try await roomsCollection.document(id).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "CommunityRoomFirestoreService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "部屋が見つかりません"])
        }
        return decodeRoom(id: id, data: data)
    }

    // MARK: - Rooms: Join / Leave

    func joinRoom(roomId: String, userId: String) async throws {
        try await roomsCollection.document(roomId).updateData([
            "joinedUserIds": FieldValue.arrayUnion([userId]),
            "participantCount": FieldValue.increment(Int64(1)),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    func leaveRoom(roomId: String, userId: String) async throws {
        try await roomsCollection.document(roomId).updateData([
            "joinedUserIds": FieldValue.arrayRemove([userId]),
            "participantCount": FieldValue.increment(Int64(-1)),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Posts: Fetch

    func fetchPosts(forRoomId roomId: String) async throws -> [CommunityRoomPost] {
        let snapshot = try await postsCollection(roomId: roomId)
            .order(by: "postedAt", descending: true)
            .getDocuments()

        let myId = BoardAuthService.shared.currentUser?.id

        var posts: [CommunityRoomPost] = []
        for doc in snapshot.documents {
            guard var post = decodePost(id: doc.documentID, roomId: roomId, data: doc.data()) else {
                continue
            }
            // 自分の like / bookmark / reaction を反映
            if let myId {
                async let likedDoc = likesCollection(roomId: roomId, postId: post.id)
                    .document(myId).getDocument()
                async let bookmarkDoc = bookmarksCollection(roomId: roomId, postId: post.id)
                    .document(myId).getDocument()
                async let reactionDoc = reactionsCollection(roomId: roomId, postId: post.id)
                    .document(myId).getDocument()

                if let liked = try? await likedDoc, liked.exists {
                    post.isLiked = true
                }
                if let bookmarked = try? await bookmarkDoc, bookmarked.exists {
                    post.isBookmarked = true
                }
                if let reaction = try? await reactionDoc,
                   let option = reaction.data()?["option"] as? String {
                    post.selectedReaction = option
                }
            }
            posts.append(post)
        }
        return posts
    }

    // MARK: - Posts: Create

    func createPost(_ post: CommunityRoomPost) async throws {
        // App Store Guideline 1.2: 客観的に不適切なコンテンツを投稿時点でフィルタ
        guard !post.body.containsObjectionableContent else {
            throw ContentModeration.ModerationError.objectionableContent
        }
        var data: [String: Any] = [
            "roomId": post.roomId,
            "authorName": post.authorName,
            "authorAvatarSymbol": post.authorAvatarSymbol,
            "authorAvatarColor": post.authorAvatarColor,
            "body": post.body,
            "themes": post.themes,
            "reactionOptions": post.reactionOptions,
            "reactionCounts": post.reactionCounts,
            "bookmarkCount": post.bookmarkCount,
            "commentCount": post.commentCount,
            "likeCount": post.likeCount,
            "viewCount": post.viewCount,
            "postedAt": Timestamp(date: post.postedAt)
        ]
        if let aid = post.authorId { data["authorId"] = aid }
        if let mbti = post.authorMbti { data["authorMbti"] = mbti }
        if let tag = post.relationshipTag { data["relationshipTag"] = tag }
        if let url = post.imageURL { data["imageURL"] = url }
        if let pURL = post.authorProfileImageURL { data["authorProfileImageURL"] = pURL }
        if let card = post.diagnosisCard {
            data["diagnosisCard"] = BoardFirestoreService.diagnosisCardDict(card)
        }

        try await postsCollection(roomId: post.roomId).document(post.id).setData(data)
    }

    // MARK: - Posts: View Count

    /// 投稿の表示回数 (インプレッション) を +1。掲示板と同じ仕様。
    /// クライアント側で `onAppear` のタイミングで呼び出す前提。
    func incrementViewCount(roomId: String, postId: String) async throws {
        try await postsCollection(roomId: roomId).document(postId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])
    }

    // MARK: - Posts: Delete

    /// 投稿を削除。配下の likes / bookmarks / reactions / replies サブコレクションも順次削除する。
    func deletePost(roomId: String, postId: String) async throws {
        // 返信とその子も削除
        if let replies = try? await repliesCollection(roomId: roomId, postId: postId).getDocuments() {
            for d in replies.documents {
                let likes = try? await d.reference.collection("likes").getDocuments()
                if let likes {
                    for l in likes.documents {
                        try? await l.reference.delete()
                    }
                }
                try? await d.reference.delete()
            }
        }
        // その他の子コレクション
        for sub in ["likes", "bookmarks", "reactions"] {
            let snap = try? await postsCollection(roomId: roomId)
                .document(postId)
                .collection(sub)
                .getDocuments()
            if let snap {
                for d in snap.documents {
                    try? await d.reference.delete()
                }
            }
        }
        try await postsCollection(roomId: roomId).document(postId).delete()
    }

    // MARK: - Replies: Fetch

    /// 投稿の返信を作成日時昇順で取得。
    func fetchReplies(roomId: String, postId: String) async throws -> [BoardReply] {
        let snapshot = try await repliesCollection(roomId: roomId, postId: postId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { doc -> BoardReply? in
            decodeReply(id: doc.documentID, postId: postId, data: doc.data())
        }
    }

    /// Firestore ドキュメントから BoardReply を復元 (相談部屋サブコレクション用)。
    private func decodeReply(id: String, postId: String, data: [String: Any]) -> BoardReply? {
        guard let authorId = data["authorId"] as? String,
              let authorDisplayName = data["authorDisplayName"] as? String,
              let content = data["content"] as? String else {
            return nil
        }
        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else {
            createdAt = Date()
        }
        var badge: LoveTypeBadge?
        if let b = data["authorBadge"] as? [String: Any],
           let code = b["typeCode"] as? String,
           let name = b["typeName"] as? String,
           let total = b["totalScore"] as? Int {
            badge = LoveTypeBadge(typeCode: code, typeName: name, totalScore: total)
        }
        return BoardReply(
            id: id,
            postId: postId,
            authorId: authorId,
            authorDisplayName: authorDisplayName,
            authorProfileImageURL: data["authorProfileImageURL"] as? String,
            authorBadge: badge,
            content: content,
            stamp: nil,
            imageURLs: data["imageURLs"] as? [String] ?? [],
            likeCount: data["likeCount"] as? Int ?? 0,
            mentionedReplyId: data["mentionedReplyId"] as? String,
            mentionedUserName: data["mentionedUserName"] as? String,
            createdAt: createdAt,
            likedByCurrentUser: false
        )
    }

    // MARK: - Replies: Create

    func createReply(
        roomId: String,
        postId: String,
        content: String,
        authorId: String,
        authorName: String,
        authorProfileImageURL: String?,
        badge: LoveTypeBadge?,
        mention: ReplyMentionInfo?
    ) async throws -> BoardReply {
        // App Store Guideline 1.2: 客観的に不適切なコンテンツを投稿時点でフィルタ
        guard !content.containsObjectionableContent else {
            throw ContentModeration.ModerationError.objectionableContent
        }
        let now = Timestamp(date: Date())
        var data: [String: Any] = [
            "authorId": authorId,
            "authorDisplayName": authorName,
            "content": content,
            "likeCount": 0,
            "createdAt": now
        ]
        if let authorProfileImageURL { data["authorProfileImageURL"] = authorProfileImageURL }
        if let badge {
            data["authorBadge"] = [
                "typeCode": badge.typeCode,
                "typeName": badge.typeName,
                "totalScore": badge.totalScore
            ]
        }
        if let mention {
            data["mentionedReplyId"] = mention.replyId
            data["mentionedUserName"] = mention.userName
        }

        let docRef = try await repliesCollection(roomId: roomId, postId: postId)
            .addDocument(data: data)
        // 親投稿の commentCount をインクリメント
        try? await postsCollection(roomId: roomId).document(postId).updateData([
            "commentCount": FieldValue.increment(Int64(1))
        ])

        return BoardReply(
            id: docRef.documentID,
            postId: postId,
            authorId: authorId,
            authorDisplayName: authorName,
            authorProfileImageURL: authorProfileImageURL,
            authorBadge: badge,
            content: content,
            stamp: nil,
            imageURLs: [],
            likeCount: 0,
            mentionedReplyId: mention?.replyId,
            mentionedUserName: mention?.userName,
            createdAt: Date(),
            likedByCurrentUser: false
        )
    }

    // MARK: - Replies: Delete

    func deleteReply(roomId: String, postId: String, replyId: String) async throws {
        // 返信の likes 子コレクションも掃除
        if let likes = try? await replyLikesCollection(roomId: roomId, postId: postId, replyId: replyId).getDocuments() {
            for d in likes.documents {
                try? await d.reference.delete()
            }
        }
        try await repliesCollection(roomId: roomId, postId: postId).document(replyId).delete()
        // 親投稿の commentCount をデクリメント
        try? await postsCollection(roomId: roomId).document(postId).updateData([
            "commentCount": FieldValue.increment(Int64(-1))
        ])
    }

    // MARK: - Replies: Toggle Like

    /// 返信の like トグル。返り値はトグル後の状態 (true = like 中)。
    func toggleReplyLike(roomId: String, postId: String, replyId: String, userId: String) async throws -> Bool {
        let likeDoc = replyLikesCollection(roomId: roomId, postId: postId, replyId: replyId).document(userId)
        let existing = try await likeDoc.getDocument()
        let replyRef = repliesCollection(roomId: roomId, postId: postId).document(replyId)
        if existing.exists {
            try await likeDoc.delete()
            try? await replyRef.updateData(["likeCount": FieldValue.increment(Int64(-1))])
            return false
        } else {
            try await likeDoc.setData([
                "userId": userId,
                "createdAt": Timestamp(date: Date())
            ])
            try? await replyRef.updateData(["likeCount": FieldValue.increment(Int64(1))])
            return true
        }
    }

    /// 自分が指定の返信に like しているかを返す。
    func isReplyLiked(roomId: String, postId: String, replyId: String, userId: String) async throws -> Bool {
        let doc = try await replyLikesCollection(roomId: roomId, postId: postId, replyId: replyId)
            .document(userId)
            .getDocument()
        return doc.exists
    }

    // MARK: - Posts: Toggle Like

    /// 投稿の like 状態をトグル (現在のユーザー基準)。
    func toggleLike(roomId: String, postId: String, userId: String) async throws {
        let likeDoc = likesCollection(roomId: roomId, postId: postId).document(userId)
        let existing = try await likeDoc.getDocument()
        if existing.exists {
            try await likeDoc.delete()
            try await postsCollection(roomId: roomId).document(postId).updateData([
                "likeCount": FieldValue.increment(Int64(-1))
            ])
        } else {
            try await likeDoc.setData([
                "userId": userId,
                "createdAt": Timestamp(date: Date())
            ])
            try await postsCollection(roomId: roomId).document(postId).updateData([
                "likeCount": FieldValue.increment(Int64(1))
            ])
        }
    }

    // MARK: - Posts: Toggle Bookmark

    func toggleBookmark(roomId: String, postId: String, userId: String) async throws {
        let bookmarkDoc = bookmarksCollection(roomId: roomId, postId: postId).document(userId)
        let existing = try await bookmarkDoc.getDocument()
        if existing.exists {
            try await bookmarkDoc.delete()
            try await postsCollection(roomId: roomId).document(postId).updateData([
                "bookmarkCount": FieldValue.increment(Int64(-1))
            ])
        } else {
            try await bookmarkDoc.setData([
                "userId": userId,
                "createdAt": Timestamp(date: Date())
            ])
            try await postsCollection(roomId: roomId).document(postId).updateData([
                "bookmarkCount": FieldValue.increment(Int64(1))
            ])
        }
    }

    // MARK: - Posts: Set Reaction

    /// ユーザーのリアクションを設定。同じものを再選択するとクリア。
    func setReaction(roomId: String, postId: String, userId: String, option: String) async throws {
        let reactionDoc = reactionsCollection(roomId: roomId, postId: postId).document(userId)
        let postRef = postsCollection(roomId: roomId).document(postId)
        let existing = try await reactionDoc.getDocument()
        let prev = existing.data()?["option"] as? String

        if prev == option {
            // 解除
            try await reactionDoc.delete()
            try await postRef.updateData([
                "reactionCounts.\(option)": FieldValue.increment(Int64(-1))
            ])
        } else {
            if let prev {
                try await postRef.updateData([
                    "reactionCounts.\(prev)": FieldValue.increment(Int64(-1))
                ])
            }
            try await reactionDoc.setData([
                "userId": userId,
                "option": option,
                "createdAt": Timestamp(date: Date())
            ])
            try await postRef.updateData([
                "reactionCounts.\(option)": FieldValue.increment(Int64(1))
            ])
        }
    }
}
