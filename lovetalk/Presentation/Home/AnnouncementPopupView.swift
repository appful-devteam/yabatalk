import SwiftUI

struct AnnouncementPopupView: View {
    let announcement: InAppAnnouncement
    let onDismiss: (Bool) -> Void // dontShowAgain
    let onPrimaryAction: () -> Void

    @State private var dontShowAgain = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Card
            cardContent
                .scaleEffect(showContent ? 1.0 : 0.8)
                .opacity(showContent ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Close button
            closeButton

            // Image
            imageSection

            // Title & Message
            textSection

            // Buttons
            buttonSection

            // Don't show again
            dontShowAgainSection
        }
        .padding(.bottom, 20)
        .background(MeloColors.Dark.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 32)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(MeloColors.Dark.textSecondary.opacity(0.6))
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
    }

    // MARK: - Image

    @ViewBuilder
    private var imageSection: some View {
        if let imageName = announcement.imageName, !imageName.isEmpty {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 180)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 8) {
            Text(announcement.title)
                .font(MeloFonts.zenMaruOrFallback(20))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .multilineTextAlignment(.center)

            Text(announcement.message)
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: 10) {
            // Primary button
            if let primaryTitle = announcement.primaryButtonTitle, !primaryTitle.isEmpty {
                Button {
                    onPrimaryAction()
                } label: {
                    Text(primaryTitle)
                        .font(MeloFonts.zenMaruOrFallback(16))
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MeloColors.Dark.accentGradient)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
            }

            // Secondary button
            if let secondaryTitle = announcement.secondaryButtonTitle, !secondaryTitle.isEmpty {
                Button {
                    dismiss()
                } label: {
                    Text(secondaryTitle)
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                }
            }
        }
        .padding(.bottom, announcement.allowDontShowAgain == true ? 12 : 0)
    }

    // MARK: - Don't Show Again

    @ViewBuilder
    private var dontShowAgainSection: some View {
        if announcement.allowDontShowAgain == true {
            Button {
                dontShowAgain.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(
                            dontShowAgain ? MeloColors.Dark.accent : MeloColors.Dark.textSecondary
                        )

                    Text(String(localized: "今後は表示しない", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(12))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss(dontShowAgain)
        }
    }
}
