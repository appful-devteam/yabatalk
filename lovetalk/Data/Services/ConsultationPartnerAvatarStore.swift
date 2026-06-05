import Foundation
import UIKit

enum ConsultationPartnerAvatarStore {
    private static let keyPrefix = "consultation.partner-avatar."
    private static let customImageKeyPrefix = "consultation.partner-custom-image."
    private static let defaults = UserDefaults.standard

    static let availableAvatarNames: [String] = (1...16).map {
        String(format: "consult_partner_meromaru_%02d", $0)
    }

    static func avatarName(for sessionId: UUID?) -> String? {
        guard let sessionId else { return nil }

        let key = storageKey(for: sessionId)
        if let stored = defaults.string(forKey: key),
           availableAvatarNames.contains(stored) {
            return stored
        }

        let fallback = defaultAvatarName(for: sessionId)
        defaults.set(fallback, forKey: key)
        return fallback
    }

    static func setAvatarName(_ avatarName: String, for sessionId: UUID?) {
        guard let sessionId, availableAvatarNames.contains(avatarName) else { return }
        defaults.set(avatarName, forKey: storageKey(for: sessionId))
        // ユーザー画像を選んでいた場合は、プリセット選択で上書き解除。
        defaults.removeObject(forKey: customImageKey(for: sessionId))
    }

    static func randomAvatarName(excluding current: String? = nil) -> String {
        let pool = availableAvatarNames.filter { $0 != current }
        return pool.randomElement() ?? availableAvatarNames.first ?? "char_meromaru_3d"
    }

    // MARK: - Custom (user-picked) image support

    /// ユーザーが選んだ独自画像 (PhotosPicker から) のバイナリ。設定すると
    /// プリセット avatar より優先表示される。
    static func customImageData(for sessionId: UUID?) -> Data? {
        guard let sessionId else { return nil }
        return defaults.data(forKey: customImageKey(for: sessionId))
    }

    static func setCustomImageData(_ data: Data?, for sessionId: UUID?) {
        guard let sessionId else { return }
        if let data {
            defaults.set(data, forKey: customImageKey(for: sessionId))
        } else {
            defaults.removeObject(forKey: customImageKey(for: sessionId))
        }
    }

    static func hasCustomImage(for sessionId: UUID?) -> Bool {
        customImageData(for: sessionId) != nil
    }

    private static func customImageKey(for sessionId: UUID) -> String {
        customImageKeyPrefix + sessionId.uuidString
    }

    private static func storageKey(for sessionId: UUID) -> String {
        keyPrefix + sessionId.uuidString
    }

    private static func defaultAvatarName(for sessionId: UUID) -> String {
        let index = sessionId.uuidString.unicodeScalars
            .map(\.value)
            .reduce(0) { partialResult, scalarValue in
                (partialResult * 31 + Int(scalarValue)) % availableAvatarNames.count
            }
        return availableAvatarNames[index]
    }
}
