import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MeloColors.Dark.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 最終更新日
                        Text(String(localized: "最終更新日: 2026年5月18日", bundle: LanguageManager.appBundle))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(MeloColors.Dark.textSecondary)

                        // イントロ
                        Text(String(localized: "ハラスメントーク（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めています。本プライバシーポリシーは、本アプリが取り扱う情報の種類、利用目的、第三者への提供、およびユーザーの権利について説明します。本アプリのご利用をもって、本プライバシーポリシーに同意したものとみなします。", bundle: LanguageManager.appBundle))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .lineSpacing(6)

                        policySection(
                            title: String(localized: "1. 収集する情報", bundle: LanguageManager.appBundle),
                            content: String(localized: "本アプリは以下の情報を取り扱います：\n\n(1) トーク履歴データ\nユーザーがインポートしたLINEのトーク履歴ファイル（テキスト形式）を解析のために使用します。これらのデータにはメッセージ本文、送信者名、送信日時が含まれます。\n\n(2) 解析結果データ\nトーク履歴から算出されたハラスメント傾向スコア（やばさ度）、ハラスメント分類、検出された要素、統計情報、および診断結果。\n\n(3) サブスクリプション情報\nApple App Store経由でのPremium／Premium+プランの購入履歴。本アプリが決済情報を直接収集することはありません。\n\n(4) 匿名利用統計・エラーログ\nアプリの機能改善および障害対応のため、匿名化された利用統計情報・エラーログを Google LLC が提供する Firebase（Firebase Analytics・Crashlytics）に送信する場合があります。これらのデータには個人を特定する情報は含まれません。\n\n(5) 認証用識別子・プッシュ通知トークン\nコミュニティ機能・通知機能の提供のため、Firebase Authentication が発行する匿名 UID および APNs プッシュトークンを Firebase（Firestore／Cloud Functions）上に保存します。", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "2. データの保存場所と管理", bundle: LanguageManager.appBundle),
                            content: String(localized: "(1) ローカル保存（原則）\nトーク履歴データおよび解析結果は、原則としてユーザーのデバイス内にのみ保存されます（Apple SwiftData フレームワークを使用）。\n\n(2) 外部送信が発生する場合\n以下の機能を利用する場合に限り、データがデバイス外に送信されます：\n• AIサマリー機能：トーク履歴の一部が Google LLC のサーバー（Gemini API）に送信されます（詳細は第5条参照）\n• 返信提案（相談）機能：会話コンテキストの一部が Google LLC のサーバー（Gemini API）に送信されます\n• 擬人化チャット機能：トーク相手の性格を再現するため、トーク履歴の一部が Google LLC のサーバー（Gemini API）に送信されます\n• 匿名利用統計・エラーログ：匿名化された利用情報・エラー情報が Google LLC が提供する Firebase（Firebase Analytics・Crashlytics）に送信される場合があります\n• コミュニティ機能・通知機能：匿名 UID およびプッシュトークンが Firebase（Firestore／Cloud Functions）に保存されます\n\n(3) データの保持期間\nデバイス内のデータは、ユーザーがアプリを削除するか、設定画面の「すべてのデータを削除」を実行するまで保持されます。Firebase 上に保存される匿名識別子等は、運営者が運用上必要と判断する期間保管されます。\n\n(4) AI機能を利用しない場合、トーク履歴が外部に送信されることは一切ありません。", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "3. 情報の利用目的", bundle: LanguageManager.appBundle),
                            content: String(localized: "収集した情報は以下の目的にのみ利用します：\n\n• トーク履歴の解析およびハラスメント診断結果の生成\n• AI機能（サマリー生成・返信提案）の提供\n• アプリ機能の提供、維持、改善\n• エラーの検出および修正\n• ユーザーサポートへの対応", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "4. 第三者への提供", bundle: LanguageManager.appBundle),
                            content: String(localized: "本アプリは、以下の場合を除き、ユーザーの個人情報を第三者に提供することはありません：\n\n(1) ユーザーが明示的に同意した場合\nAIサマリー機能、返信提案（相談）機能、または擬人化チャット機能の初回利用時に表示される同意画面にて、データ送信に同意した場合。\n\n(2) 法令に基づく場合\n法律の規定に基づき、裁判所、警察その他の行政機関から開示を求められた場合。\n\n本アプリが利用する外部サービス：\n• Apple App Store（アプリ配信およびサブスクリプション決済）\n• Google Gemini API（AIサマリー機能・返信提案機能・擬人化チャット機能） — 運営: Google LLC\n• Firebase（Firebase Analytics・Crashlytics・Cloud Functions・Cloud Firestore・Authentication・Remote Config・Cloud Messaging） — 運営: Google LLC\n• Google AdMob（広告配信） — 運営: Google LLC", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "5. Google Gemini API の利用について", bundle: LanguageManager.appBundle),
                            content: String(localized: "AIサマリー機能、返信提案（相談）機能、および擬人化チャット機能では、Google LLC が提供する Gemini API を利用しています。\n\n(1) 送信先\nGoogle LLC（Gemini API）\n所在地: 米国カリフォルニア州\n\n(2) 送信されるデータ\nトーク履歴のメッセージ本文、送信者名、送信日時（画像・動画・スタンプ等のメディアデータは送信されません）。\n\n(3) Google によるデータの取り扱い\nGoogle の Gemini API 利用規約（Gemini API Additional Terms of Service）に基づき、送信されたデータは以下のように取り扱われる可能性があります：\n• Google の製品・サービスおよび機械学習技術の改善に利用される場合があります\n• Google の担当者がデータを閲覧・注釈付け・処理する場合があります（閲覧時にはユーザーのアカウント情報との紐付けは解除されます）\n• 不正利用検出のため、最大55日間 Google のサーバーに保持される場合があります\n\n(4) データ保護について\nGoogle LLC は、業界標準のセキュリティ対策を講じており、送信されたデータに対して本アプリと同等以上のデータ保護を提供しています。詳細は Google のプライバシーポリシーをご参照ください。\n\n(5) 同意の取得\n本機能はユーザーの明示的な同意を得た場合のみ有効になります。各AI機能の初回利用時に、送信されるデータの内容・送信先・Googleによるデータの取り扱いを明記した同意画面が表示され、ユーザーが明示的に同意した場合のみデータが送信されます。\n\n(6) 詳細\nGoogle のプライバシーポリシー: https://policies.google.com/privacy\nGemini API 利用規約: https://ai.google.dev/gemini-api/terms", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "6. トーク相手のプライバシーについて", bundle: LanguageManager.appBundle),
                            content: String(localized: "トーク履歴にはユーザー以外の方（トーク相手）の発言や個人情報が含まれています。\n\n日本の個人情報保護法（平成15年法律第57号）に基づき、第三者の個人情報を外部サービスに提供する際は、原則としてその方の同意が必要です（同法第27条）。\n\nユーザーは、本アプリの利用にあたり、トーク相手のプライバシーに十分配慮し、必要に応じてトーク相手の同意を得る等、適切な措置を講じてください。トーク相手のプライバシーに関して生じた一切の紛争について、本アプリの開発者は責任を負いません。", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "7. セキュリティ", bundle: LanguageManager.appBundle),
                            content: String(localized: "本アプリは、ユーザーデータの保護のため、以下のセキュリティ対策を講じています：\n\n• すべてのローカルデータはApple SwiftDataフレームワークにより管理されます\n• 外部サーバーとの通信はHTTPS暗号化通信を使用します\n• APIキー等の認証情報はアプリ内にハードコーディングせず、サーバーから動的に取得します\n\nただし、インターネット上のデータ送信において、完全なセキュリティを保証することはできません。", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "8. お子様のプライバシー", bundle: LanguageManager.appBundle),
                            content: String(localized: "本アプリは13歳未満のお子様を対象としていません。13歳未満のお子様から意図的に個人情報を収集することはありません。13歳未満のお子様が本アプリを利用していることが判明した場合、速やかに該当データを削除します。", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "9. ユーザーの権利", bundle: LanguageManager.appBundle),
                            content: String(localized: "ユーザーは以下の権利を有します：\n\n• データの削除：設定画面の「すべてのデータを削除」より、保存されたすべてのデータを削除できます\n• AI機能の不使用：AIサマリー機能・返信提案機能を利用しないことで、外部へのデータ送信を完全に回避できます\n• アプリの削除：アプリを削除することで、デバイス内のすべてのデータが削除されます", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "10. プライバシーポリシーの変更", bundle: LanguageManager.appBundle),
                            content: String(localized: "本プライバシーポリシーは、法令の改正、サービス内容の変更、その他必要に応じて改定される場合があります。重要な変更がある場合は、アプリ内のお知らせまたはアップデート情報にてお知らせします。変更後のプライバシーポリシーは、アプリ内に表示した時点から効力を生じるものとします。", bundle: LanguageManager.appBundle)
                        )

                        policySection(
                            title: String(localized: "11. 運営者情報・お問い合わせ", bundle: LanguageManager.appBundle),
                            content: String(localized: "運営者: 株式会社appful\n代表者: Ryusei Okamoto\n所在地: 〒160-0023 東京都新宿区西新宿3丁目3番13号 西新宿水間ビル2F\n電話番号: お問い合わせください（下記メールアドレスにご請求いただければ遅滞なくご開示いたします）\nお問い合わせ: info@appful.tokyo\n\nプライバシーに関するご質問、苦情、またはデータの削除要求等は、上記メールアドレスまたはアプリ内「設定 > お問い合わせ」よりご連絡ください。", bundle: LanguageManager.appBundle)
                        )
                    }
                    .padding(24)
                }
            }
            .navigationTitle(String(localized: "プライバシーポリシー", bundle: LanguageManager.appBundle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "閉じる", bundle: LanguageManager.appBundle)) {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundColor(MeloColors.Dark.accent)
                }
            }
        }
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MeloColors.Dark.textPrimary)

            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(MeloColors.Dark.textSecondary)
                .lineSpacing(6)
        }
    }
}

// MARK: - Preview
#Preview {
    PrivacyPolicyView()
}
