import SwiftUI
import AuthenticationServices

// MARK: - Board Sign In View
struct BoardSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = BoardAuthService.shared
    @State private var showProfileSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                LinearGradient(
                    colors: [MeloColors.Dark.bgElevated, MeloColors.Dark.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // ヘッダー
                    VStack(spacing: 12) {
                        Image("mero_pair_08")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)

                        Text(String(localized: "サインインして投稿しよう", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(22))
                            .foregroundColor(MeloColors.Dark.textPrimary)

                        Text(String(localized: "投稿やリアクションにはサインインが必要です", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruOrFallback(13))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // サインインボタン
                    VStack(spacing: 12) {
                        // Apple Sign In
                        SignInWithAppleButton(.signIn) { request in
                            let hashedNonce = authService.prepareAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                Task {
                                    await authService.handleAppleSignIn(authorization: authorization)
                                    if authService.isSignedIn {
                                        if authService.needsProfileSetup {
                                            showProfileSetup = true
                                        } else {
                                            dismiss()
                                        }
                                    }
                                }
                            case .failure(let error):
                                print("[Board] Apple Sign-In failed: \(error)")
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(25)
                        .padding(.horizontal, 32)

                        // 閲覧だけする
                        Button {
                            HapticManager.light()
                            dismiss()
                        } label: {
                            Text(String(localized: "閲覧だけにする", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruOrFallback(13))
                                .foregroundColor(MeloColors.Dark.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }

                    // 注意書き
                    Text(String(localized: "サインインすることで利用規約に同意したものとみなされます", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruRegular(10))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer().frame(height: 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showProfileSetup, onDismiss: {
                dismiss()
            }) {
                ProfileSetupView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BoardSignInView()
}
