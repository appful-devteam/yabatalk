import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Board Compose View
// MARK: - Diagnosis Picker View

struct DiagnosisPickerView: View {
    let analysisHistory: [StoredAnalysisResult]
    @Binding var selectedCard: DiagnosisCard?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = BoardAuthService.shared
    @State private var expandedSessionId: UUID?
    @State private var selectedStyle: DiagnosisCard.CardStyle?
    @State private var selectedResult: StoredAnalysisResult?
    @State private var relationshipText: String = ""
    @State private var selectedPartnerMBTIs: Set<String> = []
    @FocusState private var isRelationshipFocused: Bool

    private let firestoreService = BoardFirestoreService.shared

    private let mbtiTypes = [
        "INTJ", "INTP", "ENTJ", "ENTP",
        "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ",
        "ISTP", "ISFP", "ESTP", "ESFP"
    ]

    private let relationshipSuggestions = [
        String(localized: "彼氏", bundle: LanguageManager.appBundle),
        String(localized: "彼女", bundle: LanguageManager.appBundle),
        String(localized: "片思い", bundle: LanguageManager.appBundle),
        String(localized: "好きな人", bundle: LanguageManager.appBundle),
        String(localized: "友達", bundle: LanguageManager.appBundle),
        String(localized: "推し", bundle: LanguageManager.appBundle),
    ]

