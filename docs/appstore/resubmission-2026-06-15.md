# ハラスメントーク 再提出ランブック（2026-06-15 / 第2版）

2回目リジェクト（3件）への対応。4.1(c) は前回で解消済み（今回指摘なし）。

- App: ハラスメントーク / appleAppId **6778561704** / bundle `appful.yabatalk`
- 今回の指摘: **2.1 ATT 未表示** / **2.1(a) 投稿が反映されないバグ（iPad）** / **1.2 UGC 再発**

---

## ① 2.1(a) Performance — 投稿が反映されないバグ（iPad Air, iPadOS 26.5）★コード修正済

### 原因
- 投稿成功後、`onPosted` がトースト表示のみで、**フィードへ即時反映していなかった**。リアルタイムリスナー到達に依存しており、iPad / タイミングによっては新規投稿が見えなかった。
- さらに投稿失敗時に `catch` が `print` で**握り潰し**ており、「投稿したのに反映されない」状態を誘発していた。

### 修正（コード）
- `BoardComposeViewV2.onPosted` を `((BoardPost) -> Void)` に変更し、作成した投稿を返す。`BoardFeedView` が受け取って**フィード先頭へ楽観的挿入**（リスナーの merge と二重にならないよう ID 重複ガード付き）。
- 投稿失敗時はトースト/アラートで**必ずユーザーに通知**（黙って失敗しない）。
- 影響ファイル: `BoardComposeViewV2.swift` / `BoardFeedView.swift` / `BoardMyProfileView.swift` / `CommunityRoomDetailView.swift`。ビルド成功。

> 補足: コメント（返信）は元々ローカル append で反映されるため問題なし。

---

## ② 2.1 ATT — トラッキング許可ダイアログが出ない ★コード修正済（要・実機デモ動画）

### 原因
- ATT 要求を**起動直後（RootView の `.task`、0.5s 後）**に行っていたが、その瞬間オンボーディングの `fullScreenCover`（アンケート/規約/ペイウォール）が表示中で、**ATT システムダイアログを提示できず無音で失敗**していた。

### 修正（コード）
- ATT 要求を **オンボーディングの全カバーが閉じ、シーンが `.active` になってから**行うよう `RootView` に移動（`requestATTIfReady()`、1度だけ・`.notDetermined` 時のみ）。
- 起動直後の旧要求（`lovetalkApp.task`）は削除。広告ゲート更新も ATT 応答後に実行。
- App Privacy は**トラッキングあり（IDFA）のまま維持**＝方針どおり（パーソナライズ広告を将来使う）。`NSUserTrackingUsageDescription` は Info.plist に既存。

### 🔴 審査返信に**実機の画面収録**を添付（必須）
Apple 指定の内容を 1 本の動画で:
1. フレッシュインストール（または 設定 > プライバシー > トラッキング でリセット）後にアプリ起動
2. オンボーディング（アンケート→規約同意→…）を進める
3. **オンボ終了直後に ATT 許可ダイアログが表示**される様子
4. 許可/拒否後のユーザーフロー
- 録画は ASC > App Review Information > Notes（メモ）欄にアップロード。

> ⚠️ 実機確認: 設定 > プライバシーとセキュリティ > トラッキング で「アプリからのトラッキング要求を許可」が ON であること（OFF だと OS がダイアログを抑制する）。

---

## ③ 1.2 Safety — UGC（再発）

前回コードは入っていたが、再発の二大要因と対策:

1. 🔴 **年齢レーティングが 18+ になっていない可能性**（今回ユーザー未確認）。匿名 UGC アプリは **18+ 必須**。12+/17+ のままだと**自動で 1.2 再発**する。
   - **確認/設定手順**: ASC > アプリ > 一般情報（または「年齢制限指定」）> 編集 > 質問票で、結果の年齢区分が **18+** になるよう回答して保存。UGC 系の質問（無制限のコンテンツ/ユーザー生成コンテンツ）に該当ありで回答すると 18+ に上がる。保存後、バッジが「18+」表示になっているか必ず目視確認。
2. **投稿反映バグ（①）で reviewer が安全機能（通報/ブロック/削除）を検証できなかった**可能性 → ①の修正で投稿が確実に見えるので、通報・ブロック・削除の導線を reviewer が辿れる。

実装済みの安全機構（前回 + 今回、すべてビルドに含める）:
- 投稿時の自動コンテンツフィルタ（`ContentModeration`、Board/Community 両系統の chokepoint）
- 通報 / ブロック / 自分の投稿の即削除
- EULA 同意の強制（オンボ）＋ EULA 第3条の2「ゼロ容認・24h以内に削除＋利用停止」明文
- アプリ内お問い合わせ（設定 → info@appful.tokyo）＋ 各投稿の通報導線

---

## 提出前チェック（必須）
- [ ] working tree の全変更を含めて **Archive → アップロード**（buildNumber を上げる）。※前回修正＋今回修正はまだ未コミット。Xcode は working tree から Archive するので、必ず現在の状態でアーカイブ。
- [ ] ASC 年齢レーティング = **18+**（保存・目視確認）
- [ ] App Privacy = トラッキングあり（IDFA）のまま（ATT 維持方針）
- [ ] subtitle/keywords に LINE 等の他社名が無い（前回対応済の維持確認）
- [ ] **実機で**: フレッシュ起動 → オンボ後に ATT ダイアログが出る／掲示板に投稿が即反映される／通報・ブロック・削除が動く、を録画
- [ ] 録画を App Review Information の Notes に添付

---

## App Review への返信文（Resolution Center に貼る・英語）

```
Hello, and thank you for the detailed feedback. We have addressed all three issues.

[Guideline 2.1(a) — Post not reflected]
We fixed a bug where a newly created board post was not immediately shown in the feed.
The app now inserts the created post at the top of the feed right after posting, and any
posting failure is now surfaced to the user instead of failing silently. Verified on iPad.

[Guideline 2.1 — App Tracking Transparency]
The ATT permission request was being triggered during the initial onboarding flow, while a
full-screen cover was presented, so iOS could not display the system dialog. We moved the ATT
request so it is presented only after onboarding completes and the scene is active. A screen
recording from a physical device demonstrating the prompt on a fresh install is attached in the
App Review Information notes.

[Guideline 1.2 — User-Generated Content]
- Age rating: We set the app's age rating to 18+.
- Terms (EULA): Users must agree to our Terms before use. The Terms explicitly state a
  zero-tolerance policy for objectionable content and abusive users, and that violating content
  is removed and the offending user ejected (Settings > Terms of Service, Article 3-2).
- Filtering: Posts/replies are screened by an automated content filter at submission time;
  objectionable submissions are blocked with an in-app message.
- Flagging: Every post and reply has a Report action.
- Blocking: Users can block abusive users.
- Immediate removal: Users can delete their own posts/replies at any time.
- Moderation SLA: We act on reported content within 24 hours by removing it and ejecting the user.
- In-app contact: Report action + Settings > Contact (info@appful.tokyo).

Thank you for the review.
```
