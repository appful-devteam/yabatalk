import Foundation
import SwiftData

/// 既存ユーザー向け: セッション統合・誤マージ分離
@MainActor
final class SessionMergeService {
    // MARK: - 誤マージ分離（partnerParticipantが異なる結果を別セッションに分離）
    static func splitMismergedSessions(modelContext: ModelContext) {
        let splitKey = "hasPerformedSessionSplit_v1"
        guard !UserDefaults.standard.bool(forKey: splitKey) else { return }

        let descriptor = FetchDescriptor<StoredChatSession>()
        guard let allSessions = try? modelContext.fetch(descriptor) else {
            UserDefaults.standard.set(true, forKey: splitKey)
            return
        }

        var didSplit = false

        for session in allSessions {
            guard let results = session.analysisResults, results.count > 1 else { continue }

            // partnerParticipant でグループ化
            var grouped: [String: [StoredAnalysisResult]] = [:]
            for result in results {
                grouped[result.partnerParticipant, default: []].append(result)
            }

            // 1種類のpartnerなら問題なし
            guard grouped.count > 1 else { continue }

            // 最多の結果を持つpartnerを現セッションに残し、残りを分離
            let sortedGroups = grouped.sorted { $0.value.count > $1.value.count }

            for (partnerName, orphanResults) in sortedGroups.dropFirst() {
                // 新しいセッションを作成
                let newSession = StoredChatSession(
                    id: UUID(),
                    title: String(localized: "\(partnerName)とのトーク", bundle: LanguageManager.appBundle),
                    participantNames: [orphanResults.first?.selfParticipant ?? "", partnerName],
                    messageCount: orphanResults.first?.totalMessages ?? 0,
                    importedAt: orphanResults.map(\.analyzedAt).max() ?? Date(),
                    firstMessageDate: orphanResults.first?.firstMessageDate,
                    lastMessageDate: orphanResults.first?.lastMessageDate
                )
                modelContext.insert(newSession)

                // 結果を新セッションに移動
                for result in orphanResults {
                    result.sessionId = newSession.id
                    result.session = newSession
                }

                didSplit = true
            }
        }

        if didSplit {
            do {
                try modelContext.save()
            } catch {
                print("[SessionMergeService] 分離保存失敗: \(error)")
                return // 保存失敗時は完了フラグを立てない
            }
        }
        UserDefaults.standard.set(true, forKey: splitKey)
    }

    // MARK: - 同名セッション統合
    static func mergeIfNeeded(modelContext: ModelContext) {
        let key = Constants.StorageKeys.hasPerformedSessionMerge
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let descriptor = FetchDescriptor<StoredChatSession>()
        guard let allSessions = try? modelContext.fetch(descriptor),
              allSessions.count > 1 else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        // title + 参加者名でグループ化（同一人物のみマージ）
        struct SessionKey: Hashable {
            let title: String
            let participants: Set<String>
        }
        var grouped: [SessionKey: [StoredChatSession]] = [:]
        for session in allSessions {
            let key = SessionKey(title: session.title, participants: Set(session.participantNames))
            grouped[key, default: []].append(session)
        }

        var didMerge = false

        for (_, sessions) in grouped where sessions.count > 1 {
            // 最古のセッションをprimaryに
            let sorted = sessions.sorted { $0.importedAt < $1.importedAt }
            let primary = sorted[0]

            for duplicate in sorted.dropFirst() {
                // resultsをprimaryに移動
                if let results = duplicate.analysisResults {
                    for result in results {
                        result.sessionId = primary.id
                        result.session = primary
                    }
                }
                // summariesをprimaryに移動
                if let summaries = duplicate.monthlySummaries {
                    for summary in summaries {
                        summary.session = primary
                    }
                }
                // 最新のchatSessionDataを保持
                if duplicate.importedAt > primary.importedAt {
                    if let data = duplicate.chatSessionData {
                        primary.chatSessionData = data
                    }
                    primary.importedAt = duplicate.importedAt
                    primary.messageCount = duplicate.messageCount
                    primary.participantNames = duplicate.participantNames
                    primary.firstMessageDate = duplicate.firstMessageDate
                    primary.lastMessageDate = duplicate.lastMessageDate
                }
                // cascade削除を回避するためrelationshipを空にしてから削除
                duplicate.analysisResults = []
                duplicate.monthlySummaries = []
                modelContext.delete(duplicate)
                didMerge = true
            }
        }

        if didMerge {
            do {
                try modelContext.save()
            } catch {
                print("[SessionMergeService] マージ保存失敗: \(error)")
                return // 保存失敗時はマージ完了フラグを立てない
            }
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}
