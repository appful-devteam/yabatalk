import Foundation
import FirebaseAuth

/// Cloudflare R2 への画像アップロードを Worker 経由で行う薄いラッパ。
/// 認証は Worker 側で Firebase ID トークンを検証 → R2 PUT。
/// 公開読み取りは `images.merotalk.com` の R2 カスタムドメインから直接配信されるので、
/// このクラスはアップロードと削除のみ提供する。
actor R2StorageService {
    static let shared = R2StorageService()

    enum UploadType: String {
        case post
        case reply
        case profile
        case roomIcon = "room_icon"
        case roomHeader = "room_header"
    }

    enum R2Error: LocalizedError {
        case notAuthenticated
        case invalidResponse
        case uploadFailed(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "サインインが必要です"
            case .invalidResponse:
                return "サーバーから不正なレスポンスを受信しました"
            case .uploadFailed(let status, let message):
                return "画像アップロード失敗 (\(status)): \(message)"
            }
        }
    }

    /// Worker のベース URL。yabatalk + darkmerotalk(ダークめろとーく) 共有の R2 アップローダ。
    /// darkmerotalk Firebase トークンを検証して darkmerotalk-board-images バケットへ PUT する。
    private let baseURL = URL(string: "https://darkmerotalk-r2-uploader.appful.workers.dev")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Upload

    /// 画像を R2 に PUT し、公開 URL と key を返す。
    /// `data` は UI 層であらかじめ圧縮済みのバイトを渡すこと (本サービスでは再圧縮しない)。
    func uploadImage(
        data: Data,
        type: UploadType,
        ownerId: String,
        contentType: String = "image/jpeg"
    ) async throws -> (url: URL, key: String) {
        let token = try await currentIDToken()

        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(type.rawValue, forHTTPHeaderField: "X-Upload-Type")
        request.setValue(ownerId, forHTTPHeaderField: "X-Owner-Id")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: responseData, encoding: .utf8) ?? "<no body>"
            throw R2Error.uploadFailed(status: httpResponse.statusCode, message: message)
        }

        struct UploadResponse: Decodable {
            let url: String
            let key: String
        }
        let decoded = try JSONDecoder().decode(UploadResponse.self, from: responseData)
        guard let url = URL(string: decoded.url) else {
            throw R2Error.invalidResponse
        }
        return (url, decoded.key)
    }

    // MARK: - Delete

    /// 指定した key の画像を R2 から削除する (アップロード者本人のみ許可される)。
    func deleteImage(key: String) async throws {
        let token = try await currentIDToken()

        var components = URLComponents(
            url: baseURL.appendingPathComponent("image"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = components.url else { throw R2Error.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (responseData, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw R2Error.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: responseData, encoding: .utf8) ?? "<no body>"
            throw R2Error.uploadFailed(status: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - Helpers

    /// 公開 URL から key (`posts/.../uuid.jpg` 等) を逆算する。
    /// darkmerotalk 共有 R2 の公開配信 (pub-xxxx.r2.dev) のみ対象。
    /// 旧 Firebase Storage / 旧 images.merotalk.com URL には nil を返す (= dark R2 から削除しない)。
    nonisolated func keyFromPublicURL(_ urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.hasSuffix(".r2.dev") else {
            return nil
        }
        let path = url.path
        guard path.hasPrefix("/") else { return nil }
        let key = String(path.dropFirst())
        return key.removingPercentEncoding ?? key
    }

    private func currentIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw R2Error.notAuthenticated
        }
        return try await user.getIDToken()
    }
}
