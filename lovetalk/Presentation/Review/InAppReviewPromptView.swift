//
//  InAppReviewPromptView.swift
//  yabatalk
//
//  Source: .claude/skills/inapp-review-prompt/templates/InAppReviewPromptView.swift.tmpl
//  アプリ内評価ポップアップ（2 段フロー）。
//    Page 1: 「{App名} を気に入りましたか？」(はい/いいえ)
//       はい → 即 OS の requestReview を呼ぶ
//       いいえ → Page 2（カテゴリ選択 + 自由記入 → mailto: で送信）
//  デザインは MeloColors.Dark（黒地×ホットピンク accent）に合わせている。
//

import StoreKit
import SwiftUI

struct InAppReviewPromptView: View {
    /// 表示するアプリ名。
    let appName: String
    /// フィードバック収集チャネル（既定: mailto）。
    let feedbackChannel: any FeedbackChannel
    /// Page 2 のチェックボックス候補。
    let feedbackCategories: [String]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Page = .askLiked
    @State private var selectedCategories: Set<String> = []
    @State private var freeText: String = ""
    @State private var isSending: Bool = false
    @State private var sendingError: String?
    @FocusState private var freeTextFocused: Bool

    private static let freeTextLimit = 500

    // MARK: - Design Tokens（MeloColors.Dark に統一）
    private static let COLOR_BG       = MeloColors.Dark.bg
    private static let COLOR_CARD     = MeloColors.Dark.card
    private static let COLOR_INK      = MeloColors.Dark.textPrimary
    private static let COLOR_INK_SOFT = MeloColors.Dark.textSecondary
    private static let COLOR_ACCENT   = MeloColors.Dark.accent
    private static let COLOR_WARN_BG  = MeloColors.Dark.caution.opacity(0.22)

    private static let FONT_TITLE   = Font.title2.weight(.semibold)
    private static let FONT_BODY    = Font.body
    private static let FONT_CAPTION = Font.footnote

    private static let SPACING_XS: CGFloat = 4
    private static let SPACING_SM: CGFloat = 8
    private static let SPACING_MD: CGFloat = 12
    private static let SPACING_LG: CGFloat = 20

    private static let RADIUS_CARD: CGFloat = 14
    private static let RADIUS_CHIP: CGFloat = 10

    private enum Page: Equatable {
        case askLiked
        case feedback
    }