    /// グループトークかどうか（3人以上）
    private var isGroupChat: Bool {
        guard let result = selectedResult else { return false }
        if let names = result.groupParticipantNames, names.count > 2 {
            return true
        }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // なし
                    Button {
                        HapticManager.light()
                        selectedCard = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text(String(localized: "添付しない", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruOrFallback(14))
                                .foregroundColor(BoardColors.textSecondary)
                            Spacer()
                            if selectedCard == nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(BoardColors.accent)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedCard == nil ? MeloColors.Surface.pinkPale : Color.white)
                                .shadow(color: BoardColors.accent.opacity(0.06), radius: 4, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(analysisHistory, id: \.id) { result in
                        let baseCard = makeBaseCard(from: result)
                        let isExpanded = expandedSessionId == result.sessionId

                        VStack(spacing: 0) {
                            // 診断結果カード — タップで展開
                            Button {
                                HapticManager.light()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if isExpanded {
                                        expandedSessionId = nil
                                        selectedResult = nil
                                        selectedStyle = nil
                                    } else {
                                        expandedSessionId = result.sessionId
                                        selectedResult = result
                                        selectedStyle = nil
                                        relationshipText = ""
                                        selectedPartnerMBTIs = []
                                    }
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    partnerAvatar(sessionId: result.sessionId, score: baseCard.totalScore, typeCode: baseCard.typeCode)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.partnerParticipant)
                                            .font(MeloFonts.zenMaruOrFallback(15))
                                            .foregroundColor(BoardColors.textPrimary)
                                            .lineLimit(1)

                                        HStack(spacing: 6) {
                                            Text("\(baseCard.totalScore)点")
                                                .font(MeloFonts.zenMaruMedium(11))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule().fill(MeloColors.typeGradient(for: baseCard.typeCode))
                                                )
                                            Text(baseCard.typeName)
                                                .font(MeloFonts.zenMaruRegular(12))
                                                .foregroundColor(BoardColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(BoardColors.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // カードスタイル選択 + 関係性入力
                            if isExpanded {
                                VStack(spacing: 8) {
                                    // カードスタイル選択
                                    ForEach(availableStyles(for: result), id: \.self) { style in
                                        let isSelected = selectedStyle == style

                                        Button {
                                            HapticManager.light()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedStyle = style
                                            }
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: style.icon)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(BoardColors.accent)
                                                    .frame(width: 28, height: 28)
                                                    .background(
                                                        Circle()
                                                            .fill(MeloColors.Surface.pinkPale)
                                                    )

                                                Text(style.localizedName)
                                                    .font(MeloFonts.zenMaruOrFallback(13))
                                                    .foregroundColor(BoardColors.textPrimary)

                                                Spacer()

                                                if isSelected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(BoardColors.accent)
                                                } else {
                                                    Circle()
                                                        .stroke(MeloColors.Gray.subButton, lineWidth: 1.5)
                                                        .frame(width: 16, height: 16)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(isSelected ? MeloColors.Surface.pinkPale : MeloColors.Gray.subButtonLight)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // 関係性入力（スタイル選択後に表示）
                                    if selectedStyle != nil {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Divider()

                                            Text(String(localized: "相手との関係性", bundle: LanguageManager.appBundle))
                                                .font(MeloFonts.zenMaruOrFallback(12))
                                                .foregroundColor(BoardColors.textSecondary)

                                            // サジェスト
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 6) {
                                                    ForEach(relationshipSuggestions, id: \.self) { label in
                                                        Button {
                                                            HapticManager.light()
                                                            relationshipText = label
                                                        } label: {
                                                            Text(label)
                                                                .font(MeloFonts.zenMaruOrFallback(12))
                                                                .foregroundColor(relationshipText == label ? .white : BoardColors.textSecondary)
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 6)
                                                                .background(
                                                                    Capsule()
                                                                        .fill(relationshipText == label
                                                                            ? AnyShapeStyle(LinearGradient(colors: [MeloColors.Brand.pinkDeep, MeloColors.Brand.pinkLight], startPoint: .leading, endPoint: .trailing))
                                                                            : AnyShapeStyle(MeloColors.Gray.subButtonLight))
                                                                )
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                            }

                                            // テキスト入力
                                            TextField(
                                                String(localized: "自由入力（例: 元カレ、マッチングアプリ）", bundle: LanguageManager.appBundle),
                                                text: $relationshipText
                                            )
                                            .font(MeloFonts.zenMaruOrFallback(13))
                                            .textFieldStyle(.plain)
                                            .padding(10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(MeloColors.Gray.subButtonLight)
                                            )
                                            .focused($isRelationshipFocused)

                                            // 相手のMBTI
                                            HStack {
                                                Text(String(localized: isGroupChat ? "メンバーのMBTI（複数選択可）" : "相手のMBTI", bundle: LanguageManager.appBundle))
                                                    .font(MeloFonts.zenMaruOrFallback(12))
                                                    .foregroundColor(BoardColors.textSecondary)
                                                Spacer()
                                            }
                                            .padding(.top, 4)

                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                                                ForEach(mbtiTypes, id: \.self) { mbti in
                                                    let isSelected = selectedPartnerMBTIs.contains(mbti)
                                                    Button {
                                                        HapticManager.light()
                                                        if isGroupChat {
                                                            // グループトーク: 複数選択
                                                            if isSelected {
                                                                selectedPartnerMBTIs.remove(mbti)
                                                            } else {
                                                                selectedPartnerMBTIs.insert(mbti)
                                                            }
                                                        } else {
                                                            // 1対1: 単一選択
                                                            if isSelected {
                                                                selectedPartnerMBTIs.removeAll()
                                                            } else {
                                                                selectedPartnerMBTIs = [mbti]
                                                            }
                                                        }
                                                    } label: {
                                                        Text(mbti)
                                                            .font(MeloFonts.zenMaruOrFallback(11))
                                                            .foregroundColor(isSelected ? .white : BoardColors.textSecondary)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 7)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 8)
                                                                    .fill(isSelected
                                                                        ? AnyShapeStyle(MeloColors.mbtiColor(for: mbti))
                                                                        : AnyShapeStyle(MeloColors.Gray.subButtonLight))
                                                            )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }

                                            // 添付ボタン
                                            Button {
                                                HapticManager.medium()
                                                if let result = selectedResult, let style = selectedStyle {
                                                    Task {
                                                        var card = makeCard(from: result, style: style)
                                                        let trimmed = relationshipText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                        card.relationshipLabel = trimmed.isEmpty ? nil : trimmed
                                                        // 自分のMBTIはプロフィールのバッジから自動取得
                                                        if let userId = authService.currentUser?.id {
                                                            let badge = try? await firestoreService.loadUserBadge(userId: userId)
                                                            card.selfMBTI = badge?.typeCode
                                                        }
                                                        let sortedMBTIs = Array(selectedPartnerMBTIs).sorted()
                                                        card.partnerMBTI = sortedMBTIs.first
                                                        card.partnerMBTIs = sortedMBTIs.isEmpty ? nil : sortedMBTIs
                                                        selectedCard = card
                                                        dismiss()
                                                    }
                                                }
                                            } label: {
                                                Text(String(localized: "このカードを添付", bundle: LanguageManager.appBundle))
                                                    .font(MeloFonts.zenMaruOrFallback(14))
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(
                                                                LinearGradient(
                                                                    colors: [MeloColors.Brand.pinkDeep, MeloColors.Brand.pinkLight],
                                                                    startPoint: .leading,
                                                                    endPoint: .trailing
                                                                )
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(color: BoardColors.accent.opacity(0.06), radius: 4, x: 0, y: 2)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle(String(localized: "診断結果を添付", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Partner Avatar

    /// 相手のプロフィールアイコン。チャットで設定したカスタム画像があればそれ、
    /// なければ session ごとに固定された consult_partner_meromaru_XX を表示。
    @ViewBuilder
    private func partnerAvatar(sessionId: UUID?, score: Int, typeCode: String) -> some View {
        let customImageData = ConsultationPartnerAvatarStore.customImageData(for: sessionId)
        let avatarName = ConsultationPartnerAvatarStore.avatarName(for: sessionId) ?? "char_meromaru_3d"

        ZStack {
            Circle()
                .fill(MeloColors.Surface.pinkPale)
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
        .frame(width: 52, height: 52)
        .overlay(
            Circle()
                .stroke(MeloColors.Brand.pink.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Available Styles

    private func availableStyles(for result: StoredAnalysisResult) -> [DiagnosisCard.CardStyle] {
        var styles: [DiagnosisCard.CardStyle] = [.score, .type]
        if let stats = result.detailedStatistics,
           (stats.loveWordsAnalysis.selfTotalCount + stats.loveWordsAnalysis.partnerTotalCount) > 0 {
            styles.append(.loveWords)
        }
        return styles
    }

    // MARK: - Card Builders

    private func makeBaseCard(from result: StoredAnalysisResult) -> DiagnosisCard {
        makeCard(from: result, style: .score)
    }

    private func makeCard(from result: StoredAnalysisResult, style: DiagnosisCard.CardStyle) -> DiagnosisCard {
        let axisScore = AxisScore(
            balanceScore: result.balanceScore,
            balanceRawValues: result.balanceRawValues ?? BalanceRawValues(textSendRatio: 0.5, blockInitiationRatio: 0.5, chaseMessageDifference: 0, selfMessageCount: 0, partnerMessageCount: 0),
            tensionScore: result.tensionScore,
            tensionRawValues: result.tensionRawValues ?? TensionRawValues(stickerRate: 0, laughRate: 0, emojiRate: 0, exclamationRate: 0, mediaRate: 0, stickerCount: 0, laughCount: 0, emojiCount: 0, exclamationCount: 0, mediaCount: 0),
            responseScore: result.responseScore,
            responseRawValues: result.responseRawValues ?? ResponseRawValues(selfReplyMedian: 300, partnerReplyMedian: 300, replySpeedDifference: 0, selfReplyCount: 0, partnerReplyCount: 0),
            wordScore: result.wordScore,
            wordRawValues: result.wordRawValues ?? WordRawValues(lovePhraseRate: 0, gratitudeRate: 0, careRate: 0, greetingRate: 0, encouragementRate: 0, affirmationRate: 0, missingRate: 0, futureRate: 0, totalWordHits: 0, totalTextMessages: 0),
            confidence: result.confidence
        )

        let type = RelationshipType.from(axisScore: axisScore)
        let totalRaw = (result.balanceScore + result.tensionScore + result.responseScore + result.wordScore) / 4.0
        let scaled = Int(max(0, min(100, (totalRaw - 28.0) / 54.0 * 100.0)))

        var card = DiagnosisCard(
            typeCode: type.rawValue,
            typeName: type.displayName,
            totalScore: scaled,
            balanceScore: result.balanceScore,
            tensionScore: result.tensionScore,
            responseScore: result.responseScore,
            wordScore: result.wordScore
        )

        card.cardStyle = style

        switch style {
        case .score:
            break
        case .type:
            card.typeTagline = type.tagline
            card.typeDescription = type.description
            card.typeImageName = type.imageName
        case .loveWords:
            if let stats = result.detailedStatistics {
                let lwa = stats.loveWordsAnalysis
                card.selfLoveWords = lwa.selfLoveWords.prefix(5).map { SharedPhraseCount(phrase: $0.phrase, count: $0.count) }
                card.partnerLoveWords = lwa.partnerLoveWords.prefix(5).map { SharedPhraseCount(phrase: $0.phrase, count: $0.count) }
                card.selfLoveTotal = lwa.selfTotalCount
                card.partnerLoveTotal = lwa.partnerTotalCount
            }
        }

        return card
    }
}
