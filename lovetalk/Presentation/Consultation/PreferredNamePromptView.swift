import SwiftUI

/// 相談機能を初めて開いた時に 1 回だけ表示する「呼び名入力ポップアップ」。
///
/// - 入力した名前は `Constants.StorageKeys.userPreferredName` に保存
/// - 「あとで」も選べる (空文字保存 = "あなた" 扱い)
/// - 設定からいつでも変更できる旨を明記
struct PreferredNamePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.StorageKeys.userPreferredName) private var userPreferredName: String = ""
    @State private var nameInput: String = ""
    @FocusState private var isFocused: Bool

    /// 保存 or スキップ完了時に呼ばれる。表示済みフラグの更新と次画面遷移は呼び出し側で行う。
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image("char_meromaru_3d")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text(String(localized: "なんて呼べばいい？", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(20))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .padding(.top, 8)

            Text(String(localized: "めろまるがあなたを呼ぶときの名前を教えてね 💕", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(13))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 6)

            TextField(
                String(localized: "例: あいまる", bundle: LanguageManager.appBundle),
                text: $nameInput
            )
            .font(MeloFonts.zenMaruMedium(16))
            .foregroundColor(MeloColors.Dark.textPrimary)
            .multilineTextAlignment(.center)
            .submitLabel(.done)
            .focused($isFocused)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MeloColors.Dark.bgElevated)
            )
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .onSubmit { saveAndClose() }

            Text(String(localized: "あとから設定画面でいつでも変更できるよ", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    HapticManager.medium()
                    saveAndClose()
                } label: {
                    Text(String(localized: "決定", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(15))
                        .foregroundColor(canSubmit ? MeloColors.Dark.onAccent : MeloColors.Dark.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSubmit ? AnyShapeStyle(MeloColors.Dark.accentGradient) : AnyShapeStyle(MeloColors.Dark.bgElevated))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)

                Button {
                    HapticManager.light()
                    skipWithoutSaving()
                } label: {
                    Text(String(localized: "あとで", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(13))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(MeloColors.Dark.bg.ignoresSafeArea())
        // スワイプで閉じてもよい。閉じても名前未入力なら次回開いた時に再表示される
        // (フラグの管理は呼び出し側 NewHomeView の onDismiss で行う)。
        .onAppear {
            nameInput = userPreferredName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    /// 入力が空白だけでなければ送信可。空白のみの場合は決定不可。
    private var canSubmit: Bool {
        !nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveAndClose() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userPreferredName = trimmed
        isFocused = false
        onComplete()
        dismiss()
    }

    private func skipWithoutSaving() {
        // 名前は保存しない。閉じるだけ。次回の相談タップでまた表示される。
        isFocused = false
        onComplete()
        dismiss()
    }
}
