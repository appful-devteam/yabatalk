import SwiftUI
import PhotosUI

// MARK: - Persona Chat Colors (Figma node 615:51)
private enum ChatColors {
    /// ヘッダー薄ピンク
    static let headerBg = MeloColors.Dark.bgElevated
    /// 自分バブル（こいピンク確定）
    static let userBubble = MeloColors.Dark.accent
    /// 相手バブル（白）
    static let partnerBubble = MeloColors.Dark.card
    /// システム通知背景（激薄茶）
    static let systemBg = MeloColors.Dark.bgElevated
    /// 文字色（黒系 — 旧 716463 茶を 1E1E1E に変更）
    static let textMain = MeloColors.Dark.textPrimary
    /// バブル枠 / dot 等の装飾用（旧 textMain と同じ茶を維持）
    static let bubbleStroke = MeloColors.Dark.cardStroke
    /// 入力欄ボーダー
    static let inputBorder = MeloColors.Dark.cardStroke
}

// MARK: - Persona Chat View
struct PersonaChatView: View {
    @StateObject var viewModel: PersonaChatViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirm = false

    /// チャット本体を暗くする条件: setup / カード生成中 / 学習データ無し のいずれか。
    private var shouldDimChatBody: Bool {
        viewModel.needsSetup
            || viewModel.isGeneratingPersonaCard
            || !viewModel.hasLearningData
    }
    // 入力中テキストは viewModel.inputText を真実とし、TextField を直接 binding する。
    // 旧実装は View ローカルの @State と viewModel の @Published に二重管理しており、
    // 1 通目の送信直後に SwiftUI のレンダリング順序の関係で TextField がローカル値の
    // 残骸を一瞬表示してしまっていた。

