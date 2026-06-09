# yabatalk ダーク化変換ガイド（レガシー画面 → 黒地×ピンクaccent）

lovetalk 由来のライト（白地×ピンク）UI を、診断画面と同じ **黒地 + ホットピンク accent** のダークテーマに合わせる。
**意味（severity/写真/状態色）は壊さず、地・面・文字・アクセントだけを置換**する。

## 使ってよい色トークン（これ以外の新色を発明しない）
`MeloColors.Dark` の:
- 地/面: `bg`(#0C0C0F 画面背景) / `bgElevated`(#15151B 一段上) / `card`(#17171F カード/シート) / `cardStroke`(#2A2A34 枠) / `divider`(#24242C)
- 文字: `textPrimary`(#F2F2F5 明) / `textSecondary`(#9A9AA6 副)
- アクセント: `accent`(#FF3B6B ホットピンク) / `accentBright` / `accentDeep` / `onAccent`(#0C0C0F = accent面の上の文字=黒) / `accentGradient`(LinearGradient)
- severity(データ意味・変えない): `safe`(緑) / `caution`(黄) / `danger`(ピンク) / `safeGradient` / `dangerDeep`
- バー未充填: `track`

## 置換ルール（左→右）
| 元（ライト） | 置換後（ダーク） |
|---|---|
| `Color.white` を **背景/塗り** に使用 | カード/シート/ピル= `MeloColors.Dark.card`、全画面背景= `MeloColors.Dark.bg`、一段上の面= `MeloColors.Dark.bgElevated` |
| `Color.white` を **文字色** に使用（色付き/accentボタンの上の文字） | そのまま `Color.white` で残す（暗い面/写真の上）。ただし **accent(ピンク)塗りの上の文字**なら `MeloColors.Dark.onAccent`(黒) |
| `Color.black` / `.foregroundColor(.black)`（文字） | `MeloColors.Dark.textPrimary` |
| `MeloColors.Text.primary` / `Text.secondary`（暗グレー文字） | `MeloColors.Dark.textPrimary` / `MeloColors.Dark.textSecondary` |
| `MeloColors.Text.onPrimary`（白文字） | accent塗りの上なら `Dark.onAccent`、暗面の上なら `Dark.textPrimary` |
| `MeloColors.Surface.white` / `Surface.pinkPale` / `Surface.*`（ライト地） | `MeloColors.Dark.bg`（画面）/ `MeloColors.Dark.card`（面） |
| `MeloColors.Brand.pink*` / `Brand.*`（ブランドピンク=アクセント） | `MeloColors.Dark.accent` |
| `MeloColors.Gradient.pinkPrimary` 等のピンクグラデ（CTA/見出し） | `MeloColors.Dark.accentGradient` |
| `MeloColors.Gray.divider` / 薄いグレー罫線・枠 | `MeloColors.Dark.divider` / `MeloColors.Dark.cardStroke` |
| `MeloColors.Gray.subButton*`（薄ボタン地） | `MeloColors.Dark.bgElevated` + 文字 `Dark.textSecondary` |
| 薄ピンク/白のシャドウ（`.shadow(color: ...pink/white...)`） | `Color.black.opacity(0.3)` か `MeloColors.Dark.accent.opacity(0.15)` |
| `MeloColors.Status.*`（success/error/warning 等の状態色） | **変えない**（意味色） |

## 判断指針
- **コントラスト確保**: 暗い面の上の文字は必ず `Dark.textPrimary`/`textSecondary`（暗い文字を暗面に置かない）。
- **accent は綞って**: 主役の CTA・選択状態・強調・リンクに `accent`。広い面を全部ピンクにしない（地は黒/カードは `card`）。
- **写真・アバター・アイコン画像はそのまま**（full-color 画像の塗りは変えない）。
- **severity/状態色（safe/caution/danger/Status.*）は意味なので変えない**。
- 迷うケース（この表で判断できない独自色）は **勝手に発明せず、その行に `// TODO(dark): 要確認` コメントを付けて元のまま残す**。
- ロジック・レイアウト構造・文言は変えない。**色トークンの置換のみ**。

## 触ってはいけない
- `.pbxproj` / `.xcodeproj` / `.entitlements` / `.storyboard` / `Info.plist` は編集しない。
- 既にダークの画面（NewHomeView / DiagnosisResultView / DiagnosisLabKit / MainTabBar / ImportConfirmView / AnalyzingView）は対象外。
- ビルドは各自で走らせない（並列で derived data 競合するため）。**編集のみ**。最後に親(main)が一括ビルドして直す。

## 完了報告
- 変換した画面/ファイル一覧、`// TODO(dark)` を残した箇所（判断保留）、明らかなコントラスト懸念、を簡潔に。