    var body: some View {
        NavigationStack {
            Group {
                switch page {
                case .askLiked: askLikedPage
                case .feedback: feedbackPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.COLOR_BG.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") { dismiss() }
                        .foregroundStyle(Self.COLOR_INK_SOFT)
                }
            }
        }
        .presentationDetents(page == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
    }

    // MARK: - Page 1: 温度測定

    private var askLikedPage: some View {
        VStack(spacing: Self.SPACING_LG) {
            Spacer(minLength: Self.SPACING_LG)
            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(Self.COLOR_ACCENT)
            VStack(spacing: Self.SPACING_SM) {
                Text("\(appName) を気に入りましたか？")
                    .font(Self.FONT_TITLE)
                    .foregroundStyle(Self.COLOR_INK)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("いただいた声で改善します")
                    .font(Self.FONT_BODY)
                    .foregroundStyle(Self.COLOR_INK_SOFT)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Self.SPACING_LG)
            VStack(spacing: Self.SPACING_SM) {
                primaryButton(String(localized: "はい、気に入っています"), role: .yes) {
                    requestReview()
                    dismiss()
                }
                secondaryButton(String(localized: "いいえ、改善してほしい")) { page = .feedback }
            }
            .padding(.horizontal, Self.SPACING_LG)
            Spacer()
        }
    }

    // MARK: - Page 2: フィードバック収集（「いいえ」分岐）

    private var feedbackPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Self.SPACING_LG) {
                    header
                    categoryList
                    freeTextField
                    if let sendingError {
                        warningBanner(sendingError)
                    }
                }
                .padding(Self.SPACING_LG)
            }
            .scrollContentBackground(.hidden)
            sendBar
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Self.SPACING_SM) {
            Text("ご意見ありがとうございます")
                .font(Self.FONT_TITLE)
                .foregroundStyle(Self.COLOR_INK)
                .accessibilityAddTraits(.isHeader)
            Text("どこを直すとよくなりますか？\nいくつでも選んでください。")
                .font(Self.FONT_BODY)
                .foregroundStyle(Self.COLOR_INK_SOFT)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: Self.SPACING_SM) {
            ForEach(feedbackCategories, id: \.self) { category in
                categoryRow(category)
            }
        }
    }

    private func categoryRow(_ category: String) -> some View {
        let isOn = selectedCategories.contains(category)
        return Button {
            if isOn { selectedCategories.remove(category) }
            else { selectedCategories.insert(category) }
        } label: {
            HStack(spacing: Self.SPACING_SM) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isOn ? Self.COLOR_ACCENT : Self.COLOR_INK_SOFT)
                Text(category)
                    .font(Self.FONT_BODY)
                    .foregroundStyle(Self.COLOR_INK)
                Spacer()
            }
            .padding(Self.SPACING_MD)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Self.COLOR_CARD,
                        in: RoundedRectangle(cornerRadius: Self.RADIUS_CARD))
            .overlay(
                RoundedRectangle(cornerRadius: Self.RADIUS_CARD)
                    .strokeBorder(isOn ? Self.COLOR_ACCENT : Self.COLOR_INK_SOFT.opacity(0.18),
                                  lineWidth: isOn ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }

    private var freeTextField: some View {
        VStack(alignment: .leading, spacing: Self.SPACING_SM) {
            HStack {
                Text("自由記入（任意）")
                    .font(Self.FONT_CAPTION)
                    .foregroundStyle(Self.COLOR_INK_SOFT)
                Spacer()
                Text("\(freeText.count)/\(Self.freeTextLimit)")
                    .font(Self.FONT_CAPTION)
                    .foregroundStyle(Self.COLOR_INK_SOFT)
            }
            TextField("ご意見・気になった点があれば書いてください",
                      text: $freeText, axis: .vertical)
                .keyboardType(.default)
                .lineLimit(3 ... 8)
                .focused($freeTextFocused)
                .foregroundStyle(Self.COLOR_INK)
                .padding(Self.SPACING_MD)
                .frame(minHeight: 96, alignment: .topLeading)
                .background(Self.COLOR_CARD,
                            in: RoundedRectangle(cornerRadius: Self.RADIUS_CARD))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.RADIUS_CARD)
                        .strokeBorder(Self.COLOR_INK_SOFT.opacity(0.18), lineWidth: 1))
                .onChange(of: freeText) { _, new in
                    if new.count > Self.freeTextLimit {
                        freeText = String(new.prefix(Self.freeTextLimit))
                    }
                }
        }
    }

    private func warningBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.COLOR_INK)
            Text(message)
                .font(Self.FONT_CAPTION)
                .foregroundStyle(Self.COLOR_INK)
        }
        .padding(Self.SPACING_SM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.COLOR_WARN_BG, in: RoundedRectangle(cornerRadius: Self.RADIUS_CHIP))
    }

    private var sendBar: some View {
        VStack(spacing: Self.SPACING_XS) {
            primaryButton(String(localized: "送る"), role: .yes, isEnabled: isSendEnabled,
                          showsProgress: isSending) {
                Task { await submit() }
            }
            tertiaryButton(String(localized: "キャンセル")) { dismiss() }
        }
        .padding(.horizontal, Self.SPACING_LG)
        .padding(.top, Self.SPACING_SM)
        .padding(.bottom, Self.SPACING_XS)
        .background(Self.COLOR_BG.opacity(0.95).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Self.COLOR_INK_SOFT.opacity(0.15)).frame(height: 1)
        }
    }

    private var isSendEnabled: Bool {
        !isSending
            && (!selectedCategories.isEmpty
                || !freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submit() async {
        guard !isSending else { return }
        isSending = true
        sendingError = nil
        defer { isSending = false }

        let trimmedFree = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let orderedCategories = feedbackCategories.filter { selectedCategories.contains($0) }
        let feedback = Feedback.current(
            categories: orderedCategories,
            freeText: trimmedFree.isEmpty ? nil : trimmedFree)
        let ok = await feedbackChannel.send(feedback)
        if ok {
            dismiss()
        } else {
            sendingError = String(localized: "メールアプリを設定してから送ってください。")
        }
    }

    // MARK: - Buttons

    private enum ButtonRole { case yes, no }

    private func primaryButton(_ title: String,
                               role: ButtonRole,
                               isEnabled: Bool = true,
                               showsProgress: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if showsProgress {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(Self.FONT_BODY.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(role == .yes ? Self.COLOR_ACCENT : Self.COLOR_CARD,
                        in: RoundedRectangle(cornerRadius: Self.RADIUS_CARD))
            .foregroundStyle(role == .yes ? Color.white : Self.COLOR_INK)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Self.FONT_BODY.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Self.COLOR_CARD, in: RoundedRectangle(cornerRadius: Self.RADIUS_CARD))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.RADIUS_CARD)
                        .strokeBorder(Self.COLOR_INK_SOFT.opacity(0.25), lineWidth: 1))
                .foregroundStyle(Self.COLOR_INK)
        }
        .buttonStyle(.plain)
    }

    private func tertiaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Self.FONT_CAPTION)
                .foregroundStyle(Self.COLOR_INK_SOFT)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
