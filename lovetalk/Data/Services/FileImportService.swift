import Foundation
import UIKit
import UniformTypeIdentifiers

// MARK: - File Import Service
/// ファイルインポートサービス
final class FileImportService {
    private let parser = LineChatParser()

    // MARK: - Supported Types

    static let supportedTypes: [UTType] = [
        .plainText,
        UTType(filenameExtension: "txt") ?? .plainText
    ]

    // MARK: - Import Methods

    /// URLからファイルを読み込んでパース
    func importFile(from url: URL) async throws -> ChatSession {
        // セキュリティスコープ付きリソースへのアクセス開始
        // 注意: falseが返ってもアクセス可能な場合がある（サンドボックス内のファイルなど）
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()

        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // メモリ警告を監視
        let memoryObserver = MemoryPressureObserver()
        defer { memoryObserver.stop() }

        // ファイル読み込み
        let content: String
        do {
            // まずUTF-8で試行
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Shift-JISで再試行
            do {
                content = try String(contentsOf: url, encoding: .shiftJIS)
            } catch {
                throw FileImportError.encodingError
            }
        }

        guard !memoryObserver.didReceiveWarning else {
            throw FileImportError.outOfMemory
        }

        // パース
        do {
            let session = try parser.parse(content, title: url.lastPathComponent)
            return session
        } catch {
            if memoryObserver.didReceiveWarning {
                throw FileImportError.outOfMemory
            }
            throw FileImportError.parsingError(error.localizedDescription)
        }
    }

    /// 文字列からパース（デバッグ用）
    func importFromString(_ content: String, title: String = "トーク履歴") throws -> ChatSession {
        try parser.parse(content, title: title)
    }
}

// MARK: - File Import Error
enum FileImportError: LocalizedError {
    case accessDenied
    case fileTooLarge(size: Int)
    case encodingError
    case parsingError(String)
    case outOfMemory
    case unknownError

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return String(localized: "ファイルへのアクセスが拒否されました", bundle: LanguageManager.appBundle)
        case .fileTooLarge(let size):
            let sizeInMB = Double(size) / 1024 / 1024
            return String(format: String(localized: "ファイルが大きすぎます（%.1fMB）", bundle: LanguageManager.appBundle), sizeInMB)
        case .encodingError:
            return String(localized: "ファイルの文字コードを認識できませんでした", bundle: LanguageManager.appBundle)
        case .parsingError(let message):
            return String(format: String(localized: "ファイルの解析に失敗しました: %@", bundle: LanguageManager.appBundle), message)
        case .outOfMemory:
            return String(localized: "トーク履歴が大きすぎて処理できませんでした", bundle: LanguageManager.appBundle)
        case .unknownError:
            return String(localized: "不明なエラーが発生しました", bundle: LanguageManager.appBundle)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return String(localized: "ファイルへのアクセス権限を確認してください", bundle: LanguageManager.appBundle)
        case .fileTooLarge:
            return String(localized: "より短い期間のトーク履歴をエクスポートしてください", bundle: LanguageManager.appBundle)
        case .encodingError:
            return String(localized: "LINEの「トーク履歴を送信」機能で出力したファイルを使用してください", bundle: LanguageManager.appBundle)
        case .parsingError:
            return String(localized: "LINEのトーク履歴ファイルか確認してください", bundle: LanguageManager.appBundle)
        case .outOfMemory:
            return String(localized: "LINEで期間を指定してトーク履歴をエクスポートし、より短い期間のデータで再度お試しください", bundle: LanguageManager.appBundle)
        case .unknownError:
            return String(localized: "アプリを再起動して再度お試しください", bundle: LanguageManager.appBundle)
        }
    }
}

// MARK: - Memory Pressure Observer
/// メモリ警告を監視してクラッシュ前に安全に中断するためのオブザーバー
final class MemoryPressureObserver {
    private(set) var didReceiveWarning = false
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.didReceiveWarning = true
        }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    deinit {
        stop()
    }
}
