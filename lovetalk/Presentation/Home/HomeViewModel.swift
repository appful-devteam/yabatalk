import Foundation
import SwiftUI

// MARK: - Home View Model
@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isImporting = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false

    // MARK: - Dependencies
    private let importService = FileImportService()

    // MARK: - Methods

    /// ファイルインポート処理
    func importFile(from url: URL) async -> ChatSession? {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await importService.importFile(from: url)

            // パース成功(本文は送らず件数のみ)
            AnalyticsManager.shared.fileParsed(
                participantCount: session.participants.count,
                messageCount: session.totalMessageCount
            )

            // 参加者数チェック（2〜10人）
            guard session.participants.count >= 2 else {
                AnalyticsManager.shared.importError(.parseError)
                errorMessage = String(localized: "参加者が2人以上のトークを選択してください。", bundle: LanguageManager.appBundle)
                showingError = true
                isLoading = false
                return nil
            }

            guard session.participants.count <= 10 else {
                AnalyticsManager.shared.importError(.tooManyParticipants)
                errorMessage = String(localized: "10人以下のトークのみ解析できます。参加者数: \(session.participants.count)人", bundle: LanguageManager.appBundle)
                showingError = true
                isLoading = false
                ErrorTracker.record(
                    context: "file_import",
                    errorType: "too_many_participants",
                    message: "参加者数: \(session.participants.count)",
                    metadata: [
                        "participant_count": session.participants.count,
                        "participant_names": session.participants.map(\.name),
                        "total_messages": session.totalMessageCount,
                        "filename": url.lastPathComponent
                    ]
                )
                return nil
            }

            // メッセージ数確認
            guard session.totalMessageCount >= Constants.Analysis.minimumMessagesRequired else {
                AnalyticsManager.shared.importError(.insufficientMessages)
                errorMessage = String(localized: "メッセージ数が少なすぎます（\(session.totalMessageCount)件）。最低\(Constants.Analysis.minimumMessagesRequired)件必要です。", bundle: LanguageManager.appBundle)
                showingError = true
                isLoading = false
                ErrorTracker.record(
                    context: "file_import",
                    errorType: "insufficient_messages",
                    message: "メッセージ数: \(session.totalMessageCount)",
                    metadata: [
                        "message_count": session.totalMessageCount,
                        "minimum_required": Constants.Analysis.minimumMessagesRequired,
                        "filename": url.lastPathComponent
                    ]
                )
                return nil
            }

            isLoading = false
            return session

        } catch let error as FileImportError {
            AnalyticsManager.shared.importError(.parseError)
            errorMessage = error.localizedDescription
            showingError = true
            isLoading = false
            ErrorTracker.record(
                context: "file_import",
                errorType: "file_import_error",
                message: error.localizedDescription,
                metadata: ["filename": url.lastPathComponent]
            )
            return nil
        } catch {
            AnalyticsManager.shared.importError(.parseError)
            errorMessage = String(localized: "ファイルの読み込みに失敗しました", bundle: LanguageManager.appBundle)
            showingError = true
            isLoading = false
            ErrorTracker.record(
                context: "file_import",
                errorType: "unknown_error",
                message: error.localizedDescription,
                metadata: ["filename": url.lastPathComponent]
            )
            return nil
        }
    }

    func dismissError() {
        showingError = false
        errorMessage = nil
    }

    /// サンプルデータをインポート（審査用）
    func importSampleData() async -> ChatSession? {
        isLoading = true
        errorMessage = nil

        do {
            // バンドルからサンプルファイルを読み込み
            guard let url = Bundle.main.url(forResource: "[LINE] Keinaとのトーク", withExtension: "txt") else {
                errorMessage = String(localized: "サンプルデータが見つかりませんでした", bundle: LanguageManager.appBundle)
                showingError = true
                isLoading = false
                return nil
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            let session = try importService.importFromString(content, title: "[LINE] Keinaとのトーク.txt")

            isLoading = false
            return session

        } catch {
            errorMessage = String(localized: "サンプルデータの読み込みに失敗しました", bundle: LanguageManager.appBundle)
            showingError = true
            isLoading = false
            return nil
        }
    }
}
