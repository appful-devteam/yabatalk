import Foundation
import BackgroundTasks
import SwiftData

// MARK: - Persona Background Service
/// バックグラウンドでペルソナのプロアクティブメッセージを生成するサービス
@MainActor
final class PersonaBackgroundService {
    static let shared = PersonaBackgroundService()
    static let taskIdentifier = "appful.yabatalk.personaMessage"

    private init() {}

    // MARK: - Register Background Task

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
    }

    // MARK: - Schedule Next Background Task

    func scheduleBackgroundTask() {
        // アクティブなチャットの返信分布を参照してスケジュール間隔を決定
        let allChats = PersonaChatViewModel.loadAllChats()
        let activeChat = allChats.values.first { !$0.messages.isEmpty && $0.resolvedSettings.proactiveMessages }
        let delay: TimeInterval
        if let timing = activeChat?.replyTiming {
            delay = timing.generateProactiveDelay()
        } else {
            delay = TimeInterval.random(in: 1800...7200)
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[PersonaBackground] Failed to schedule: \(error)")
        }
    }

    // MARK: - Handle Background Task

    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        // Premium+ チェック
        guard SubscriptionManager.shared.isPremiumPlus else {
            task.setTaskCompleted(success: true)
            return
        }

        // アクティブなペルソナチャットを取得（プロアクティブ有効 & 48時間以内にアクティブ）
        let allChats = PersonaChatViewModel.loadAllChats()
        guard let (_, chat) = allChats.first(where: {
            !$0.value.messages.isEmpty
            && $0.value.resolvedSettings.proactiveMessages
            && !$0.value.isProactiveTimedOut
        }) else {
            task.setTaskCompleted(success: true)
            return
        }

        // 最後のメッセージから十分な時間が経過しているか（分布のP75ベース）
        let minInterval = chat.replyTiming?.p75 ?? 1800
        if let lastMessage = chat.lastMessageAt,
           Date().timeIntervalSince(lastMessage) < minInterval {
            task.setTaskCompleted(success: true)
            scheduleBackgroundTask()
            return
        }

        // データをロード
        let context = await loadContext(for: chat)

        do {
            let responses = try await PersonaChatService.shared.generateProactiveMessage(
                chat: chat,
                partnerMessages: context.partnerMessages,
                allMessages: context.allMessages,
                replyStyle: context.replyStyle,
                selfName: context.selfName,
                relationshipType: chat.resolvedSettings.relationshipType
            )

            // Save messages
            var updatedChat = chat
            for responseText in responses {
                let message = PersonaChatMessage(role: .persona, text: responseText, isRead: false)
                updatedChat.appendMessage(message)
            }

            var allChatsUpdated = PersonaChatViewModel.loadAllChats()
            allChatsUpdated[updatedChat.sessionId.uuidString] = updatedChat
            if let data = try? JSONEncoder().encode(allChatsUpdated) {
                UserDefaults.standard.set(data, forKey: "persona_chats")
            }

            // Send notification with actual message content
            if updatedChat.resolvedSettings.notifications, let lastText = responses.last {
                PersonaNotificationService.shared.sendImmediateNotification(
                    for: updatedChat,
                    messageText: lastText
                )
            }

            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }

        // Schedule next
        scheduleBackgroundTask()
    }

    // MARK: - Load Context

    private struct PersonaContext {
        let partnerMessages: [ChatMessage]
        let allMessages: [ChatMessage]
        let selfName: String
        let replyStyle: ReplyStyleProfile?
    }

    private func loadContext(for chat: PersonaChat) async -> PersonaContext {
        return await Task.detached(priority: .userInitiated) {
            let container = await SwiftDataContainer.shared.container
            let context = ModelContext(container)

            let sessionId = chat.sessionId
            let descriptor = FetchDescriptor<StoredAnalysisResult>(
                predicate: #Predicate<StoredAnalysisResult> { $0.sessionId == sessionId && $0.period == "all" }
            )

            guard let storedResult = try? context.fetch(descriptor).first else {
                return PersonaContext(partnerMessages: [], allMessages: [], selfName: "", replyStyle: nil)
            }

            let analysisResult = storedResult.toAnalysisResult()
            let selfName = analysisResult.selfParticipant

            // Load chat session for messages
            var partnerMessages: [ChatMessage] = []
            var allMessages: [ChatMessage] = []
            let sessionDescriptor = FetchDescriptor<StoredChatSession>(
                predicate: #Predicate<StoredChatSession> { $0.id == sessionId }
            )
            if let storedSession = try? context.fetch(sessionDescriptor).first,
               let data = storedSession.chatSessionData,
               let chatSession = try? JSONDecoder().decode(ChatSession.self, from: data) {
                allMessages = chatSession.messages
                partnerMessages = chatSession.messages.filter {
                    $0.senderName != selfName && $0.eventType == .text
                }
            }

            let replyStyle = analysisResult.replyStyleProfiles?.partnerStyle

            return PersonaContext(
                partnerMessages: partnerMessages,
                allMessages: allMessages,
                selfName: selfName,
                replyStyle: replyStyle
            )
        }.value
    }
}
