import SwiftUI

// MARK: - Import Confirm Tokens (NewHomeView 準拠)
private enum ImportConfirmTokens {
    static let pageBg = Color.white
    static let headerBg = MeloColors.Surface.pinkPale
    static let softBg = MeloColors.Surface.pinkPale
    static let softBgAlt = MeloColors.Surface.pinkPale
    static let brandPink = MeloColors.Brand.pink
    static let filledPink = MeloColors.Brand.pink
    static let softPink = MeloColors.Brand.pinkLight
    static let textDark = MeloColors.Text.primary
    static let textGrey = MeloColors.Text.secondary
    static let brownBorder = MeloColors.Text.primary
}

// MARK: - Import Confirm View
struct ImportConfirmView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: ImportConfirmViewModel
    @State private var animateContent = false

    init(session: ChatSession) {
        _viewModel = StateObject(wrappedValue: ImportConfirmViewModel(session: session))
    }

    var body: some View {
        ZStack {
            // ページ背景: ほんのりピンクのグラデーション
            LinearGradient(
                colors: [
                    ImportConfirmTokens.pageBg,
                    ImportConfirmTokens.softBg,
                    ImportConfirmTokens.softBgAlt
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)

                        // 相手の情報カード
                        partnerInfoCard
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 30)

                        // 関係性選択カード（必須）
                        relationshipCard
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 35)

                        // トーク統計カード
                        statisticsCard
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 40)

                        // 開始ボタン
                        actionButtons
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateContent = true
            }
        }
    }

    // MARK: - Header Bar (NewHomeView 準拠)

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                HapticManager.light()
                coordinator.popToRoot()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(localized: "戻る", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(14))
                        .tracking(0.42)
                }
                .foregroundColor(ImportConfirmTokens.brandPink)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(String(localized: "トーク確認", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(18))
                .tracking(0.54)
                .foregroundColor(ImportConfirmTokens.textDark)

            Spacer()

            // 右端のスペーサー(左ボタンとのバランス用)
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 32)
        .padding(.top, 23)
        .padding(.bottom, 10)
        .background(Color.white)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 14) {
            // 成功アイコン (薄ピンク円 + ブランドピンクの枠)
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle()
                            .stroke(ImportConfirmTokens.brandPink, lineWidth: 1)
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(ImportConfirmTokens.filledPink)
            }

            VStack(spacing: 6) {
                Text(String(localized: "トーク履歴を読み込みました", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(20))
                    .tracking(0.6)
                    .foregroundColor(ImportConfirmTokens.textDark)
                    .multilineTextAlignment(.center)

                Text(String(localized: "内容を確認して分析を開始しましょう", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(13))
                    .tracking(0.3)
                    .foregroundColor(ImportConfirmTokens.textGrey)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var partnerInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションタイトル
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ImportConfirmTokens.brandPink)

                Text(String(localized: "あなたはどちらですか？", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(16))
                    .tracking(0.48)
                    .foregroundColor(ImportConfirmTokens.textDark)
            }

            // 参加者選択
            VStack(spacing: 10) {
                ForEach(viewModel.session.participants) { participant in
                    participantSelectionRow(participant: participant)
                }
            }

            // 選択結果の表示
            if !viewModel.partnerName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ImportConfirmTokens.brandPink)

                    if viewModel.isGroupChat {
                        Text(String(format: String(localized: "%@のグループトークを分析します", bundle: LanguageManager.appBundle), viewModel.partnerName))
                            .font(MeloFonts.zenMaruRegular(12))
                            .tracking(0.3)
                            .foregroundColor(ImportConfirmTokens.textGrey)
                    } else {
                        Text(String(format: String(localized: "%@さんとのトークを分析します", bundle: LanguageManager.appBundle), viewModel.partnerName))
                            .font(MeloFonts.zenMaruRegular(12))
                            .tracking(0.3)
                            .foregroundColor(ImportConfirmTokens.textGrey)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ImportConfirmTokens.brownBorder, lineWidth: 1)
                )
        )
    }

    private func participantSelectionRow(participant: ChatParticipant) -> some View {
        let isSelected = participant.name == viewModel.selectedSelfName

        return Button {
            HapticManager.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectSelf(participant.name)
            }
        } label: {
            HStack(spacing: 14) {
                // アイコン: 白地 + ブランドピンクの枠
                ZStack {
                    Circle()
                        .fill(isSelected ? ImportConfirmTokens.softBg : Color.white)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? ImportConfirmTokens.brandPink : ImportConfirmTokens.brownBorder.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: 46, height: 46)

                    Text(String(participant.name.prefix(1)))
                        .font(MeloFonts.zenMaru(20))
                        .tracking(0.6)
                        .foregroundColor(isSelected ? ImportConfirmTokens.brandPink : ImportConfirmTokens.textGrey)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.name)
                        .font(MeloFonts.zenMaru(16))
                        .tracking(0.48)
                        .foregroundColor(isSelected ? ImportConfirmTokens.textDark : ImportConfirmTokens.textGrey)

                    Text(String(format: String(localized: "%d件のメッセージ", bundle: LanguageManager.appBundle), participant.messageCount))
                        .font(MeloFonts.zenMaruRegular(11))
                        .tracking(0.3)
                        .foregroundColor(ImportConfirmTokens.textGrey)
                }

                Spacer()

                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? ImportConfirmTokens.brandPink : ImportConfirmTokens.brownBorder.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(ImportConfirmTokens.filledPink)
                            .frame(width: 13, height: 13)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? ImportConfirmTokens.softBg : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isSelected ? ImportConfirmTokens.brandPink : ImportConfirmTokens.brownBorder.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Relationship Card (必須選択)

    private var relationshipCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ImportConfirmTokens.brandPink)

                Text(String(localized: "相手との関係性は？", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(16))
                    .tracking(0.48)
                    .foregroundColor(ImportConfirmTokens.textDark)

                Text(String(localized: "必須", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruRegular(10))
                    .tracking(0.3)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(ImportConfirmTokens.filledPink)
                    )
            }

            Text(String(localized: "同じ言葉でも関係性によってヤバさの読み方が変わります。", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(11))
                .tracking(0.3)
                .foregroundColor(ImportConfirmTokens.textGrey)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(RelationshipContext.allCases.filter { $0 != .unknown }, id: \.self) { relationship in
                    relationshipChip(relationship)
                }
            }

            if let selected = viewModel.selectedRelationship {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ImportConfirmTokens.brandPink)

                    Text(String(format: String(localized: "%@として読み解きます", bundle: LanguageManager.appBundle), selected.displayName))
                        .font(MeloFonts.zenMaruRegular(12))
                        .tracking(0.3)
                        .foregroundColor(ImportConfirmTokens.textGrey)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ImportConfirmTokens.brownBorder, lineWidth: 1)
                )
        )
    }

    private func relationshipChip(_ relationship: RelationshipContext) -> some View {
        let isSelected = viewModel.selectedRelationship == relationship

        return Button {
            HapticManager.light()
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectRelationship(relationship)
            }
        } label: {
            HStack(spacing: 8) {
                Text(relationship.emoji)
                    .font(.system(size: 16))

                Text(relationship.displayName)
                    .font(MeloFonts.zenMaru(13))
                    .tracking(0.3)
                    .foregroundColor(isSelected ? .white : ImportConfirmTokens.textDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? ImportConfirmTokens.filledPink : ImportConfirmTokens.softBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                isSelected ? ImportConfirmTokens.filledPink : ImportConfirmTokens.brownBorder.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションタイトル
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ImportConfirmTokens.brandPink)

                Text(String(localized: "トーク情報", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaru(16))
                    .tracking(0.48)
                    .foregroundColor(ImportConfirmTokens.textDark)
            }

            // 統計グリッド
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statBox(
                    icon: "message.fill",
                    title: String(localized: "メッセージ数", bundle: LanguageManager.appBundle),
                    value: "\(viewModel.session.totalMessageCount)",
                    unit: String(localized: "件", bundle: LanguageManager.appBundle)
                )

                statBox(
                    icon: "calendar",
                    title: String(localized: "期間", bundle: LanguageManager.appBundle),
                    value: "\(viewModel.session.durationDays)",
                    unit: String(localized: "日", bundle: LanguageManager.appBundle)
                )

                if let partner = viewModel.partnerParticipant {
                    statBox(
                        icon: "person.fill",
                        title: viewModel.partnerName,
                        value: "\(partner.messageCount)",
                        unit: String(localized: "件", bundle: LanguageManager.appBundle)
                    )
                }

                if let selfP = viewModel.selfParticipant {
                    statBox(
                        icon: "person.fill",
                        title: String(localized: "あなた", bundle: LanguageManager.appBundle),
                        value: "\(selfP.messageCount)",
                        unit: String(localized: "件", bundle: LanguageManager.appBundle)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ImportConfirmTokens.brownBorder, lineWidth: 1)
                )
        )
    }

    private func statBox(icon: String, title: String, value: String, unit: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle()
                            .stroke(ImportConfirmTokens.brandPink, lineWidth: 1)
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ImportConfirmTokens.filledPink)
            }

            VStack(spacing: 2) {
                Text(value)
                    .font(MeloFonts.jerseyOrFallback(28))
                    .foregroundColor(ImportConfirmTokens.brandPink)

                Text(unit)
                    .font(MeloFonts.zenMaruRegular(10))
                    .tracking(0.24)
                    .foregroundColor(ImportConfirmTokens.textGrey)
            }

            Text(title)
                .font(MeloFonts.zenMaru(12))
                .tracking(0.3)
                .foregroundColor(ImportConfirmTokens.textDark)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ImportConfirmTokens.softBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(ImportConfirmTokens.brandPink.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // 解析開始ボタン (ピンクピル)。関係性未選択時は disabled。
            Button {
                guard let analysisSession = viewModel.sessionForAnalysis() else { return }
                HapticManager.medium()
                AnalyticsManager.shared.selfNameConfirmed(
                    isGroupChat: viewModel.isGroupChat,
                    partnerCount: max(0, viewModel.session.participants.count - 1)
                )
                coordinator.navigateToAnalyzing(
                    session: analysisSession,
                    selfName: viewModel.selfName
                )
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))

                    Text(viewModel.canStartAnalysis
                         ? String(localized: "分析を開始", bundle: LanguageManager.appBundle)
                         : String(localized: "関係性を選んでください", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(17))
                        .tracking(0.51)

                    if viewModel.canStartAnalysis {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(viewModel.canStartAnalysis
                              ? ImportConfirmTokens.filledPink
                              : ImportConfirmTokens.filledPink.opacity(0.35))
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStartAnalysis)

            // キャンセルボタン
            Button {
                HapticManager.light()
                coordinator.popToRoot()
            } label: {
                Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(14))
                    .tracking(0.42)
                    .foregroundColor(ImportConfirmTokens.textGrey)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ImportConfirmView(session: ChatSession(
            title: "テスト",
            messages: [],
            participants: [
                ChatParticipant(name: "田中さん", messageCount: 150, textMessageCount: 120, stickerCount: 20),
                ChatParticipant(name: "自分", messageCount: 100, textMessageCount: 80, stickerCount: 15)
            ]
        ))
    }
    .environmentObject(AppCoordinator())
}
