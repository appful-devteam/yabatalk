import SwiftUI
import SwiftData

// MARK: - Chat List Destination

struct ChatListDestination: Hashable {
    let result: AnalysisResult
    let session: ChatSession?
}

// MARK: - Chat List View

struct ChatListView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    @Query(sort: \StoredAnalysisResult.analyzedAt, order: .reverse)
    private var analysisHistory: [StoredAnalysisResult]

    @State private var refreshTrigger = false
    @State private var showPersonaChatConsent = false
    @State private var pendingChatResult: StoredAnalysisResult?
    @AppStorage(Constants.StorageKeys.hasSeenPersonaChatTutorial)
    private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var showHelpSheet = false
    @StateObject private var limitManager = PersonaChatLimitManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var cachedChats: [String: PersonaChat] = [:]

    // Figma design tokens
    private let headerBg = MeloColors.Dark.bgElevated   // 全ページで白ヘッダー統一
    private let headerBorder = MeloColors.Dark.divider
    // テキストは黒系で統一 (旧 716463 茶 → 1E1E1E)
    private let textColor = MeloColors.Dark.textPrimary
    private let pinkAccent = MeloColors.Dark.accent
    private let timeColor = MeloColors.Dark.accent
    // 薄茶 DACDC4 → 薄灰 B6B6B6
    private let secondaryText = MeloColors.Dark.textSecondary
    // カード枠など stroke 用の柔らかい色 (旧 textColor を共有していた箇所)
    private let cardStroke = MeloColors.Dark.cardStroke  // 濃いグレー統一

    var body: some View {
        ZStack {
            // 背景は白統一 (カード領域はピンクを避ける)
            MeloColors.Dark.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (Figma node 559:1346)
                header

                if uniqueResults.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            cachedChats = PersonaChatViewModel.loadAllChats()
            refreshTrigger.toggle()
            if !hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTutorial = true
                }
            }
        }
        .overlay {
            if showTutorial {
                PersonaChatTutorialPopupView {
                    let isFirstTime = !hasSeenTutorial
                    showTutorial = false
                    hasSeenTutorial = true
                    // 初回のみチュートリアル後にPaywallを表示
                    if isFirstTime {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            coordinator.subscriptionSource = "chat_tutorial"
                            coordinator.showingSubscription = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPersonaChatConsent) {
            GeminiConsentView(featureType: .personaChat) {
                if let result = pendingChatResult {
                    pendingChatResult = nil
                    navigateToChat(result)
                }
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            ChatHelpSheet()
        }
    }

    // MARK: - Unique Results (one per session, "all" period preferred)

    private var uniqueResults: [StoredAnalysisResult] {
        var sessionMap: [UUID: StoredAnalysisResult] = [:]

        for result in analysisHistory {
            // グループチャットは除外（擬人化チャットは1対1のみ対応）。
            // 新規データは groupParticipantNames で判定し、フィールド未設定の旧データは
            // partnerParticipant が「A・B・C」と「・」結合になっている点で検出する。
            if (result.groupParticipantNames?.count ?? 0) > 2 { continue }
            if result.partnerParticipant.contains("・") { continue }

            if let existing = sessionMap[result.sessionId] {
                if result.period == "all" && existing.period != "all" {
                    sessionMap[result.sessionId] = result
                } else if result.period == "all" && existing.period == "all" && result.analyzedAt > existing.analyzedAt {
                    sessionMap[result.sessionId] = result
                }
            } else {
                sessionMap[result.sessionId] = result
            }
        }

        return Array(sessionMap.values).sorted { a, b in
            let chatA = cachedChats[a.sessionId.uuidString]
            let chatB = cachedChats[b.sessionId.uuidString]
            let dateA = chatA?.lastMessageAt ?? a.analyzedAt
            let dateB = chatB?.lastMessageAt ?? b.analyzedAt
            return dateA > dateB
        }
    }

    // MARK: - Header (Figma node 559:1346)

    private var header: some View {
        VStack(spacing: 0) {
            // 注意文 (Gemini AI 使用に関する注意) はヘッダー外 (chatList 上端) に移動。
            // ヘッダーはタイトル + 右側ボタンの 1 行構成だけにし、その分縦に狭くする。
            HStack(alignment: .center, spacing: 8) {
                Text(String(localized: "チャット", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(22))
                    .tracking(0.66)
                    .foregroundColor(textColor)

                Spacer(minLength: 0)

                // ヘルプアイコン (PremiumBadgeButton.height = 32 と揃える)
                Button {
                    HapticManager.light()
                    showHelpSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(MeloColors.Dark.card)
                            .overlay(
                                Circle().stroke(headerBorder, lineWidth: 1)
                            )
                            .frame(width: PremiumBadgeButton.height, height: PremiumBadgeButton.height)

                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(textColor)
                    }
                }
                .buttonStyle(.plain)

                // 30/30 使用回数バッジ
                usageBadge

                // Premium ボタン (加入中でも表示・タップで購読管理/購読画面へ) — rightmost
                PremiumBadgeButton(source: "chat_list") {
                    HapticManager.medium()
                    coordinator.subscriptionSource = "chat_list"
                    coordinator.showingSubscription = true
                }
            }
            .padding(.horizontal, MeloLayout.titleHorizontalPadding)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(headerBg)

            Rectangle()
                .fill(headerBorder)
                .frame(height: 3)
        }
    }

    private var usageBadge: some View {
        Text("\(limitManager.remainingMessages)/\(limitManager.dailyLimit)")
            .font(MeloFonts.zenMaruOrFallback(13))
            .tracking(0.4)
            .foregroundColor(
                limitManager.hasReachedLimit ? MeloColors.Dark.accentDeep : textColor
            )
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .frame(height: PremiumBadgeButton.height)
            .background(
                Capsule()
                    .fill(MeloColors.Dark.bgElevated)
            )
    }

    private var premiumButton: some View {
        Button {
            HapticManager.medium()
            coordinator.subscriptionSource = "chat_list"
            coordinator.showingSubscription = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(MeloColors.Dark.onAccent)
                Text(String(localized: "Premium", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(15))
                    .tracking(0.45)
                    .foregroundColor(MeloColors.Dark.onAccent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .frame(height: 37)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(pinkAccent)
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("mero_pair_11")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            Text(String(localized: "診断するとチャットできるよ", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(15))
                .foregroundColor(MeloColors.Dark.textSecondary)

            Text(String(localized: "LINEのトーク履歴を取り込んで\n相手の性格をAIが再現します", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Chat List

    private var chatList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                // AI 注意文 (旧ヘッダー下段から移動) — 一番上に配置（送信先プロバイダは Remote Config 駆動）
                Text(String(format: String(localized: "%1$@ の生成AI使用　ートーク履歴の一部が%2$@に送信されます", bundle: LanguageManager.appBundle), RemoteConfigService.shared.currentAIProvider.serviceName, RemoteConfigService.shared.currentAIProvider.companyName))
                    .font(MeloFonts.zenMaruOrFallback(10))
                    .tracking(0.3)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)

                // バナー広告（相手カードの一番上に配置）。非課金 & ads_enabled のときだけ表示され、
                // それ以外は EmptyView なので隙間は生まれない（広告 ON 時のみ広告分の高さを取る）。
                AdBannerContainer(adUnitID: AdUnitID.bannerChat)
                    .padding(.bottom, 4)

                ForEach(uniqueResults, id: \.id) { result in
                    chatRow(result)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Chat Row (Figma card style)

    private func chatRow(_ result: StoredAnalysisResult) -> some View {
        let chat = cachedChats[result.sessionId.uuidString]
        let hasUnread = chat?.hasUnread ?? false
        let unreadCount = chat?.unreadCount ?? 0
        let lastMessage = chat?.messages.last

        return Button {
            HapticManager.light()
            openChat(result)
        } label: {
            HStack(spacing: 12) {
                // Avatar (39x39)
                avatar(for: result)
                    .frame(width: 39, height: 39)

                // Name + Last Message (flex-1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.partnerParticipant)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(0.42)
                        .foregroundColor(textColor)
                        .lineLimit(1)

                    Group {
                        if let msg = lastMessage {
                            let senderName = msg.role == .user
                                ? String(localized: "自分", bundle: LanguageManager.appBundle)
                                : result.partnerParticipant
                            Text("\(senderName)：\(msg.text)")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(0.36)
                                .foregroundColor(hasUnread ? textColor.opacity(0.8) : secondaryText)
                                .lineLimit(1)
                        } else {
                            Text(String(localized: "タップしてチャットを始めよう", bundle: LanguageManager.appBundle))
                                .font(.system(size: 12, weight: .medium))
                                .tracking(0.36)
                                .foregroundColor(secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right column: time + unread badge (w 52)
                VStack(alignment: .trailing, spacing: 3) {
                    if let date = lastMessage?.createdAt ?? chat?.lastMessageAt ?? chat?.createdAt {
                        Text(relativeTime(date))
                            .font(MeloFonts.zenMaruOrFallback(11))
                            .tracking(0.33)
                            .foregroundColor(timeColor)
                    } else {
                        Text(" ")
                            .font(MeloFonts.zenMaruOrFallback(11))
                    }

                    if unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(timeColor)
                                .frame(width: 21, height: 21)
                            Text("\(unreadCount)")
                                .font(MeloFonts.zenMaruOrFallback(12))
                                .foregroundColor(MeloColors.Dark.onAccent)
                        }
                    }
                }
                .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 15)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(cardStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Avatar

    /// 診断結果に紐づく相手の画像を表示する。
    /// 1) ユーザーが PhotosPicker で選んだ独自画像があればそれを使う
    /// 2) なければプリセットの consult_partner_meromaru_XX
    /// 3) 全て未設定なら char_meromaru_3d
    private func avatar(for result: StoredAnalysisResult) -> some View {
        let customImageData = ConsultationPartnerAvatarStore.customImageData(for: result.sessionId)
        let avatarName = ConsultationPartnerAvatarStore.avatarName(for: result.sessionId) ?? "char_meromaru_3d"
        return ZStack {
            Circle()
                .fill(MeloColors.Dark.card)
            if let data = customImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(avatarName)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            }
        }
        .overlay(
            Circle()
                .stroke(MeloColors.Dark.accent.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Open Chat

    private func openChat(_ result: StoredAnalysisResult) {
        // 擬人化チャットの同意チェック
        guard GeminiConsentView.hasAgreed(for: .personaChat) else {
            pendingChatResult = result
            showPersonaChatConsent = true
            return
        }

        navigateToChat(result)
    }

    private func navigateToChat(_ result: StoredAnalysisResult) {
        let analysisResult = result.toAnalysisResult()
        Task {
            let session = await loadChatSession(sessionId: result.sessionId)
            let destination = ChatListDestination(result: analysisResult, session: session)
            coordinator.chatPath.append(destination)
        }
    }

    private func loadChatSession(sessionId: UUID) async -> ChatSession? {
        return await Task.detached(priority: .userInitiated) {
            let container = await SwiftDataContainer.shared.container
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<StoredChatSession>(
                predicate: #Predicate<StoredChatSession> { $0.id == sessionId }
            )
            guard let storedSession = try? context.fetch(descriptor).first,
                  let data = storedSession.chatSessionData else { return nil as ChatSession? }
            return try? JSONDecoder().decode(ChatSession.self, from: data)
        }.value
    }

    // MARK: - Relative Time

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return String(localized: "たった今", bundle: LanguageManager.appBundle)
        } else if interval < 3600 {
            return String(localized: "\(Int(interval / 60))分前", bundle: LanguageManager.appBundle)
        } else if interval < 86400 {
            return String(localized: "\(Int(interval / 3600))時間前", bundle: LanguageManager.appBundle)
        } else if interval < 604800 {
            return String(localized: "\(Int(interval / 86400))日前", bundle: LanguageManager.appBundle)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Chat Help Sheet

private struct ChatHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(MeloColors.Dark.accent)
                        Text(String(localized: "AIチャットについて", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(18))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        helpItem(
                            title: String(format: String(localized: "%@ を使用", bundle: LanguageManager.appBundle), RemoteConfigService.shared.currentAIProvider.serviceName),
                            body: String(format: String(localized: "相手の性格をAIが再現したチャット体験を提供するため、%1$@ が提供する生成AI「%2$@」を使用しています。", bundle: LanguageManager.appBundle), RemoteConfigService.shared.currentAIProvider.companyShort, RemoteConfigService.shared.currentAIProvider.serviceName)
                        )

                        helpItem(
                            title: String(localized: "送信されるデータ", bundle: LanguageManager.appBundle),
                            body: String(format: String(localized: "あなたが送信したメッセージと、相手の性格再現に必要なトーク履歴の一部が%@のサーバーに送信されます。個人を特定する情報は送信されません。", bundle: LanguageManager.appBundle), RemoteConfigService.shared.currentAIProvider.companyName)
                        )

                        helpItem(
                            title: String(localized: "1日の利用制限", bundle: LanguageManager.appBundle),
                            body: String(localized: "無料プランでは1日あたりのメッセージ送信数に上限があります。Premiumプランにご加入いただくと無制限でご利用いただけます。", bundle: LanguageManager.appBundle)
                        )

                        helpItem(
                            title: String(localized: "ご注意", bundle: LanguageManager.appBundle),
                            body: String(localized: "AIが生成する返信はあくまでシミュレーションです。実際の相手の発言や意見を表すものではありません。", bundle: LanguageManager.appBundle)
                        )
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(MeloColors.Dark.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "閉じる", bundle: LanguageManager.appBundle)) {
                        dismiss()
                    }
                    .foregroundColor(MeloColors.Dark.accent)
                }
            }
        }
    }

    private func helpItem(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(MeloColors.Dark.textPrimary)
            Text(body)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeloColors.Dark.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ChatListView()
    }
    .modelContainer(for: [StoredChatSession.self, StoredAnalysisResult.self])
}
