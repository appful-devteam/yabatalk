import SwiftUI
import SwiftData

// MARK: - ConsultationPartnerPickerView
/// 「めろまるに相談」ボタンから開かれる相手選択画面。
/// 診断履歴 (StoredAnalysisResult) から 1 セッション 1 行で選択し、
/// 選ばれた相手の AnalysisResult / ChatSession を用いて ConsultationChatView に遷移する。
struct ConsultationPartnerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StoredAnalysisResult.analyzedAt, order: .reverse)
    private var analysisHistory: [StoredAnalysisResult]

    /// 選択時に親へ通知。親は dismiss 後に ConsultationChatView を表示する。
    let onSelect: (StoredAnalysisResult) -> Void
    /// 「相手を特定せずにとりあえず話す」を選択した際のコールバック。
    /// 履歴がない初回ユーザーや、特定の相手について話す気分でない場合に使用。
    var onSelectGeneral: (() -> Void)? = nil

    // MARK: - Design Tokens (NewHomeView に合わせる)
    private let pageBg = Color.white
    private let brandPink = MeloColors.Brand.pink
    private let filledPink = MeloColors.Brand.pink
    private let softPinkBg = MeloColors.Surface.pinkPale
    private let textDark = MeloColors.Text.primary
    private let textGrey = MeloColors.Text.secondary
    private let brown = MeloColors.Text.secondary  // カード枠の濃いグレー (旧716463から変更)
    private let divider = MeloColors.Gray.subButtonLight

    var body: some View {
        ZStack {
            // 診断ページと共通のピンクスターダスト背景
            ZStack {
                MeloColors.Surface.pinkPale
                Image("bg_diagnose_stardust")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.3)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if entries.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // 相手を特定せずに話すオプション (常に先頭に表示)
                            generalCard
                                .padding(.top, 12)

                            ForEach(entries) { entry in
                                partnerCard(entry: entry)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header (透過背景 + 戻る + タイトル)
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                HapticManager.light()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(MeloColors.Gradient.pinkPrimary)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32)
                .shadow(color: MeloColors.Brand.pink.opacity(0.45), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "閉じる", bundle: LanguageManager.appBundle)))

            Text(String(localized: "誰のことで相談する？", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(20))
                .tracking(0.6)
                .foregroundColor(MeloColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Hint Card (3D めろまる)
    private var hintCard: some View {
        HStack(spacing: 12) {
            Image("char_meromaru_3d")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)

            Text(String(localized: "相談したい相手を選んでね\nめろまるが相手のことを覚えてるよ！", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruMedium(12))
                .foregroundColor(textDark)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: MeloColors.Brand.pinkLight.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    // MARK: - Partner Card
    private func partnerCard(entry: PickerEntry) -> some View {
        Button {
            HapticManager.light()
            onSelect(entry.result)
        } label: {
            HStack(spacing: 12) {
                partnerAvatar(for: entry.result.sessionId)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                        .font(MeloFonts.zenMaruMedium(16))
                        .foregroundColor(textDark)
                        .lineLimit(1)
                    Text(formatDate(entry.result.analyzedAt))
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(textGrey)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(brandPink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func partnerAvatar(for sessionId: UUID) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)

            if let avatarName = ConsultationPartnerAvatarStore.avatarName(for: sessionId) {
                Image(avatarName)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Image("char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            }
        }
        .frame(width: 44, height: 44)
        .overlay(
            Circle()
                .stroke(brandPink.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - General Card (相手を特定せずに話す) — 3D めろまるアバター
    private var generalCard: some View {
        Button {
            HapticManager.light()
            onSelectGeneral?()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(softPinkBg)
                        .frame(width: 44, height: 44)
                    Image("char_meromaru_3d")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "とりあえず話す", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(16))
                        .foregroundColor(textDark)
                        .lineLimit(1)
                    Text(String(localized: "相手を特定せずにめろまるとお話しよう", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(11))
                        .foregroundColor(textGrey)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(brandPink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("mero_pair_02")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
            Text(String(localized: "まだ診断履歴がありません", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaru(14))
                .foregroundColor(textDark)
            Text(String(localized: "まずはLINE相性診断から始めよう", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(12))
                .foregroundColor(textDark)

            // 履歴がなくても「とりあえず話す」は使えるようにする
            generalCard
                .padding(.top, 12)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Entries (sessionId ごとに最新1件)
    private struct PickerEntry: Identifiable {
        let id: UUID
        let result: StoredAnalysisResult
        let displayName: String
    }

    private var entries: [PickerEntry] {
        var sessionMap: [UUID: StoredAnalysisResult] = [:]
        for r in analysisHistory {
            if let existing = sessionMap[r.sessionId] {
                if r.period == "all" && existing.period != "all" {
                    sessionMap[r.sessionId] = r
                } else if r.period == "all" && existing.period == "all" && r.analyzedAt > existing.analyzedAt {
                    sessionMap[r.sessionId] = r
                } else if existing.period != "all" && r.analyzedAt > existing.analyzedAt {
                    sessionMap[r.sessionId] = r
                }
            } else {
                sessionMap[r.sessionId] = r
            }
        }

        return sessionMap.values
            .sorted { $0.analyzedAt > $1.analyzedAt }
            .map { result in
                let isGroup = (result.groupParticipantNames?.count ?? 0) > 2
                let name: String
                if isGroup, let title = result.session?.title, !title.isEmpty {
                    name = title
                } else {
                    name = result.partnerParticipant
                }
                return PickerEntry(
                    id: result.id,
                    result: result,
                    displayName: name
                )
            }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.appLocale
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
}
