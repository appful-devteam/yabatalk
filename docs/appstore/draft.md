# Metadata Draft — ハラスメントーク (appleAppId 6778561704)

- appInfoId: `0f0d64b7-bd97-42d1-bb2c-0c3723965f5e`
- editableVersionId: `8cf6c86c-f639-482f-829a-940a2edaabaa` (1.0 / PREPARE_FOR_SUBMISSION)
- appInfoLoc ja id: `831d8dfc-...`
- versionLoc ja id: `c45dc970-a023-49a8-a2b1-320d67da7ec4`
- 法務 URL 疎通確認済み (/, /privacy, /terms, /tokutei = 200)

## Categories
- Primary: **LIFESTYLE**（ライフスタイル）
- Secondary: **SOCIAL_NETWORKING**（ソーシャルネットワーキング）

## ja — App Info
- name: `ハラスメントーク`（既存・変更なし）
- subtitle (≤30): `そのトーク、毒見します。ハラスメント診断`  <!-- 4.1(c): LINE 除去済 (旧: LINEトークを毒見。ハラスメント診断) -->
- name: `ハラスメントーク`（LINE 等の他社ブランド名を含まない — 4.1(c) OK）
- privacyPolicyUrl: `https://darkmerotalk.com/privacy`

## ja — Version Localization
- promotionalText (≤170): `トーク履歴を貼るだけ。パワハラ・モラハラ・セクハラを4分類で毒見診断。掲示板でみんなの経験をシェア。`
- keywords (≤100): `ハラスメント,パワハラ,モラハラ,セクハラ,トーク診断,職場,人間関係,毒舌,チェック,相談`  <!-- 4.1(c): LINE診断 → トーク診断 -->`
- supportUrl: `https://darkmerotalk.com`
- marketingUrl: `https://darkmerotalk.com`
- whatsNew: `初回リリース`
- description: 下記参照（端末内処理の明記 / AI同意制 / UGC通報ブロック / サブスク価格・自動更新・解約 / アカウント削除 / EULA+プライバシーフッター）

## Age Rating → 18+ 必須（Guideline 1.2: 匿名 UGC があるため）
| key | 値 |
|---|---|
| userGeneratedContent | FREQUENT（掲示板UGCあり）|
| matureOrSuggestiveThemes | FREQUENT（ハラスメント主題）|
| profanityOrCrudeHumor | FREQUENT（毒舌UI）|
| その他 violence/sexual/gambling 等 | NONE |
| **結果の年齢区分** | **18+**（ASC の新年齢レーティングで 18+ になるよう回答。匿名 UGC アプリの 1.2 要件）|

> 🔴 旧申請は 12+ で 1.2 リジェクト。ASC > App 情報 > 年齢制限指定 で **18+** に再設定して保存すること。

## Version Defaults
- copyright: `2026 appful Inc.`
- review contact: Ryusei Okamoto / info@appful.tokyo / +8107064754676
- releaseType: MANUAL

## Compliance: PASS 8 / WARN 3 (UGC利用規約のdescription明示, AdMobのApp Privacy宣言, ATT)
## App Privacy / ATT は別途 ASC UI 手動（drafter 出力の手順参照）

---
---

# en-US 追加ローカライズ草案（2026-06-19）

- primaryLocale: ja（**変更しない**）／追加対象: **en-US**
- editableVersionId 1.2 = **READY_FOR_SALE（ライブ）** → version レベル新規ロケール追加は 409 ロックの可能性大。
  その場合 ASC で新バージョン（1.3）を Prepare 状態にしてから version ローカライズを投入する必要あり。

## App Info (en-US)
| field | 値 | 文字数 |
|---|---|---|
| name | `Harassmentalk: Chat Check` | 25/30 |
| subtitle | `Spot harassment in your chats` | 29/30 |
| privacyPolicyUrl | `https://darkmerotalk.com/privacy` | — |

## Version Localization (en-US)
- keywords (94/100, カンマ後スペースなし):
  `harassment,workplace,toxic,abuse,gaslighting,power harassment,chat analysis,LINE,relationship,toxic boss`
- promotionalText (150/170):
  `Paste your LINE chat history and instantly see power, moral, and sexual harassment patterns broken down by type. Works for English and Japanese chats.`
- supportUrl / marketingUrl: `https://darkmerotalk.com`
- whatsNew: （空）
- description: ja 完全ミラー（hook→機能→18要素の仕組み(法的断定でない)→AI相談(Google Gemini明示/同意制)→掲示板(通報/ブロック/運営確認/無料は広告)→Premium(価格/自動更新/解約)→アカウント削除導線→サポート→EULA/Privacy フッター）+ 英語チャット対応を明記。本文は draft-approved.json に格納。

## Categories（変更なし）: primary UTILITIES / secondary LIFESTYLE

## Compliance
- ✅ EULA+Privacy フッター(privacyPolicyUrl一致) / サブスク必須記載 / 法的・医療断定回避 / UGC通報ブロック運営確認 / AI送信先Gemini明示
- ⚠️ 提出前(別件): darkmerotalk.com の support/privacy 200確認(4.5) / アカウント削除導線 / 年齢17+ / 審査ノートにUGCモデレーション
