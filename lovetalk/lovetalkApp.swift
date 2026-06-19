//
//  lovetalkApp.swift
//  lovetalk
//
//  Created by 岡本隆誠 on 1/7/26.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct lovetalkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var fileImportManager = FileImportManager.shared

    init() {
        // Google Mobile Ads SDKの初期化
        MobileAds.shared.start()
        // App Open広告を事前ロード
        AppOpenAdManager.shared.loadAd()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .modifier(DismissKeyboardOnTap())
                .onOpenURL { url in
                    fileImportManager.handleIncomingFile(url: url)
                }
                .task {
                    // ATT（トラッキング許可）の要求は RootView 側で「オンボーディングの全画面カバーが
                    // 閉じ、シーンが active になってから」行う（requestATTIfReady）。ここで起動直後に
                    // 要求するとオンボの fullScreenCover と衝突してダイアログが無音で出ず、2.1 リジェクト
                    // の原因になっていた。広告ゲートの更新も ATT 応答後に RootView 側で行う。
                    await AdGate.shared.refresh()
                    if AdGate.shared.adsEnabled {
                        AppOpenAdManager.shared.loadAd()
                    }
                }
        }
        .modelContainer(SwiftDataContainer.shared.container)
    }

}

// MARK: - File Import Manager
@MainActor
final class FileImportManager: ObservableObject {
    static let shared = FileImportManager()

    @Published var pendingFileURL: URL?
    @Published var hasPendingFile = false

    private init() {}

    private let appGroupID = "group.appful.yabatalk"

    func handleIncomingFile(url: URL) {
        // Share Extensionからのカスタムスキーム
        if url.scheme == "lovetalk" && url.host == "import" {
            handleSharedFileFromExtension()
            return
        }

        // ファイルURLでない場合は処理しない
        guard url.isFileURL else {
            print("Not a file URL: \(url)")
            return
        }

        // Security-Scoped Resourceへのアクセスを開始
        // 重要: 必ずstartを呼び、成功した場合のみstopを呼ぶ
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()

        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // NSFileCoordinatorを使用してファイルに安全にアクセス
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { coordinatedURL in
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "imported_\(UUID().uuidString).txt"
                let destinationURL = documentsPath.appendingPathComponent(fileName)

                // Dataとして読み込む（エンコーディング問題を回避）
                let data = try Data(contentsOf: coordinatedURL)

                // UTF-8でデコードを試みる、失敗したらShift-JISなど他のエンコーディングを試す
                var content: String?
                if let utf8String = String(data: data, encoding: .utf8) {
                    content = utf8String
                } else if let shiftJISString = String(data: data, encoding: .shiftJIS) {
                    content = shiftJISString
                } else if let asciiString = String(data: data, encoding: .ascii) {
                    content = asciiString
                }

                guard let fileContent = content else {
                    print("Could not decode file content")
                    return
                }

                // 新しいファイルとして保存
                try fileContent.write(to: destinationURL, atomically: true, encoding: .utf8)

                DispatchQueue.main.async {
                    self.processPendingFile(url: destinationURL)
                }
            } catch {
                print("File coordination error: \(error)")
            }
        }

        if let error = error {
            print("NSFileCoordinator error: \(error)")
        }
    }

    /// Share Extensionから共有されたファイルをApp Groupから読み込む
    private func handleSharedFileFromExtension() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("App Group container not accessible: \(appGroupID)")
            ErrorTracker.record(
                context: "file_import",
                errorType: "app_group_unavailable",
                message: "containerURL returned nil for \(appGroupID)"
            )
            return
        }

        let sharedFileURL = containerURL.appendingPathComponent("shared_line_export.txt")

        guard FileManager.default.fileExists(atPath: sharedFileURL.path) else {
            print("Shared file not found at: \(sharedFileURL.path)")
            return
        }

        // ドキュメントディレクトリにコピー
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "imported_\(UUID().uuidString).txt"
            let destinationURL = documentsPath.appendingPathComponent(fileName)

            try FileManager.default.copyItem(at: sharedFileURL, to: destinationURL)

            // 共有ファイルを削除
            try? FileManager.default.removeItem(at: sharedFileURL)
            UserDefaults(suiteName: appGroupID)?.set(false, forKey: "hasSharedContent")

            processPendingFile(url: destinationURL)
        } catch {
            // コピー失敗時は直接読み込みを試みる
            processPendingFile(url: sharedFileURL)
        }
    }

    private func processPendingFile(url: URL) {
        pendingFileURL = url
        hasPendingFile = true

        // 通知を送信してHomeViewに伝える
        NotificationCenter.default.post(
            name: .didReceiveFileFromShare,
            object: nil,
            userInfo: ["url": url]
        )
    }

    func clearPendingFile() {
        pendingFileURL = nil
        hasPendingFile = false
    }
}

// MARK: - Dismiss Keyboard on Tap
/// UIKitベースのタップジェスチャーでキーボードを閉じる（ボタン等のタップを妨げない）
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissView())
    }
}

private struct KeyboardDismissView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dismiss))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        @objc func dismiss() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let didReceiveFileFromShare = Notification.Name("didReceiveFileFromShare")
}
