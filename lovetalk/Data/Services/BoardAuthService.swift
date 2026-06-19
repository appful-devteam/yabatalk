import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

// MARK: - Board Auth Service
/// 掲示板機能の認証管理（Firebase Auth）
@MainActor
final class BoardAuthService: ObservableObject {
    static let shared = BoardAuthService()

    @Published var currentUser: BoardUser?
    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    /// Apple Sign-In後に新規アカウントと判定された場合にtrue
    @Published var needsProfileSetup: Bool = false

    /// Apple IDなどでサインイン済み（匿名ではない）
    var hasRealAccount: Bool {
        guard let user = currentUser else { return false }
        return !user.isAnonymous
    }

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private init() {
        listenToAuthState()
    }

    // MARK: - Auth State Listener

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user {
                    self?.currentUser = BoardUser(firebaseUser: user)
                    self?.isSignedIn = true
                    print("[BoardAuth] state-listener: signed-in uid=\(user.uid) anon=\(user.isAnonymous)")
                    // 別アプリ (LINE↔IG) でブックマーク・テーマ部屋参加が変わっていれば取り込む
                    await BoardBookmarkService.shared.syncFromFirestore()
                } else {
                    self?.currentUser = nil
                    self?.isSignedIn = false
                    print("[BoardAuth] state-listener: signed-out")
                }
            }
        }
    }

    // MARK: - Anonymous Sign In

    func signInAnonymously() async {
        // 🔴 復元ガード（リビルド/cold launch 毎ログアウトの修正）:
        // Firebase が Keychain から既存ユーザー(Apple 連携 or 匿名)を復元済みなら、
        // それを採用して新規匿名サインインしない。これが無いと、起動直後に掲示板の
        // ensureSignedIn() が状態リスナー(@Published isSignedIn を非同期で立てる)の発火前に
        // 走り、signInAnonymously() が復元された既存ユーザーを新しい匿名ユーザーで
        // 上書き → 毎回ログアウト扱い & Firebase に匿名アカウントが量産される。
        // Auth.auth().currentUser は復元直後から同期的に参照できるためこれで判定する。
        if let existing = Auth.auth().currentUser {
            currentUser = BoardUser(firebaseUser: existing)
            isSignedIn = true
            print("[BoardAuth] signInAnonymously: reuse restored uid=\(existing.uid) anon=\(existing.isAnonymous)")
            return
        }

        isLoading = true
        error = nil

        do {
            let result = try await Auth.auth().signInAnonymously()
            currentUser = BoardUser(firebaseUser: result.user)
            isSignedIn = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(authorization: ASAuthorization) async {
        print("[BoardAuth] handleAppleSignIn: start")
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8),
              let nonce = currentNonce else {
            print("[BoardAuth] handleAppleSignIn: guard failed (currentNonce=\(currentNonce ?? "nil"))")
            error = "Apple Sign-In failed"
            return
        }

        isLoading = true
        error = nil

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let resultUser: FirebaseAuth.User

            // ゲスト（匿名）ユーザーの場合はアカウントリンク
            if let existingUser = Auth.auth().currentUser, existingUser.isAnonymous {
                print("[BoardAuth] attempting link from anonymous uid=\(existingUser.uid)")
                do {
                    let linkResult = try await existingUser.link(with: firebaseCredential)
                    resultUser = linkResult.user
                    print("[BoardAuth] link success uid=\(resultUser.uid) anon=\(resultUser.isAnonymous)")
                } catch let linkError as NSError {
                    // リンク失敗 → 既存アカウントへ通常サインイン
                    // credentialAlreadyInUse の場合、エラーから更新済み credential を取り出す必要がある
                    print("[BoardAuth] link failed code=\(linkError.code) domain=\(linkError.domain) msg=\(linkError.localizedDescription)")
                    let credentialToUse: AuthCredential
                    if let updated = linkError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                        print("[BoardAuth] using updated credential from error userInfo")
                        credentialToUse = updated
                    } else {
                        credentialToUse = firebaseCredential
                    }
                    let signInResult = try await Auth.auth().signIn(with: credentialToUse)
                    resultUser = signInResult.user
                    print("[BoardAuth] signIn after link-fail success uid=\(resultUser.uid) anon=\(resultUser.isAnonymous)")
                }
            } else {
                let signInResult = try await Auth.auth().signIn(with: firebaseCredential)
                resultUser = signInResult.user
                print("[BoardAuth] direct signIn success uid=\(resultUser.uid) anon=\(resultUser.isAnonymous)")
            }

            currentUser = BoardUser(firebaseUser: resultUser)
            isSignedIn = true

            // 表示名をAppleの名前で更新（初回のみ）
            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !displayName.isEmpty, resultUser.displayName == nil {
                    let changeRequest = resultUser.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try? await changeRequest.commitChanges()
                    currentUser = BoardUser(firebaseUser: Auth.auth().currentUser ?? resultUser)
                }
            }

            // Firestoreにプロフィールが存在しなければ新規アカウント
            let hasProfile = await BoardFirestoreService.shared.hasExistingProfile(userId: resultUser.uid)
            needsProfileSetup = !hasProfile
            print("[BoardAuth] handleAppleSignIn done isSignedIn=\(isSignedIn) anon=\(currentUser?.isAnonymous ?? true) needsProfileSetup=\(needsProfileSetup)")
        } catch {
            print("[BoardAuth] handleAppleSignIn caught error: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Apple Sign-In用のnonce生成
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isSignedIn = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// プロフィール設定完了前にキャンセルした場合、Firebaseアカウントを削除してログアウト
    /// 作成直後のため再認証不要で delete() が成功する
    func cancelAccountSetup() async {
        guard let user = Auth.auth().currentUser else {
            signOut()
            return
        }
        do {
            try await user.delete()
        } catch {
            print("[BoardAuth] Failed to delete account on cancel: \(error.localizedDescription)")
        }
        currentUser = nil
        isSignedIn = false
        needsProfileSetup = false
    }

    // MARK: - Delete Account

    /// Apple再認証 → Firestoreデータ削除 → Firebase Authアカウント削除
    func reauthenticateAndDeleteAccount(authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw DeleteAccountError.reauthFailed
        }

        guard let user = Auth.auth().currentUser else {
            throw DeleteAccountError.noUser
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        // 1) 再認証
        try await user.reauthenticate(with: firebaseCredential)

        // 2) Firestoreデータ削除
        await BoardFirestoreService.shared.deleteAllUserData(userId: user.uid)

        // 3) Firebase Authアカウント削除（再認証済みなので成功する）
        try await user.delete()

        currentUser = nil
        isSignedIn = false
    }

    enum DeleteAccountError: LocalizedError {
        case reauthFailed
        case noUser

        var errorDescription: String? {
            switch self {
            case .reauthFailed: return "Re-authentication failed"
            case .noUser: return "No signed-in user"
            }
        }
    }

    // MARK: - Update Display Name

    func updateDisplayName(_ name: String) async {
        guard let user = Auth.auth().currentUser else { return }

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        do {
            try await changeRequest.commitChanges()
            currentUser = BoardUser(firebaseUser: Auth.auth().currentUser ?? user)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            // SecRandomCopyBytes 失敗時はUUIDベースのフォールバック
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Board User

struct BoardUser: Identifiable {
    let id: String
    let displayName: String
    let email: String?
    let isAnonymous: Bool

    init(firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.displayName = firebaseUser.displayName ?? String(localized: "ゲスト", bundle: LanguageManager.appBundle)
        self.email = firebaseUser.email
        self.isAnonymous = firebaseUser.isAnonymous
    }
}
