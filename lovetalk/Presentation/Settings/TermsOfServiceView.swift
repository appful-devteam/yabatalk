import SwiftUI

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
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
                        Text(String(localized: "この利用規約（以下「本規約」）は、めろとーく（以下「本アプリ」）の利用条件を定めるものです。ユーザーの皆様には、本規約に同意いただいた上で、本アプリをご利用いただきます。本アプリをダウンロード、インストール、または使用することにより、本規約に同意したものとみなされます。", bundle: LanguageManager.appBundle))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(MeloColors.Text.secondary)
                            .lineSpacing(6)

                        termsSection(
                            title: String(localized: "第1条（定義と適用）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本規約は、ユーザーと本アプリ運営者（以下「運営者」）との間の本アプリの利用に関わる一切の関係に適用されます。\n2. 本アプリに関して本規約のほか、ご利用にあたってのルール等、各種の定め（以下「個別規定」）をすることがあります。これら個別規定は本規約の一部を構成するものとします。\n3. 本規約と個別規定が矛盾する場合は、個別規定が優先して適用されるものとします。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第2条（サービスの内容）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本アプリは、LINEのトーク履歴（テキスト形式）を解析し、4軸スコアリング、コミュニケーションパターン分析、性格タイプ分類、およびAI要約を提供するサービスです。\n2. 本アプリが提供する診断結果、スコア、性格分類、およびAI生成サマリーは、すべて参考情報であり、科学的・医学的・心理学的な根拠に基づくものではありません。\n3. 本アプリの利用にはiOS端末およびインターネット接続環境が必要です。\n4. ユーザーは、自己の責任において本アプリを利用するものとします。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第3条（禁止事項）", bundle: LanguageManager.appBundle),
                            content: String(localized: "ユーザーは、本アプリの利用にあたり、以下の行為をしてはなりません：\n\n• 法令または公序良俗に違反する行為\n• 犯罪行為に関連する行為\n• 他のユーザーまたは第三者のプライバシーを侵害する行為\n• トーク相手の同意を得ずに、その方の個人情報を含むトーク履歴を本アプリに取り込み、第三者提供（AI機能への送信を含む）を行う行為であって、個人情報保護法に違反するもの\n• 他者のトーク履歴を無断で取得・解析する行為\n• ストーキング、ハラスメント、嫌がらせ等の目的で本アプリを利用する行為\n• 本アプリの運営を妨害するおそれのある行為\n• 本アプリのリバースエンジニアリング、逆コンパイル、逆アセンブル、またはソースコードの抽出を試みる行為\n• 本アプリのAPIキーを不正に取得・使用する行為\n• 自動化ツール等を使用して大量のリクエストを送信する行為\n• その他、運営者が不適切と合理的に判断する行為", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第4条（トーク履歴データの取り扱い）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. ユーザーがインポートしたトーク履歴データは、原則としてユーザーのデバイス内にのみ保存されます。\n2. AIサマリー機能、返信提案（相談）機能、または擬人化チャット機能を利用する場合、トーク履歴の一部（メッセージ本文、送信者名、送信日時）がGoogle LLC が提供するGemini APIのサーバーに送信されます。画像・動画・スタンプ等のメディアデータは送信されません。\n3. ユーザーは、これらのAI機能の初回利用時に、データの外部送信に関する明示的な同意を行う必要があります。各機能の初回利用時に、送信されるデータの内容、送信先（Google LLC）、およびGoogleによるデータの取り扱いについて明記した同意画面が表示されます。\n4. Googleによるデータの取り扱いについては、Googleのプライバシーポリシー（https://policies.google.com/privacy）およびGemini API利用規約（https://ai.google.dev/gemini-api/terms）が適用されます。Google LLC は業界標準のセキュリティ対策を講じており、送信されたデータに対して同等以上のデータ保護を提供しています。\n5. AI機能を利用しない場合、トーク履歴がデバイス外に送信されることはありません。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第5条（トーク相手の個人情報に関するユーザーの責任）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. トーク履歴にはユーザー以外の方（トーク相手）の発言、氏名、その他の個人情報が含まれています。\n2. 日本の個人情報保護法に基づき、第三者の個人情報を外部サービス（Google Gemini API を含む）に提供する際は、原則としてその方の同意が必要です。AI機能（AIサマリー・返信提案・擬人化チャット）を利用する場合、トーク相手の個人情報がGoogle LLC のサーバーに送信されることをご理解ください。\n3. ユーザーは、本アプリの利用にあたり、トーク相手のプライバシーに十分配慮し、必要に応じてトーク相手の同意を得る等、法令を遵守するための適切な措置を講じる責任を負います。\n4. LINEの利用規約では、第三者の個人情報を不正に収集・開示・提供する行為が禁止されています。ユーザーは、LINEの利用規約を遵守した上で本アプリを利用してください。\n5. トーク相手のプライバシーに関して生じた紛争、損害、請求等について、運営者は一切の責任を負いません。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第6条（サブスクリプション）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本アプリは無料機能に加え、有料のPremiumプランおよびPremium+プラン（サブスクリプション）を提供しています。\n2. サブスクリプションの購入はApple App Storeを通じて行われ、Appleの利用規約および決済ポリシーが適用されます。\n3. サブスクリプションのプランおよび価格：\n   【Premiumプラン】\n   • 週間プラン: ¥500/週\n   • 月間プラン: ¥980/月\n   • 年間プラン: ¥5,000/年\n   【Premium+プラン】\n   • 週間プラン: ¥980/週\n   • 月間プラン: ¥1,980/月\n   • 年間プラン: ¥12,800/年\n4. サブスクリプションは、現在の期間が終了する24時間前までに解約しない限り、自動的に更新されます。\n5. 解約は、Apple ID の設定画面から行うことができます。\n6. サブスクリプション期間中の途中解約による日割り返金は行いません。返金についてはAppleのポリシーに従います。\n7. 無料トライアル期間が提供される場合、未使用部分はサブスクリプション購入時に失効します。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第7条（広告）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本アプリの無料版では、Google AdMob による広告が表示される場合があります。\n2. 広告の表示にあたり、Google のプライバシーポリシーが適用されます。\n3. Premiumプランに加入することで、広告を非表示にすることができます。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第8条（免責事項）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本アプリが提供する診断結果、スコア、性格分類、AI生成サマリー、および返信提案は、すべて参考情報であり、その正確性、完全性、有用性、特定目的への適合性を保証するものではありません。\n2. 診断結果やAI生成コンテンツに基づくユーザーの判断や行動（人間関係に関する意思決定を含む）について、運営者は一切の責任を負いません。\n3. Google Gemini API に送信されたデータの取り扱いについて、運営者は責任を負いません。データ送信後の取り扱いは Google LLC のプライバシーポリシーおよび利用規約に従います。\n4. 本アプリの利用により生じたいかなる損害（直接損害、間接損害、偶発的損害、特別損害、懲罰的損害、逸失利益を含むがこれらに限定されない）についても、運営者は法令上許容される最大限の範囲で責任を負いません。\n5. 本アプリは現状有姿（AS IS）で提供されます。\n6. 通信環境、デバイスの状態、外部サービスの障害等に起因する本アプリの動作不良について、運営者は責任を負いません。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第9条（サービスの変更・中断・終了）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 運営者は、以下の場合に、事前の通知なく本アプリの内容を変更、中断、または終了することができます：\n   • システムの保守・点検・更新を行う場合\n   • 天災、停電、通信障害等の不可抗力により提供が困難な場合\n   • 外部サービス（Google Gemini API 等）の提供停止・仕様変更があった場合\n   • その他、運営者が合理的に必要と判断した場合\n2. 本アプリの変更、中断、終了によってユーザーに生じた損害について、運営者は責任を負いません。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第10条（知的財産権）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本アプリに関するすべての知的財産権（著作権、商標権、意匠権等を含む）は、運営者または正当な権利者に帰属します。\n2. ユーザーは、運営者の事前の書面による許可なく、本アプリのコンテンツ（UI、アイコン、キャラクター画像、テキスト等）を複製、転載、改変、配布、販売することはできません。\n3. ユーザーが本アプリにインポートしたトーク履歴データの著作権および権利は、ユーザーおよび元の著作権者に帰属します。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第11条（利用規約の変更）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 運営者は、法令の改正、サービス内容の変更、その他必要と判断した場合には、ユーザーへの事前の通知なく本規約を変更することができます。\n2. 変更後の利用規約は、本アプリ内に表示した時点から効力を生じるものとします。\n3. 変更後に本アプリを継続して利用した場合、変更後の規約に同意したものとみなします。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第12条（準拠法・管轄）", bundle: LanguageManager.appBundle),
                            content: String(localized: "1. 本規約の解釈にあたっては、日本法を準拠法とします。\n2. 本アプリに関して紛争が生じた場合には、東京地方裁判所を第一審の専属的合意管轄裁判所とします。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第13条（分離可能性）", bundle: LanguageManager.appBundle),
                            content: String(localized: "本規約の一部の条項が法令により無効または執行不能と判断された場合であっても、残りの条項は引き続き有効に存続するものとします。", bundle: LanguageManager.appBundle)
                        )

                        termsSection(
                            title: String(localized: "第14条（運営者情報・お問い合わせ）", bundle: LanguageManager.appBundle),
                            content: String(localized: "運営者: 株式会社appful\n代表者: Ryusei Okamoto\n所在地: 〒160-0023 東京都新宿区西新宿3丁目3番13号 西新宿水間ビル2F\n電話番号: お問い合わせください（下記メールアドレスにご請求いただければ遅滞なくご開示いたします）\nお問い合わせ: info@appful.tokyo\n\n本規約に関するお問い合わせは、上記メールアドレスまたはアプリ内「設定 > お問い合わせ」よりご連絡ください。", bundle: LanguageManager.appBundle)
                        )
                    }
                    .padding(24)
                }
            }
            .navigationTitle(String(localized: "利用規約", bundle: LanguageManager.appBundle))
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

    private func termsSection(title: String, content: String) -> some View {
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
    TermsOfServiceView()
}
