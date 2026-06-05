import SwiftUI

// MARK: - ConsultationChatView
/// 診断タブの「めろまるに相談」ボタンから選ばれた相手について相談するチャット画面。
/// ReplySuggestionViewModel を再利用し、NewHomeView の新デザイン (Zen Maru / 白カード / ピンクアクセント) に統一。
struct ConsultationChatView: View {
    @ObservedObject var viewModel: ReplySuggestionViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @State private var showHelpOverlay = false
    @State private var showLimitReachedSheet = false
    @State private var showSubscription = false
    @State private var showPartnerAvatarPicker = false
    @State private var partnerAvatarName: String?
    @State private var composerHeight: CGFloat = 68
    @StateObject private var keyboard = KeyboardState()
    @FocusState private var isInputFocused: Bool

    // MARK: - Design Tokens
    private let brandPink = MeloColors.Brand.pink
    private let textDark = MeloColors.Text.primary
    private let textMuted = MeloColors.Text.secondary
    private let textGrey = MeloColors.Text.secondary
    private let brown = MeloColors.Text.primary
    private let divider = MeloColors.Gray.subButtonLight

    init(
        session: ChatSession?,
        selfName: String,
        partnerName: String,
        analysisResult: AnalysisResult?,
        resultId: UUID?
    ) {
        viewModel = ReplySuggestionViewModel(
            session: session,
            selfName: selfName,
            partnerName: partnerName,
            analysisResult: analysisResult,
            resultId: resultId
        )
    }

