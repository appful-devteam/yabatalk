# ハラスメントーク 再提出ランブック（2026-06-14）

リジェクト 2 件への対応記録と、提出前にやる ASC 手動作業 + 審査返信文。

- App: ハラスメントーク / appleAppId **6778561704** / bundle `appful.yabatalk`
- リジェクト: **4.1(c) Copycats** + **1.2 Safety – UGC**

---

## ① 4.1(c) Copycats（メタデータのみ・再ビルド不要）

App 名 / subtitle / keywords に他社ブランド名「LINE」を含めない。

| 項目 | 旧 | 新 |
|---|---|---|
| name | ハラスメントーク（変更不要・LINE 含まず） | ハラスメントーク |
| **subtitle** | `LINEトークを毒見。ハラスメント診断` | **`そのトーク、毒見します。ハラスメント診断`** |
| **keywords** | `…,セクハラ,LINE診断,職場,…` | `…,セクハラ,トーク診断,職場,…` |

- description 本文の「LINE のトーク履歴を読み込む」等の**機能説明としての言及は Apple は許容**（相互運用の説明）。ただし不安なら「トーク履歴（テキスト）を読み込む」に和らげても可。今回は subtitle / keywords のみ必須。
- **作業場所**: ASC > App Store > 1.0 > （日本語）プロモーション/サブタイトル/キーワード を上記に書き換えて保存。

---

## ② 1.2 Safety – User Generated Content

掲示板（ホーム）/ 相談部屋 / 擬似チャットの匿名 UGC があるため、7 要件を全て満たす。

### コード対応（このコミットで実装済み・ビルド成功）

| 1.2 要件 | 対応 |
|---|---|
| 客観コンテンツの**自動フィルタ** | ✅ **新規**: `ContentModeration`（`String+Extensions.swift`）+ 投稿時 guard。Board (`BoardFirestoreService.createPost/createPostWithImages/createReply`) と Community (`CommunityRoomFirestoreService.createPost/createReply`) の両系統 chokepoint で不適切語を含む投稿を throw。compose UI（`BoardComposeViewV2` / `BoardPostDetailView`）は投稿前プリチェック + アラート/トーストで即フィードバック。 |
| **通報** (flag) | ✅ 既存（`BoardPostDetailView` → `reportPost`） |
| **ブロック** | ✅ 既存（`BoardBlockService`） |
| 自分の投稿を**即削除** | ✅ 既存 |
| **EULA にゼロ容認＋即排除明文** | ✅ **追記**: `TermsOfServiceView` 第3条の2「不適切コンテンツ・迷惑行為を一切許容せず、通報を24時間以内に確認し削除＋当該ユーザーを利用停止（排除）」 |
| EULA 同意の強制 | ✅ 既存（初回 `TermsConsentView`、同意せずやめる導線あり） |
| アプリ内**お問い合わせ/報告窓口** | ✅ 既存（設定 > お問い合わせ → info@appful.tokyo）+ 各投稿の通報導線 |

### ASC 手動作業（提出前に必ず実施）

1. 🔴 **年齢レーティングを 18+ に再設定**（旧 12+ が 1.2 リジェクト要因）
   - ASC > App 情報 > 年齢制限指定 > 編集
   - ユーザー生成コンテンツの質問に回答し、結果が **18+** になるようにする（匿名 UGC アプリの必須水準）。
2. subtitle / keywords を ①の新値に更新。
3. （任意）App Privacy / ATT は drafter 出力手順どおり別途。

### App Review への返信文（Resolution Center に貼る・英語）

```
Hello, and thank you for the review.

We have addressed both issues.

[Guideline 4.1(c) — Copycats]
We removed the third-party brand name "LINE" from the app's metadata.
- Subtitle is now: "そのトーク、毒見します。ハラスメント診断"
- Keyword "LINE診断" was replaced with "トーク診断".
The app name does not contain any third-party brand name.

[Guideline 1.2 — User-Generated Content]
This build implements all required precautions for the anonymous board / community features:

1. Age rating: We updated the app's age rating to 18+.
2. Terms (EULA): Users must agree to our Terms before using the app. The Terms now
   explicitly state a zero-tolerance policy for objectionable content and abusive users,
   and that violating content will be removed and the offending user ejected.
   (Settings > Terms of Service, Article 3-2.)
3. Filtering objectionable content: Posts and replies are screened at submission time by
   an automated content filter; objectionable submissions are blocked with an in-app message.
4. Flagging: Every post and reply has a "Report" action.
5. Blocking: Users can block abusive users.
6. Immediate removal: Users can delete their own posts/replies from the feed at any time.
7. Moderation SLA: We act on reported content within 24 hours by removing the content and
   ejecting the user who provided it.
8. In-app contact: Users can report inappropriate activity via the in-app Report action and
   via Settings > Contact (info@appful.tokyo).

We are happy to provide any further information. Thank you.
```

---

## 提出フロー
1. このコミットのビルドを Xcode で Archive → ASC へアップロード（buildNumber を上げる）。
2. ASC で ①②のメタデータ + 18+ を保存。
3. 新ビルドを 1.0 に紐付け → 上記返信文を Resolution Center に貼って再提出。
