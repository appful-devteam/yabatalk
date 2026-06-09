import SwiftUI

// MARK: - Board Notifications View
struct BoardNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = BoardAuthService.shared
    @State private var notifications: [BoardNotification] = []
    @State private var isLoading = true
    @State private var selectedPostId: String?
    @State private var selectedPost: BoardPost?

    private let firestoreService = BoardFirestoreService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeloColors.Dark.bg
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(BoardColors.accent)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle(String(localized: "おしらせ", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                    }
                }
            }
            .sheet(item: $selectedPost) { post in
                BoardPostDetailView(post: post)
            }
        }
        .onAppear {
            Task { await loadNotifications() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("mero_pair_03")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            Text(String(localized: "おしらせはまだありません", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(BoardColors.textTertiary)
        }
    }

    // MARK: - Notification List

    private var notificationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(notifications) { notification in
                    notificationRow(notification)
                }
            }
            .padding(.top, 8)
        }
    }

    private func notificationRow(_ notification: BoardNotification) -> some View {
        Button {
            HapticManager.light()
            // followタイプは投稿がないのでタップしない
            guard notification.type != "follow" else { return }
            Task {
                if let post = try? await firestoreService.fetchPost(postId: notification.postId) {
                    selectedPost = post
                }
            }
        } label: {
            HStack(spacing: 12) {
                // アイコン
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BoardColors.accentLight.opacity(0.5), BoardColors.accent.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: notificationIcon(for: notification.type))
                            .font(.system(size: 14))
                            .foregroundColor(BoardColors.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(notificationMessage(notification))
                        .font(MeloFonts.zenMaruOrFallback(13))
                        .foregroundColor(BoardColors.textPrimary)

                    Text(BoardTimeFormatter.timeAgo(notification.createdAt))
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(BoardColors.textTertiary)
                }

                Spacer()

                if !notification.read {
                    Circle()
                        .fill(BoardColors.accent)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                notification.read
                ? MeloColors.Dark.card
                : MeloColors.Dark.bgElevated
            )
        }
        .buttonStyle(.plain)
    }

    private func notificationIcon(for type: String) -> String {
        switch type {
        case "reply": return "bubble.left.fill"
        case "reaction": return "heart.fill"
        case "follow": return "person.badge.plus"
        case "follow_request": return "person.badge.clock"
        case "follow_request_accepted": return "person.badge.check"
        case "following_post": return "square.and.pencil"
        default: return "bell.fill"
        }
    }

    private func notificationMessage(_ notification: BoardNotification) -> String {
        switch notification.type {
        case "reply":
            return String(localized: "\(notification.actorName) が返信しました", bundle: LanguageManager.appBundle)
        case "reaction":
            return String(localized: "\(notification.actorName) がいいねしました", bundle: LanguageManager.appBundle)
        case "follow":
            return String(localized: "\(notification.actorName) にフォローされました", bundle: LanguageManager.appBundle)
        case "follow_request":
            return String(localized: "\(notification.actorName) からフォローリクエストが届きました", bundle: LanguageManager.appBundle)
        case "follow_request_accepted":
            return String(localized: "\(notification.actorName) がフォローリクエストを承認しました", bundle: LanguageManager.appBundle)
        case "following_post":
            return String(localized: "\(notification.actorName) が新しく投稿しました", bundle: LanguageManager.appBundle)
        default:
            return String(localized: "\(notification.actorName) から通知があります", bundle: LanguageManager.appBundle)
        }
    }

    // MARK: - Actions

    private func loadNotifications() async {
        guard let userId = authService.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            notifications = try await firestoreService.fetchNotifications(userId: userId)
            try? await firestoreService.markNotificationsRead(userId: userId)
        } catch {
            print("[Board] Failed to load notifications: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    BoardNotificationsView()
}