    init(viewModel: ReplySuggestionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GeometryReader { geometry in
            let keyboardOffset = max(0, keyboard.height - geometry.safeAreaInsets.bottom)

            ZStack(alignment: .bottom) {
                background

                contentStack(bottomInset: composerHeight + keyboardOffset + 12)

                composerBar
                    .measureHeight($composerHeight)
                    .offset(y: -keyboardOffset)
                    .zIndex(1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(keyboard.animation, value: keyboardOffset)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task(id: viewModel.consultationPartnerSessionId) {
            refreshPartnerAvatar()
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.isLimitReached) { _, reached in
            if reached {
                showLimitReachedSheet = true
            }
        }
        .sheet(isPresented: $showSubscription, onDismiss: {
            viewModel.retryAfterUpgradeIfNeeded()
        }) {
            SubscriptionView(source: "consultation_diagnose")
        }
        .overlay {
            if showLimitReachedSheet {
                limitPopup
            }
        }
        .overlay {
            if showHelpOverlay {
                helpPopup
            }
        }
        .sheet(isPresented: $showPartnerAvatarPicker) {
            partnerAvatarPickerSheet
        }
        .sheet(isPresented: $viewModel.showSidebar) {
            consultationHistorySheet
        }
        .sheet(isPresented: $viewModel.showToneSettings) {
            consultationSettingsSheet
        }
    }

    private var background: some View {
        ZStack {
            MeloColors.Surface.pinkPale
            Image("bg_diagnose_stardust")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.3)
        }
        .ignoresSafeArea()
    }

    private func contentStack(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            partnerProfileBar
            chatArea(bottomInset: bottomInset)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header (透過背景 + ピンクグラデアイコンボタン)
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // Back button
            headerCircleButton(systemName: "chevron.left", action: {
                HapticManager.light()
                dismiss()
            })
            .accessibilityLabel(Text(String(localized: "戻る", bundle: LanguageManager.appBundle)))

            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "めろまるに相談", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(20))
                    .tracking(0.6)
                    .foregroundColor(MeloColors.Text.primary)
                    .lineLimit(1)
                if let remaining = viewModel.remainingRalliesText {
                    Text(String(format: String(localized: "今日の残り: %@", bundle: LanguageManager.appBundle), remaining))
                        .font(MeloFonts.zenMaruRegular(10))
                        .foregroundColor(textGrey)
                }
            }

            Spacer()

            // 履歴ボタン
            headerCircleButton(systemName: "clock.arrow.circlepath", action: {
                HapticManager.light()
                viewModel.toggleSidebar()
            })
            .accessibilityLabel(Text(String(localized: "履歴", bundle: LanguageManager.appBundle)))

            // 設定ボタン (口調・文字数)
            headerCircleButton(systemName: "gearshape", action: {
                HapticManager.light()
                viewModel.showToneSettings = true
            })
            .accessibilityLabel(Text(String(localized: "設定", bundle: LanguageManager.appBundle)))

            // メニュー: 新しい相談 / 使い方
            Menu {
                Button {
                    HapticManager.light()
                    viewModel.startNewSession()
                } label: {
                    Label(
                        String(localized: "新しい相談", bundle: LanguageManager.appBundle),
                        systemImage: "square.and.pencil"
                    )
                }
                Button {
                    HapticManager.light()
                    withAnimation(.easeOut(duration: 0.2)) {
                        showHelpOverlay = true
                    }
                } label: {
                    Label(
                        String(localized: "使い方", bundle: LanguageManager.appBundle),
                        systemImage: "questionmark"
                    )
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Gradient.pinkPrimary)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
                .shadow(color: MeloColors.Brand.pink.opacity(0.45), radius: 6, x: 0, y: 2)
            }
            .accessibilityLabel(Text(String(localized: "メニュー", bundle: LanguageManager.appBundle)))
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var partnerProfileBar: some View {
        Group {
            if let partnerName = viewModel.consultationPartnerDisplayName {
                Button {
                    HapticManager.light()
                    showPartnerAvatarPicker = true
                } label: {
                    HStack(spacing: 12) {
                        partnerProfileAvatar(name: partnerAvatarName ?? "char_meromaru_3d", size: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "相談している相手", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruRegular(10))
                                .foregroundColor(textGrey)
                            Text(partnerName)
                                .font(MeloFonts.zenMaruMedium(15))
                                .foregroundColor(textDark)
                                .lineLimit(1)
                        }

                        Spacer()

                        Label(
                            String(localized: "画像を変更", bundle: LanguageManager.appBundle),
                            systemImage: "photo"
                        )
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(brandPink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(brandPink.opacity(0.28), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
            }
        }
    }

    /// ピンクグラデ円 + 白アイコン (診断ページの設定ボタンと同スタイル)
    private func headerCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(MeloColors.Gradient.pinkPrimary)
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)
            .shadow(color: MeloColors.Brand.pink.opacity(0.45), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat Area
    private func chatArea(bottomInset: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.entries) { entry in
                        messageRow(entry: entry)
                            .id(entry.id)
                    }

                    if viewModel.isLoading {
                        typingIndicator
                            .id("typing_indicator")
                    }

                    // Quick options (関係性・問題カテゴリー選択)
                    if !viewModel.currentQuickOptions.isEmpty, !viewModel.isLoading {
                        quickOptionsRow(viewModel.currentQuickOptions)
                            .id("quick_options")
                    }

                    Color.clear
                        .frame(height: bottomInset)
                        .id("bottom_anchor")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                // 余白タップでキーボードを閉じる(LazyVStack 全体をタップ領域にする)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }
            }
            // スワイプダウンでもキーボードを閉じられるように
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.entries.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: keyboard.height) { _, height in
                if height > 0 {
                    scrollToBottom(proxy: proxy)
                }
            }
            // キーボード起動時に末尾までスクロールして入力欄が隠れないようにする
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        withAnimation(animated ? .easeOut(duration: 0.25) : nil) {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
        }
    }

    // MARK: - Message Row
    @ViewBuilder
    private func messageRow(entry: ReplyChatEntry) -> some View {
        if entry.role == .user {
            HStack(alignment: .bottom, spacing: 6) {
                Spacer(minLength: 0)
                Text(entry.text)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(MeloColors.Gradient.pinkPrimary)
                    )
                    // 内容に応じて自然なサイズで折り返し、最大は画面の 75%
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                avatarImage
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(brandPink.opacity(0.6), lineWidth: 1))

                Text(entry.text)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(textDark)
                    .lineSpacing(4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(brandPink.opacity(0.5), lineWidth: 1)
                            )
                    )
                    // 自然なサイズで折り返し、最大は画面の 70%
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Avatar (最新 3D めろまる)
    private var avatarImage: some View {
        Image("char_meromaru_3d")
            .resizable()
            .scaledToFit()
            .padding(2)
    }

    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            avatarImage
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(brandPink.opacity(0.6), lineWidth: 1))

            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(brandPink.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseScale(for: index))
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(brown, lineWidth: 1)
                    )
            )

            Spacer(minLength: 40)
        }
    }

    private func pulseScale(for index: Int) -> CGFloat {
        viewModel.isLoading ? 1.2 : 0.8
    }

    private var partnerAvatarPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let partnerName = viewModel.consultationPartnerDisplayName {
                        Text(String(format: String(localized: "%@のプロフィール画像を選んでね", bundle: LanguageManager.appBundle), partnerName))
                            .font(MeloFonts.zenMaruMedium(15))
                            .foregroundColor(textDark)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    Button {
                        HapticManager.light()
                        let nextAvatar = ConsultationPartnerAvatarStore.randomAvatarName(excluding: partnerAvatarName)
                        updatePartnerAvatar(to: nextAvatar)
                    } label: {
                        Label(String(localized: "ランダムに変更", bundle: LanguageManager.appBundle), systemImage: "shuffle")
                            .font(MeloFonts.zenMaruMedium(13))
                            .foregroundColor(brandPink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(MeloColors.Surface.pinkPale)
                                    .overlay(
                                        Capsule()
                                            .stroke(brandPink.opacity(0.35), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                        spacing: 12
                    ) {
                        ForEach(ConsultationPartnerAvatarStore.availableAvatarNames, id: \.self) { avatarName in
                            Button {
                                HapticManager.light()
                                updatePartnerAvatar(to: avatarName)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    partnerProfileAvatar(name: avatarName, size: 72)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .stroke(
                                                            avatarName == partnerAvatarName ? brandPink : brandPink.opacity(0.16),
                                                            lineWidth: avatarName == partnerAvatarName ? 2 : 1
                                                        )
                                                )
                                        )

                                    if avatarName == partnerAvatarName {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(brandPink)
                                            .padding(6)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .background(MeloColors.Surface.pinkPale.ignoresSafeArea())
            .navigationTitle(String(localized: "相手の画像", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる", bundle: LanguageManager.appBundle)) {
                        showPartnerAvatarPicker = false
                    }
                    .font(MeloFonts.zenMaruRegular(13))
                    .foregroundColor(brandPink)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Quick Options
    private func quickOptionsRow(_ options: [QuickOption]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // インデント揃え (アバター幅 + 余白)
            Spacer().frame(height: 0)

            // Flow layout 的なチップ
            WrapHStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        HapticManager.light()
                        viewModel.selectQuickOption(option)
                    } label: {
                        Text(option.label)
                            .font(MeloFonts.zenMaruMedium(13))
                            .foregroundColor(brandPink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .overlay(
                                        Capsule()
                                            .stroke(brandPink, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 44) // アバター分だけインデント
        }
    }

    // MARK: - Composer
    private var composerBar: some View {
        // 内側: 入力欄と送信ボタン (左右 24pt の安全余白に収める)
        HStack(alignment: .center, spacing: 10) {
            TextField(
                String(localized: "メッセージを入力…", bundle: LanguageManager.appBundle),
                text: $viewModel.inputText,
                axis: .vertical
            )
            .font(MeloFonts.zenMaruMedium(14))
            .foregroundColor(textDark)
            .focused($isInputFocused)
            .lineLimit(1...4)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(
                        Capsule()
                            .stroke(brandPink, lineWidth: 1)
                    )
            )

            Button {
                HapticManager.medium()
                isInputFocused = false
                Task { await viewModel.sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Gradient.pinkPrimary)
                        .frame(width: 40, height: 40)
                        .opacity(viewModel.canSend ? 1.0 : 0.4)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(45))
                        .offset(x: -1, y: 1)
                }
                .shadow(color: MeloColors.Brand.pink.opacity(viewModel.canSend ? 0.45 : 0), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
            .accessibilityLabel(Text(String(localized: "送信", bundle: LanguageManager.appBundle)))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        // 背景は edge-to-edge の白 + 上に1本の細い区切り線。
        // キーボード追従は body 側の offset に集約し、ここはバー単体の見た目だけを持つ。
        .background(
            Color.white
                .overlay(Rectangle().fill(divider).frame(height: 0.5), alignment: .top)
        )
    }

    // MARK: - History Sheet (過去の相談セッション一覧)

    private var consultationHistorySheet: some View {
        NavigationView {
            Group {
                if viewModel.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image("char_meromaru_3d")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        Text(String(localized: "まだ相談履歴がありません", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(textGrey)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MeloColors.Surface.pinkPale.ignoresSafeArea())
                } else {
                    List {
                        ForEach(viewModel.sessions) { session in
                            Button {
                                HapticManager.light()
                                viewModel.viewSession(session.id)
                            } label: {
                                historySessionRow(session)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteSession(session.id)
                                } label: {
                                    Label(
                                        String(localized: "削除", bundle: LanguageManager.appBundle),
                                        systemImage: "trash"
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(MeloColors.Surface.pinkPale.ignoresSafeArea())
                }
            }
            .navigationTitle(String(localized: "相談履歴", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showSidebar = false
                    } label: {
                        Text(String(localized: "閉じる", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(MeloColors.Brand.pink)
                    }
                }
            }
        }
    }

    private func historySessionRow(_ session: ReplySession) -> some View {
        // 最初のユーザー発言をプレビューに使う(無ければプレースホルダ)。
        let firstUserText = session.entries.first(where: { $0.role == .user })?.text
            ?? String(localized: "(まだメッセージなし)", bundle: LanguageManager.appBundle)
        return VStack(alignment: .leading, spacing: 6) {
            Text(firstUserText)
                .font(MeloFonts.zenMaruMedium(14))
                .foregroundColor(textDark)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 8) {
                Text(historyTimestamp(session))
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(textGrey)
                Spacer()
                Text(String(format: String(localized: "%d往復", bundle: LanguageManager.appBundle), session.entries.filter { $0.role == .user }.count))
                    .font(MeloFonts.zenMaruRegular(11))
                    .foregroundColor(textGrey)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(brandPink.opacity(0.25), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }

    private func historyTimestamp(_ session: ReplySession) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: session.createdAt)
    }

    // MARK: - Settings Sheet (口調 / 文字数)

    private var consultationSettingsSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 口調
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "口調", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(textDark)
                        ForEach(ConsultationTone.allCases, id: \.self) { tone in
                            settingsToneRow(tone)
                        }
                    }

                    Divider()

                    // 文字数
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "返答の長さ", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(textDark)
                        ForEach(ConsultationLength.allCases, id: \.self) { length in
                            settingsLengthRow(length)
                        }
                    }
                }
                .padding(20)
            }
            .background(MeloColors.Surface.pinkPale.ignoresSafeArea())
            .navigationTitle(String(localized: "相談の設定", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showToneSettings = false
                    } label: {
                        Text(String(localized: "完了", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(14))
                            .foregroundColor(MeloColors.Brand.pink)
                    }
                }
            }
        }
    }

    private func settingsToneRow(_ tone: ConsultationTone) -> some View {
        let isSelected = viewModel.consultationContext.tone == tone
        return Button {
            HapticManager.light()
            viewModel.consultationContext.tone = tone
        } label: {
            HStack {
                Text(tone.displayName)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(textDark)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(brandPink)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? brandPink : brandPink.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func settingsLengthRow(_ length: ConsultationLength) -> some View {
        let isSelected = viewModel.consultationContext.length == length
        return Button {
            HapticManager.light()
            viewModel.consultationContext.length = length
        } label: {
            HStack {
                Text(length.displayName)
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(textDark)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(brandPink)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? brandPink : brandPink.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Limit Reached Popup
    private var limitPopup: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showLimitReachedSheet = false
                    }
                }

            ConsultationLimitReachedView(
                tier: viewModel.currentTier,
                reason: viewModel.limitReachedReason,
                onUpgrade: {
                    showLimitReachedSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showSubscription = true
                    }
                },
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showLimitReachedSheet = false
                    }
                }
            )
            .padding(.horizontal, 24)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLimitReachedSheet)
    }

    // MARK: - Help Popup (シンプル版)
    private var helpPopup: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showHelpOverlay = false
                    }
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    Image("char_meromaru_3d")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                    Text(String(localized: "めろまる相談の使い方", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaru(16))
                        .foregroundColor(textDark)
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showHelpOverlay = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(textMuted)
                    }
                    .buttonStyle(.plain)
                }

                helpBullet(String(localized: "関係と悩みのジャンルを選ぶとスムーズに相談できるよ", bundle: LanguageManager.appBundle))
                helpBullet(String(localized: "めろまるはあなたの診断結果から相手のことを覚えてるよ", bundle: LanguageManager.appBundle))
                helpBullet(String(localized: "左上の戻るボタンで診断タブに戻れるよ", bundle: LanguageManager.appBundle))
                helpBullet(String(localized: "右上の鉛筆ボタンで新しい相談を始められるよ", bundle: LanguageManager.appBundle))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(brandPink.opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 28)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showHelpOverlay)
    }

    private func helpBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(brandPink)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            Text(text)
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(textDark)
                .lineSpacing(4)
        }
    }

    private func refreshPartnerAvatar() {
        partnerAvatarName = ConsultationPartnerAvatarStore.avatarName(for: viewModel.consultationPartnerSessionId)
    }

    private func updatePartnerAvatar(to avatarName: String) {
        ConsultationPartnerAvatarStore.setAvatarName(avatarName, for: viewModel.consultationPartnerSessionId)
        partnerAvatarName = avatarName
    }

    private func partnerProfileAvatar(name: String, size: CGFloat) -> some View {
        let customImageData = ConsultationPartnerAvatarStore.customImageData(for: viewModel.consultationPartnerSessionId)
        return ZStack {
            Circle()
                .fill(Color.white)

            if let data = customImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(brandPink.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Keyboard / Layout Helpers
private final class KeyboardState: ObservableObject {
    @Published var height: CGFloat = 0
    @Published var animation: Animation = .easeOut(duration: 0.25)

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardNotification),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardNotification),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleKeyboardNotification(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let isHiding = notification.name == UIResponder.keyboardWillHideNotification

        animation = .easeOut(duration: duration)
        height = isHiding ? 0 : max(0, endFrame.height)
    }
}

private struct ViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ViewHeightPreferenceKey.self) { newHeight in
            if newHeight > 0, abs(height.wrappedValue - newHeight) > 0.5 {
                height.wrappedValue = newHeight
            }
        }
    }
}

// MARK: - WrapHStack (簡易版 FlowLayout)
fileprivate struct WrapHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
