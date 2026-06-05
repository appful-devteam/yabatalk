# CLAUDE.md — yabatalk

## Project Overview

**yabatalk** — LINE トーク履歴からハラスメント傾向を診断する iOS アプリ。
かわいい毒舌 UI（毒見結果）×論理的なハラスメント構造分解エンジン の二重構造が特徴。

- **Language:** Swift 6.2
- **UI:** SwiftUI
- **Platform:** iOS 26+, iPhone only
- **Bundle ID:** `appful.yabatalk`
- **Tests:** Swift Testing + 実機 XCUITest（シミュレータは使わない方針はアプリ次第）

## Scaffolding 由来

このリポジトリは **lovetalk（めろとーく）からコードベースを丸ごとコピー** してスタート。
Xcode の "Rename Project" wizard で **プロジェクト名 / ターゲット名 / scheme は yabatalk 化済み**
（`yabatalk.xcodeproj` / target `yabatalk` / scheme `yabatalk`）。

ただし pbxproj 内の `path = lovetalk;` 参照とディスク上のソースフォルダ名 (`lovetalk/` / `lovetalkTests/` /
`lovetalkUITests/`) は **整合のためそのまま残置**（pbxproj は agent 編集禁止のため、Finder で雑に変えると
ビルドが壊れる）。`.app-meta.yaml` の `conventions.*` パスはディスクフォルダ名 (`lovetalk/...`) で正本。

## 診断仕様の正本

すべての診断ロジック・タイプ名・スコアリング・アウトプットは:

**`docs/spec/diagnosis-logic.md`**

を **single source of truth** とする。Swift 実装は必ずここを参照する。
仕様変更はまずこのファイルを更新してから実装に反映。

## アーキテクチャ

lovetalk から継承した MVVM + Clean。yabatalk 固有の追加層:

- **Domain/Models/Diagnosis/** — `HarassmentCategory`, `HarassmentFactor`, `HarassmentType`, `DiagnosisResult` 等
- **Data/Analyzers/Diagnosis/** — `FactorDetector`, `FactorScorer`, `CategoryScorer`, `PriorityResolver`, `TypeMatcher`, `OutputBuilder`
- **Domain/UseCases/DiagnoseHarassmentUseCase.swift** — 上記をオーケストレート
- **Presentation/Result/Diagnosis/** — 毒見結果画面（タイプ + 闇成分ミックス + 論理説明 + 引用）

既存の lovetalk アナライザ / モデル / UI は **削除せず残置**。yabatalk MVP で必要かどうかは
段階的に判断する。

## 既存 lovetalk コードの扱い（要判断）

| モジュール | 状態 | 判断ポイント |
|---|---|---|
| Data/Analyzers/{Volume,Temperature,Response,Word}AxisCalculator | 残置 | yabatalk では別軸。再利用しないなら削除 |
| Data/Services/* (Firebase / Supabase / Ads / Subscription / Persona / Board / Community) | 残置 | yabatalk MVP では未使用。Bundle ID 切替に伴い設定差し替え or 削除 |
| Presentation/Board / Community / Consultation / PersonaChat / Subscription | 残置 | yabatalk では同等機能を持たない予定 |
| GoogleService-Info.plist / Configuration.storekit | 残置 | Firebase / IAP を採用するなら差し替え、しないなら削除 |
| LP/ | 残置 | yabatalk 用 LP は別途検討 |

判断したら CLAUDE.md と `.app-meta.yaml` を更新する。

## Build & Run

```bash
xcodebuild -project yabatalk.xcodeproj -scheme yabatalk -configuration Debug build

# 実機テスト（Xcode で実行）
```

ユーザーの方針: **シミュレータではなく Xcode で実機テスト**。

## 絶対禁止事項（ワークスペース既定の再掲）

- `.pbxproj` / `.xcodeproj/` / `.xcworkspace/` / `.xib` / `.storyboard` / `.entitlements` のエージェント直接編集
- ATS の無効化
- ハードコードされた API キー・トークン
- `--no-verify` でフックバイパス

## ワークフロー

```
診断仕様変更:  docs/spec/diagnosis-logic.md を更新 → 実装に反映
新機能:        /plan → /tdd → /code-review
バグ修正:      /tdd → /build-fix
リリース前:    /quality-gate
```
