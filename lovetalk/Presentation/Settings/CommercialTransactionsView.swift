import SwiftUI

// MARK: - Commercial Transactions View
/// 特定商取引法に基づく表記
struct CommercialTransactionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MeloGradientBackground(style: .subtle)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 最終更新日
                        Text(String(localized: "最終更新日: 2026年5月18日", bundle: LanguageManager.appBundle))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(MeloColors.Text.secondary)

                        // イントロ
                        Text(String(localized: "本ページは、特定商取引に関する法律第11条に基づく表記です。", bundle: LanguageManager.appBundle))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(MeloColors.Text.secondary)
                            .lineSpacing(6)

                        section(
                            title: String(localized: "販売事業者", bundle: LanguageManager.appBundle),
                            content: String(localized: "株式会社appful", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "代表責任者", bundle: LanguageManager.appBundle),
                            content: "Ryusei Okamoto"
                        )

                        section(
                            title: String(localized: "所在地", bundle: LanguageManager.appBundle),
                            content: String(localized: "〒160-0023 東京都新宿区西新宿3丁目3番13号 西新宿水間ビル2F", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "電話番号", bundle: LanguageManager.appBundle),
                            content: String(localized: "お問い合わせください（下記メールアドレスにご請求いただければ遅滞なくご開示いたします）", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "お問い合わせ", bundle: LanguageManager.appBundle),
                            content: "info@appful.tokyo"
                        )

                        section(
                            title: String(localized: "販売価格", bundle: LanguageManager.appBundle),
                            content: String(localized: "本アプリは無料でご利用いただけます。一部の機能は有料のPremiumプランおよびPremium+プラン（サブスクリプション）でご提供します。\n\n【Premiumプラン】\n• 週間プラン: ¥500/週\n• 月間プラン: ¥980/月\n• 年間プラン: ¥5,000/年\n\n【Premium+プラン】\n• 週間プラン: ¥980/週\n• 月間プラン: ¥1,980/月\n• 年間プラン: ¥12,800/年\n\n価格は税込です。各プランの最新価格はApp Store内の購入画面でご確認ください。", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "商品代金以外の必要料金", bundle: LanguageManager.appBundle),
                            content: String(localized: "本アプリの利用にあたって発生する通信料金（インターネット接続料金等）はユーザーのご負担となります。", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "支払方法", bundle: LanguageManager.appBundle),
                            content: String(localized: "Apple App Storeを通じた決済となります。Apple IDに登録されたお支払い方法に従います。", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "支払時期", bundle: LanguageManager.appBundle),
                            content: String(localized: "サブスクリプション購入確定時、および各更新日に課金されます。サブスクリプションは、現在の期間が終了する24時間前までに解約しない限り、自動的に更新されます。", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "商品の引渡時期", bundle: LanguageManager.appBundle),
                            content: String(localized: "決済完了後、直ちにPremium機能をご利用いただけます。", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "返品・キャンセルについて", bundle: LanguageManager.appBundle),
                            content: String(localized: "サービスの性質上、決済完了後のキャンセル・返金は原則として行いません。返金についてはApple App Storeのポリシーに従います。返金をご希望の場合は、Apple サポート（https://reportaproblem.apple.com/）より直接お申し込みください。\n\nサブスクリプションは、Apple IDの設定画面からいつでも解約できます。解約後も、すでに課金された期間の終了日まではPremium機能をご利用いただけます。期間途中の解約による日割り返金は行いません。", bundle: LanguageManager.appBundle)
                        )

                        section(
                            title: String(localized: "動作環境", bundle: LanguageManager.appBundle),
                            content: String(localized: "iOS 17.6 以上のiPhone。インターネット接続環境が必要です。", bundle: LanguageManager.appBundle)
                        )
                    }
                    .padding(24)
                }
            }
            .navigationTitle(String(localized: "特定商取引法に基づく表記", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる", bundle: LanguageManager.appBundle)) {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundColor(MeloColors.Brand.pinkDeep)
                }
            }
        }
    }

    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MeloColors.Text.primary)

            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(MeloColors.Text.secondary)
                .lineSpacing(6)
        }
    }
}

// MARK: - Preview
#Preview {
    CommercialTransactionsView()
}
