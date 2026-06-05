import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

/// アプリ内エラーの記録窓口。Crashlytics（クラッシュとして記録）と Analytics（集計用イベント）に
/// 同時に流す。Supabase 移行前の `SupabaseService.sendErrorLog` の置き換え。
enum ErrorTracker {
    /// エラーを記録する。同期メソッド。Crashlytics と Analytics 双方に書き込む。
    /// - Parameters:
    ///   - context: 発生箇所のラベル（例: "gemini_api", "file_import", "analysis"）
    ///   - errorType: エラー種別（例: "rate_limit_exhausted", "parsing_failed"）
    ///   - message: 詳細メッセージ
    ///   - metadata: 追加情報（任意）
    static func record(
        context: String,
        errorType: String,
        message: String,
        metadata: [String: Any]? = nil
    ) {
        // ---- Crashlytics ----
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message,
            "context": context,
            "error_type": errorType
        ]
        if let metadata = metadata,
           let json = try? JSONSerialization.data(withJSONObject: metadata),
           let s = String(data: json, encoding: .utf8) {
            userInfo["metadata"] = s
        }
        let nsError = NSError(domain: context, code: errorTypeHash(errorType), userInfo: userInfo)
        Crashlytics.crashlytics().record(error: nsError)

        // ---- Analytics ----
        // Analytics の制約: パラメータ名 [a-zA-Z0-9_] 40文字以下、文字列値 100文字以下
        var params: [String: Any] = [
            "context": String(context.prefix(40)),
            "error_type": String(errorType.prefix(40)),
            "message": String(message.prefix(100))
        ]
        if let metadata = metadata,
           let json = try? JSONSerialization.data(withJSONObject: metadata),
           let s = String(data: json, encoding: .utf8) {
            params["metadata"] = String(s.prefix(100))
        }
        Analytics.logEvent("error_log", parameters: params)
    }

    /// errorType 文字列を NSError code に安定的にマップ（同種のエラーが同じ code でグルーピングされる）
    private static func errorTypeHash(_ s: String) -> Int {
        var h: UInt32 = 5381
        for byte in s.utf8 {
            h = h &* 33 &+ UInt32(byte)
        }
        return Int(h & 0x7FFFFFFF)
    }
}