    var body: some View {
        ZStack {
            // Background: Body は白。ヘッダー部分だけピンクを敷く。
            MeloColors.Dark.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                chatMessagesView
                inputBar
            }
            .opacity(shouldDimChatBody ? 0.3 : 1)
            .allowsHitTesting(!shouldDimChatBody)

            // Initial setup overlay
            if viewModel.needsSetup {
                PersonaChatSetupView(
                    partnerName: viewModel.chat.partnerName,
                    defaultCallName: viewModel.defaultUserCallName,
                    onComplete: { settings, callName in
                        viewModel.applySettings(settings, userCallName: callName)
                    }
                )
                .transition(.opacity)
            } else if viewModel.isGeneratingPersonaCard {
                PersonaCardLoadingOverlay(partnerName: viewModel.chat.partnerName)
                    .transition(.opacity)
            } else if !viewModel.hasLearningData {
                // 学習元のトーク履歴が無い(または極端に少ない)場合の案内オーバーレイ。
                // 古いセッションは保存容量のため chatSessionData が破棄されており、
                // この場合 Persona は実データから生成できない。再インポートを促す。
                PersonaLearningEmptyOverlay(
                    partnerName: viewModel.chat.partnerName,
                    onClose: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.needsSetup)
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasLearningData)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isGeneratingPersonaCard)
        .navigationBarHidden(true)
        .enableSwipeBack()
        .alert(String(localized: "チャットを削除しますか？", bundle: LanguageManager.appBundle), isPresented: $showClearConfirm) {
            Button(String(localized: "削除", bundle: LanguageManager.appBundle), role: .destructive) {
                viewModel.clearChat()
            }
            Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .cancel) {}
        }
        .alert(String(localized: "本日の送信上限に達しました", bundle: LanguageManager.appBundle), isPresented: $viewModel.showLimitReached) {
            if SubscriptionManager.shared.currentTier != .premiumPlus {
                Button(String(localized: "プランをアップグレード", bundle: LanguageManager.appBundle)) {
                    coordinator.subscriptionSource = "persona_chat_limit"
                    coordinator.showingSubscription = true
                }
            }
            Button(String(localized: "OK", bundle: LanguageManager.appBundle), role: .cancel) {}
        } message: {
            let limit = PersonaChatLimitManager.shared.dailyLimit
            Text(String(localized: "1日あたり\(limit)回まで送信できます。明日またお話ししましょう！", bundle: LanguageManager.appBundle))
        }
        .sheet(isPresented: $viewModel.showSettings) {
            PersonaChatSettingsSheet(
                settings: viewModel.chat.resolvedSettings,
                userCallName: viewModel.chat.userCallName ?? viewModel.defaultUserCallName,
                partnerName: viewModel.chat.partnerName,
                sessionId: viewModel.chat.sessionId,
                personaCardGeneratedAt: viewModel.chat.personaCard?.generatedAt,
                personaCardSummary: viewModel.chat.personaCard?.summary,
                learningSummary: viewModel.learningStyleSummary,
                onSave: { settings, callName in
                    viewModel.updateSettings(settings, userCallName: callName)
                },
                onRegeneratePersona: {
                    Task { await viewModel.regeneratePersonaCard() }
                }
            )
        }
        .onAppear { viewModel.onChatAppear() }
        .onDisappear { viewModel.onChatDisappear() }
        .alert(
            String(localized: "エラー", bundle: LanguageManager.appBundle),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "OK", bundle: LanguageManager.appBundle), role: .cancel) {}
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Header (Figma: 74pt, 薄ピンク #FFF1F4)

    private var header: some View {
        ZStack {
            // 中央: アバター + 相手名
            HStack(spacing: 8) {
                partnerAvatar(size: 24, borderWidth: 0.3)
                Text(viewModel.chat.partnerName)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(ChatColors.textMain)
                    .lineLimit(1)
            }

            // 左右: 戻る / メニュー
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(ChatColors.textMain)
                        .frame(width: 24, height: 24)
                }

                Spacer()

                Menu {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Label(
                            String(localized: "チャット設定", bundle: LanguageManager.appBundle),
                            systemImage: "gearshape"
                        )
                    }
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label(
                            String(localized: "チャットを削除", bundle: LanguageManager.appBundle),
                            systemImage: "trash"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ChatColors.textMain)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, MeloLayout.titleHorizontalPadding)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(MeloColors.Dark.bgElevated.ignoresSafeArea(edges: .top))
    }

    // MARK: - Chat Messages

    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let firstDate = viewModel.chat.messages.first?.createdAt {
                        dateHeader(firstDate)
                    }

                    ForEach(Array(viewModel.chat.messages.enumerated()), id: \.element.id) { index, message in
                        if index > 0 && !Calendar.current.isDate(message.createdAt, inSameDayAs: viewModel.chat.messages[index - 1].createdAt) {
                            dateHeader(message.createdAt)
                        }

                        messageBubble(message)
                            .id(message.id)
                    }

                    if viewModel.showTypingIndicator {
                        typingIndicator
                            .id("typingIndicator")
                    }

                    // スクロール用アンカー
                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(MeloColors.Dark.bg)
            .onChange(of: viewModel.chat.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.showTypingIndicator) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        }
    }

    // MARK: - Message Bubble (Figma: 214pt width, corner15, padding10, Zen Maru Medium 12, tracking 0.36)

    private func messageBubble(_ message: PersonaChatMessage) -> some View {
        let isUser = message.role == .user
        let bubbleWidth: CGFloat = 214

        return HStack(alignment: .top, spacing: 9) {
            if isUser {
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    userBubbleContent(message, width: bubbleWidth)
                    Text(timeString(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(ChatColors.textMain.opacity(0.5))
                }
            } else {
                partnerAvatar(size: 35, borderWidth: 0.5)

                VStack(alignment: .leading, spacing: 4) {
                    partnerBubbleContent(message, width: bubbleWidth)
                    Text(timeString(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(ChatColors.textMain.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func partnerBubbleContent(_ message: PersonaChatMessage, width: CGFloat) -> some View {
        // Text は wrap 用に内側で width を提案、padding+background でバブル化、
        // 最後の .frame は HStack 上の配置スロット (alignment .leading) として機能。
        // テキストが短いときは Text が自然幅、背景もそれに沿って縮む。
        Text(message.text)
            .font(MeloFonts.zenMaruMedium(12))
            .tracking(0.36)
            .foregroundColor(ChatColors.textMain)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(ChatColors.partnerBubble)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(ChatColors.bubbleStroke, lineWidth: 1)
            )
            .frame(maxWidth: width + 20, alignment: .leading)
    }

    private func userBubbleContent(_ message: PersonaChatMessage, width: CGFloat) -> some View {
        Text(message.text)
            .font(MeloFonts.zenMaruMedium(12))
            .tracking(0.36)
            .foregroundColor(MeloColors.Dark.onAccent)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(ChatColors.userBubble)
            )
            .frame(maxWidth: width + 20, alignment: .trailing)
    }

    // MARK: - System Notification (Figma: 激薄茶 #F5F1ED, corner20, 10/5 padding)

    @ViewBuilder
    private func systemNotice(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(MeloFonts.zenMaruMedium(10))
                .tracking(0.3)
                .foregroundColor(ChatColors.textMain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(ChatColors.systemBg)
                )
            Spacer()
        }
    }

    // MARK: - Partner Avatar

    /// 1) ユーザーが選んだ独自画像 (PhotosPicker から)
    /// 2) なければプリセットのめろまる画像
    /// 3) 全て無ければデフォルトのめろまる
    private func partnerAvatar(size: CGFloat, borderWidth: CGFloat) -> some View {
        let sessionId = viewModel.chat.sessionId
        let customImageData = ConsultationPartnerAvatarStore.customImageData(for: sessionId)
        let avatarName = ConsultationPartnerAvatarStore.avatarName(for: sessionId) ?? "char_meromaru_3d"
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
        .frame(width: size, height: size)
        .overlay(Circle().stroke(MeloColors.Dark.accent.opacity(0.35), lineWidth: borderWidth))
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 9) {
            partnerAvatar(size: 35, borderWidth: 0.5)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(ChatColors.bubbleStroke.opacity(0.45))
                        .frame(width: 6, height: 6)
                        .offset(y: typingDotOffset(index: i))
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: viewModel.showTypingIndicator
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(ChatColors.partnerBubble)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(ChatColors.bubbleStroke, lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
    }

    private func typingDotOffset(index: Int) -> CGFloat {
        viewModel.showTypingIndicator ? -4 : 0
    }

    // MARK: - Date Header

    private func dateHeader(_ date: Date) -> some View {
        HStack {
            Spacer()
            Text(dateString(date))
                .font(MeloFonts.zenMaruMedium(10))
                .tracking(0.3)
                .foregroundColor(ChatColors.textMain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(ChatColors.systemBg)
                )
            Spacer()
        }
    }

    // MARK: - Input Bar (Figma: 白背景, 送信 F7A2BA, border FFD9E1, corner 22)

    private var inputBar: some View {
        // 入力ボックスはテキスト量に応じて 1 行〜10 行で自動リサイズ。
        // axis: .vertical + lineLimit(1...10) で SwiftUI が高さを動的に調整する。
        HStack(alignment: .bottom, spacing: 10) {
            HStack {
                TextField(
                    String(localized: "メッセージを入力", bundle: LanguageManager.appBundle),
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(ChatColors.textMain)
                .tint(ChatColors.userBubble)
                .lineLimit(1...10)
                .focused($isInputFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 38)
            .background(MeloColors.Dark.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .onTapGesture {
                isInputFocused = true
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(ChatColors.inputBorder, lineWidth: 1)
            )

            Button {
                viewModel.sendMessage()  // viewModel 側で inputText を読み取り、空にしてから送信処理
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AnyShapeStyle(MeloColors.Dark.bgElevated)
                                : AnyShapeStyle(ChatColors.userBubble)
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? MeloColors.Dark.textSecondary
                                : MeloColors.Dark.onAccent
                        )
                }
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            MeloColors.Dark.bgElevated
                .overlay(
                    Rectangle()
                        .fill(MeloColors.Dark.divider)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d (E)"
        formatter.locale = LanguageManager.shared.locale
        return formatter.string(from: date)
    }
}

// MARK: - Initial Setup View

struct PersonaChatSetupView: View {
    let partnerName: String
    let defaultCallName: String
    let onComplete: (PersonaChatSettings, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var userCallName: String = ""
    @State private var replySpeed: ReplySpeed = .realtime
    @State private var relationshipType: PersonaRelationship = .crush

    // NewHome tokens
    private let brandPink = MeloColors.Dark.accent
    private let filledPink = MeloColors.Dark.accent
    private let brownStroke = MeloColors.Dark.cardStroke
    private let textPrimary = MeloColors.Dark.textPrimary
    private let textMuted = MeloColors.Dark.textSecondary
    private let softFieldBg = MeloColors.Dark.bgElevated

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Soft pink gradient (NewHome)
            LinearGradient(
                colors: [MeloColors.Dark.bg, MeloColors.Dark.bg],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)

                    // Title
                    Text(String(format: String(localized: "%@のAIペルソナ", bundle: LanguageManager.appBundle), partnerName))
                        .font(MeloFonts.zenMaruOrFallback(22))
                        .foregroundColor(MeloColors.Dark.textPrimary)

                    Spacer().frame(height: 14)

                    // Chat preview bubbles
                    VStack(spacing: 8) {
                        HStack {
                            Text(String(format: String(localized: "ねぇ、%@と話せるよ！", bundle: LanguageManager.appBundle), partnerName))
                                .font(MeloFonts.zenMaruOrFallback(13))
                                .foregroundColor(MeloColors.Dark.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(MeloColors.Dark.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(brownStroke, lineWidth: 1)
                                )
                            Spacer()
                        }

                        HStack {
                            Spacer()
                            Text(String(localized: "えっ、ほんとに？", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruOrFallback(13))
                                .foregroundColor(MeloColors.Dark.onAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(filledPink)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 40)

                    // Mascot — 2D meromaru waving
                    Image("char_meromaru_3d")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .padding(.top, 12)

                    Spacer().frame(height: 20)

                    // Settings card — flat white with brown stroke
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: String(localized: "%@からなんて呼ばれてる？", bundle: LanguageManager.appBundle), partnerName))
                                .font(MeloFonts.zenMaruMedium(13))
                                .foregroundColor(brandPink)
                            TextField(String(localized: "例: 〇〇ちゃん、〇〇くん", bundle: LanguageManager.appBundle), text: $userCallName)
                                .font(MeloFonts.zenMaruOrFallback(15))
                                .foregroundColor(textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(softFieldBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(brownStroke.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)

                        Rectangle()
                            .fill(brownStroke.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 14)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "返信速度", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruMedium(13))
                                .foregroundColor(brandPink)
                            HStack(spacing: 8) {
                                ForEach(ReplySpeed.allCases, id: \.self) { speed in
                                    replySpeedButton(speed)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)

                        Rectangle()
                            .fill(brownStroke.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 14)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: String(localized: "%@との関係は？", bundle: LanguageManager.appBundle), partnerName))
                                .font(MeloFonts.zenMaruMedium(13))
                                .foregroundColor(brandPink)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(PersonaRelationship.allCases, id: \.self) { type in
                                    relationshipButton(type)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(MeloColors.Dark.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(brownStroke, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 24)

                    // Start button — flat pink pill
                    Button {
                        let settings = PersonaChatSettings(
                            replySpeed: replySpeed,
                            proactiveMessages: true,
                            notifications: true,
                            relationshipType: relationshipType
                        )
                        let name = userCallName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onComplete(settings, name.isEmpty ? defaultCallName : name)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15))
                                .rotationEffect(.degrees(-25))
                            Text(String(localized: "チャットを始める", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruMedium(16))
                        }
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(filledPink)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // Back button (pink chevron inside white circle)
            Button {
                HapticManager.light()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Dark.card)
                        .overlay(
                            Circle().stroke(brownStroke.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(brandPink)
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .onAppear {
            if userCallName.isEmpty {
                userCallName = defaultCallName
            }
        }
    }

    // MARK: - Setup Helpers

    private func replySpeedButton(_ speed: ReplySpeed) -> some View {
        let isSelected = replySpeed == speed
        return Button {
            replySpeed = speed
        } label: {
            VStack(spacing: 3) {
                Text(speed.icon)
                    .font(.system(size: 16))
                Text(speed.label)
                    .font(MeloFonts.zenMaruOrFallback(10))
                    .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? filledPink : softFieldBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? brandPink : brownStroke.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func relationshipButton(_ type: PersonaRelationship) -> some View {
        let isSelected = relationshipType == type
        return Button {
            relationshipType = type
        } label: {
            HStack(spacing: 6) {
                Text(type.icon)
                    .font(.system(size: 14))
                Text(type.label)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? filledPink : softFieldBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? brandPink : brownStroke.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Persona Card Loading Overlay

/// 人物像カード生成中の全画面オーバーレイ。チャット入力をブロックして待機表示する。
private struct PersonaCardLoadingOverlay: View {
    let partnerName: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(MeloColors.Dark.accent)
                    .scaleEffect(1.2)

                VStack(spacing: 6) {
                    Text(String(format: String(localized: "%@の人物像を準備中…", bundle: LanguageManager.appBundle), partnerName))
                        .font(MeloFonts.zenMaruMedium(15))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(String(localized: "口調や性格を分析しています(数十秒ほど)", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(11))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MeloColors.Dark.card)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Persona Learning Empty Overlay

/// 学習元のトーク履歴データが無い(または極端に少ない)場合のオーバーレイ。
/// このアプリでは保存容量のため古いセッションの chatSessionData は破棄されるので、
/// その状態だと擬人化を実行できない。診断画面からの再インポートに誘導する。
private struct PersonaLearningEmptyOverlay: View {
    let partnerName: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 18) {
                Image("char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)

                VStack(spacing: 8) {
                    Text(String(localized: "学習データがありません", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(17))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(String(format: String(localized: "%@の擬人化は、実際のLINEトーク履歴から口調や性格を学習しています。\n古いトーク履歴は容量の都合で削除されているため、もう一度トークデータを取り込んでください。", bundle: LanguageManager.appBundle), partnerName))
                        .font(MeloFonts.zenMaruOrFallback(12))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    onClose()
                } label: {
                    Text(String(localized: "診断画面に戻る", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MeloColors.Dark.accentGradient)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(MeloColors.Dark.card)
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Settings Sheet

struct PersonaChatSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var settings: PersonaChatSettings
    @State var userCallName: String
    let partnerName: String
    let sessionId: UUID
    /// ペルソナカード最終生成日時(未生成なら nil)。表示にのみ使用。
    let personaCardGeneratedAt: Date?
    /// ペルソナカード本文(未生成なら nil)。シート内で展開表示する。
    let personaCardSummary: String?
    /// 学習データの要約(件数・検出した文体特徴)。silent failureの可視化用。
    let learningSummary: PersonaLearningSummary
    let onSave: (PersonaChatSettings, String) -> Void
    /// 「ペルソナを再生成」ボタン押下時のコールバック。
    let onRegeneratePersona: () -> Void

    @State private var partnerImageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var personaCardExpanded: Bool = false

    // NewHome tokens
    private let brandPink = MeloColors.Dark.accent
    private let filledPink = MeloColors.Dark.accent
    private let brownStroke = MeloColors.Dark.cardStroke
    private let textPrimary = MeloColors.Dark.textPrimary
    private let textMuted = MeloColors.Dark.textSecondary
    /// 入力欄 / 関係性ボタン等の背景 (旧: 白)。
    private let softFieldBg = MeloColors.Dark.bgElevated

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Partner profile image picker
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(String(format: String(localized: "%@のプロフィール画像", bundle: LanguageManager.appBundle), partnerName))
                            HStack(spacing: 14) {
                                partnerImagePreview
                                VStack(alignment: .leading, spacing: 8) {
                                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                                        Text(String(localized: "画像を選ぶ", bundle: LanguageManager.appBundle))
                                            .font(MeloFonts.zenMaruMedium(13))
                                            .foregroundColor(MeloColors.Dark.onAccent)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(MeloColors.Dark.accentGradient))
                                    }
                                    if partnerImageData != nil {
                                        Button {
                                            partnerImageData = nil
                                            photoItem = nil
                                            ConsultationPartnerAvatarStore.setCustomImageData(nil, for: sessionId)
                                        } label: {
                                            Text(String(localized: "デフォルトに戻す", bundle: LanguageManager.appBundle))
                                                .font(MeloFonts.zenMaruMedium(11))
                                                .foregroundColor(MeloColors.Dark.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // User call name
                    settingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader(String(localized: "あなたの呼ばれ方", bundle: LanguageManager.appBundle))
                            Text(String(format: String(localized: "%@からなんて呼ばれていますか？", bundle: LanguageManager.appBundle), partnerName))
                                .font(MeloFonts.zenMaruOrFallback(11))
                                .foregroundColor(textMuted)
                            TextField(String(localized: "例: 〇〇ちゃん、〇〇くん", bundle: LanguageManager.appBundle), text: $userCallName)
                                .font(MeloFonts.zenMaruOrFallback(15))
                                .foregroundColor(textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(softFieldBg)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                                )
                        }
                    }

                    // Reply speed
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(String(localized: "返信速度", bundle: LanguageManager.appBundle))
                            ForEach(ReplySpeed.allCases, id: \.self) { speed in
                                speedRow(speed)
                                if speed != ReplySpeed.allCases.last {
                                    Divider()
                                }
                            }
                        }
                    }

                    // Relationship type
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(String(localized: "関係性", bundle: LanguageManager.appBundle))
                            Text(String(format: String(localized: "%@との関係を選んでください", bundle: LanguageManager.appBundle), partnerName))
                                .font(MeloFonts.zenMaruOrFallback(11))
                                .foregroundColor(textMuted)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(PersonaRelationship.allCases, id: \.self) { type in
                                    settingsRelationshipButton(type)
                                }
                            }
                        }
                    }

                    // Toggles
                    settingsCard {
                        VStack(spacing: 0) {
                            Toggle(isOn: $settings.proactiveMessages) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "自発メッセージ", bundle: LanguageManager.appBundle))
                                        .font(MeloFonts.zenMaruOrFallback(15))
                                        .foregroundColor(textPrimary)
                                    Text(String(localized: "相手から自動的にメッセージが届きます", bundle: LanguageManager.appBundle))
                                        .font(MeloFonts.zenMaruOrFallback(11))
                                        .foregroundColor(textMuted)
                                }
                            }
                            .tint(filledPink)

                            Divider().padding(.vertical, 12)

                            Toggle(isOn: $settings.notifications) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "通知", bundle: LanguageManager.appBundle))
                                        .font(MeloFonts.zenMaruOrFallback(15))
                                        .foregroundColor(textPrimary)
                                    Text(String(localized: "チャットを閉じている間の新着メッセージを通知", bundle: LanguageManager.appBundle))
                                        .font(MeloFonts.zenMaruOrFallback(11))
                                        .foregroundColor(textMuted)
                                }
                            }
                            .tint(filledPink)
                        }
                    }

                    // Learning status panel: 学習材料の可視化 (silent failure 撲滅)
                    settingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader(String(localized: "学習データの状況", bundle: LanguageManager.appBundle))

                            if learningSummary.isEmpty {
                                // データなし or 不足 → 赤字警告
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(MeloColors.Status.error)
                                        .font(.system(size: 14))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(String(format: String(localized: "%@のトーク履歴データが不足しています(%d件)", bundle: LanguageManager.appBundle), partnerName, learningSummary.messageCount))
                                            .font(MeloFonts.zenMaruMedium(13))
                                            .foregroundColor(MeloColors.Status.error)
                                        Text(String(localized: "古いセッションは保存容量のためトーク履歴が削除されています。診断画面からトークを再度取り込むと、このチャットの学習が復活します。", bundle: LanguageManager.appBundle))
                                            .font(MeloFonts.zenMaruOrFallback(11))
                                            .foregroundColor(textMuted)
                                    }
                                }
                            } else {
                                // 学習中 → 検出した特徴を表示
                                learningRow(label: String(localized: "学習対象メッセージ", bundle: LanguageManager.appBundle),
                                            value: "\(learningSummary.messageCount)件")
                                if let fp = learningSummary.firstPerson {
                                    learningRow(label: String(localized: "一人称", bundle: LanguageManager.appBundle),
                                                value: "「\(fp)」")
                                }
                                if let pol = learningSummary.politenessLabel {
                                    learningRow(label: String(localized: "話し方", bundle: LanguageManager.appBundle),
                                                value: pol)
                                }
                                if !learningSummary.topEndings.isEmpty {
                                    learningRow(label: String(localized: "よく使う語尾", bundle: LanguageManager.appBundle),
                                                value: learningSummary.topEndings.map { "「\($0)」" }.joined(separator: " "))
                                }
                                if learningSummary.emojiUse {
                                    let emojiText = learningSummary.topEmojis.isEmpty
                                        ? String(localized: "(検出なし)", bundle: LanguageManager.appBundle)
                                        : learningSummary.topEmojis.joined(separator: " ")
                                    learningRow(label: String(localized: "使う絵文字", bundle: LanguageManager.appBundle),
                                                value: emojiText)
                                } else {
                                    learningRow(label: String(localized: "絵文字", bundle: LanguageManager.appBundle),
                                                value: String(localized: "使わない人(出力時にも除去)", bundle: LanguageManager.appBundle))
                                }
                                if let median = learningSummary.medianLength {
                                    learningRow(label: String(localized: "メッセージ長", bundle: LanguageManager.appBundle),
                                                value: String(format: String(localized: "中央値 %d文字", bundle: LanguageManager.appBundle), median))
                                }
                            }
                        }
                    }

                    // Persona card section: 状態 + 本文プレビュー + 再生成ボタン
                    settingsCard {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader(String(localized: "人物像(ペルソナ)", bundle: LanguageManager.appBundle))
                            Text(String(format: String(localized: "%@の口調や性格をAIが実際のトーク履歴から学習しています。下の本文を確認して、違和感があれば再生成してください。", bundle: LanguageManager.appBundle), partnerName))
                                .font(MeloFonts.zenMaruOrFallback(11))
                                .foregroundColor(textMuted)
                            if let generatedAt = personaCardGeneratedAt {
                                Text(personaCardStatusText(generatedAt))
                                    .font(MeloFonts.zenMaruOrFallback(11))
                                    .foregroundColor(textMuted)
                            } else {
                                Text(String(localized: "まだ生成されていません", bundle: LanguageManager.appBundle))
                                    .font(MeloFonts.zenMaruOrFallback(11))
                                    .foregroundColor(textMuted)
                            }

                            if let summary = personaCardSummary, !summary.isEmpty {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        personaCardExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: personaCardExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(personaCardExpanded
                                             ? String(localized: "本文を隠す", bundle: LanguageManager.appBundle)
                                             : String(localized: "学習された本文を表示", bundle: LanguageManager.appBundle))
                                            .font(MeloFonts.zenMaruMedium(12))
                                    }
                                    .foregroundColor(MeloColors.Dark.accent)
                                }
                                .buttonStyle(.plain)

                                if personaCardExpanded {
                                    ScrollView {
                                        Text(summary)
                                            .font(MeloFonts.zenMaruOrFallback(12))
                                            .foregroundColor(MeloColors.Dark.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                            .padding(12)
                                    }
                                    .frame(maxHeight: 320)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(MeloColors.Dark.bgElevated)
                                    )
                                }
                            }

                            Button {
                                onRegeneratePersona()
                                dismiss()
                            } label: {
                                Text(String(localized: "人物像を再生成", bundle: LanguageManager.appBundle))
                                    .font(MeloFonts.zenMaruMedium(13))
                                    .foregroundColor(MeloColors.Dark.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(MeloColors.Dark.accent, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Save CTA — flat pink pill
                    Button {
                        let name = userCallName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(settings, name)
                        dismiss()
                    } label: {
                        Text(String(localized: "保存", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(16))
                            .foregroundColor(MeloColors.Dark.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(MeloColors.Dark.accentGradient)
                            )
                            .shadow(color: MeloColors.Dark.accent.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: [MeloColors.Dark.bg, MeloColors.Dark.bg],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
            )
            .navigationTitle(String(localized: "チャット設定", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                partnerImageData = ConsultationPartnerAvatarStore.customImageData(for: sessionId)
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            partnerImageData = data
                            ConsultationPartnerAvatarStore.setCustomImageData(data, for: sessionId)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(15))
                            .foregroundColor(MeloColors.Dark.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Settings Helpers

    @ViewBuilder
    private var partnerImagePreview: some View {
        ZStack {
            Circle()
                .fill(MeloColors.Dark.card)
                .overlay(Circle().stroke(MeloColors.Dark.accent.opacity(0.35), lineWidth: 1))
            if let data = partnerImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(ConsultationPartnerAvatarStore.avatarName(for: sessionId) ?? "char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
        }
        .frame(width: 64, height: 64)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
                    )
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(MeloFonts.zenMaruMedium(13))
            .foregroundColor(textPrimary)
            .tracking(0.5)
    }

    private func learningRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(MeloFonts.zenMaruOrFallback(11))
                .foregroundColor(textMuted)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(MeloFonts.zenMaruMedium(12))
                .foregroundColor(textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func personaCardStatusText(_ generatedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return String(
            format: String(localized: "最終生成: %@", bundle: LanguageManager.appBundle),
            formatter.string(from: generatedAt)
        )
    }

    private func settingsRelationshipButton(_ type: PersonaRelationship) -> some View {
        let isSelected = settings.relationshipType == type
        return Button {
            settings.relationshipType = type
        } label: {
            HStack(spacing: 6) {
                Text(type.icon)
                    .font(.system(size: 14))
                Text(type.label)
                    .font(MeloFonts.zenMaruOrFallback(12))
                    .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MeloColors.Dark.accentGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MeloColors.Dark.card)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func speedRow(_ speed: ReplySpeed) -> some View {
        let isSelected = settings.replySpeed == speed
        return Button {
            settings.replySpeed = speed
        } label: {
            HStack(spacing: 12) {
                Text(speed.icon)
                    .font(.system(size: 20))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(speed.label)
                        .font(MeloFonts.zenMaruOrFallback(15))
                        .foregroundColor(textPrimary)
                    Text(speed.detail)
                        .font(MeloFonts.zenMaruOrFallback(11))
                        .foregroundColor(textMuted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(brandPink)
                } else {
                    Circle()
                        .stroke(brownStroke.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ReplySpeed Display Helpers

extension ReplySpeed {
    var icon: String {
        switch self {
        case .instant: return "⚡"
        case .fast: return "🐇"
        case .realtime: return "⏱"
        }
    }

    var label: String {
        switch self {
        case .instant: return String(localized: "即レス", bundle: LanguageManager.appBundle)
        case .fast: return String(localized: "早め", bundle: LanguageManager.appBundle)
        case .realtime: return String(localized: "リアル", bundle: LanguageManager.appBundle)
        }
    }

    var detail: String {
        switch self {
        case .instant: return String(localized: "すぐに返信が届きます", bundle: LanguageManager.appBundle)
        case .fast: return String(localized: "実際の半分くらいの速度で返信", bundle: LanguageManager.appBundle)
        case .realtime: return String(localized: "実際の返信速度・ばらつきをそのまま再現", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - PersonaRelationship Display Helpers

extension PersonaRelationship {
    var icon: String {
        switch self {
        case .lover: return "💑"
        case .crush: return "💘"
        case .mutual: return "💕"
        case .ex: return "💔"
        case .situational: return "🌙"
        case .friend: return "🤝"
        }
    }

    var label: String {
        switch self {
        case .lover: return String(localized: "恋人", bundle: LanguageManager.appBundle)
        case .crush: return String(localized: "片思い", bundle: LanguageManager.appBundle)
        case .mutual: return String(localized: "両思い", bundle: LanguageManager.appBundle)
        case .ex: return String(localized: "元カレ/元カノ", bundle: LanguageManager.appBundle)
        case .situational: return String(localized: "曖昧な関係", bundle: LanguageManager.appBundle)
        case .friend: return String(localized: "友達", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var path = Path()

        if isUser {
            // 右下の角がテールになる一体型バブル
            path.move(to: CGPoint(x: r, y: 0))
            // 上辺 → 右上角
            path.addLine(to: CGPoint(x: rect.width - r, y: 0))
            path.addArc(center: CGPoint(x: rect.width - r, y: r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            // 右辺を下へ → 右下角をテールに
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - 6))
            path.addCurve(
                to: CGPoint(x: rect.width - r, y: rect.height),
                control1: CGPoint(x: rect.width, y: rect.height),
                control2: CGPoint(x: rect.width, y: rect.height)
            )
            // 下辺 → 左下角
            path.addLine(to: CGPoint(x: r, y: rect.height))
            path.addArc(center: CGPoint(x: r, y: rect.height - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            // 左辺を上へ → 左上角
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addArc(center: CGPoint(x: r, y: r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // 左下の角がテールになる一体型バブル
            path.move(to: CGPoint(x: r, y: 0))
            // 上辺 → 右上角
            path.addLine(to: CGPoint(x: rect.width - r, y: 0))
            path.addArc(center: CGPoint(x: rect.width - r, y: r),
                        radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            // 右辺を下へ → 右下角
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
            path.addArc(center: CGPoint(x: rect.width - r, y: rect.height - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            // 下辺 → 左下角をテールに
            path.addLine(to: CGPoint(x: r, y: rect.height))
            path.addCurve(
                to: CGPoint(x: 0, y: rect.height - 6),
                control1: CGPoint(x: 0, y: rect.height),
                control2: CGPoint(x: 0, y: rect.height)
            )
            // 左辺を上へ → 左上角
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addArc(center: CGPoint(x: r, y: r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}
