//
//  ShareViewController.swift
//  LineExportShare
//
//  Created by 岡本隆誠 on 1/10/26.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.appful.yabatalk"

    override func viewDidLoad() {
        super.viewDidLoad()
        // 透明な背景
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedFile()
    }

    private func handleSharedFile() {
        guard let extensionContext = extensionContext,
              let inputItem = extensionContext.inputItems.first as? NSExtensionItem,
              let attachments = inputItem.attachments else {
            close()
            return
        }

        for attachment in attachments {
            // テキストファイル
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                    self?.processItem(item, error: error)
                }
                return
            }
            // ファイルURL
            if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                    self?.processItem(item, error: error)
                }
                return
            }
            // URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                    self?.processItem(item, error: error)
                }
                return
            }
            // Data
            if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { [weak self] item, error in
                    self?.processItem(item, error: error)
                }
                return
            }
        }

        close()
    }

    private func processItem(_ item: Any?, error: Error?) {
        guard error == nil else {
            close()
            return
        }

        var content: String?

        if let url = item as? URL {
            content = try? String(contentsOf: url, encoding: .utf8)
        } else if let text = item as? String {
            content = text
        } else if let data = item as? Data {
            content = String(data: data, encoding: .utf8)
        }

        if let content = content {
            saveToAppGroup(content: content)
            openMainApp()
        } else {
            close()
        }
    }

    private func saveToAppGroup(content: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let fileURL = containerURL.appendingPathComponent("shared_line_export.txt")

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            UserDefaults(suiteName: appGroupID)?.set(true, forKey: "hasSharedContent")
            UserDefaults(suiteName: appGroupID)?.set(Date(), forKey: "sharedContentDate")
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private func openMainApp() {
        let url = URL(string: "lovetalk://import")!

        // iOS 18以降の方法
        if let scene = view.window?.windowScene {
            scene.open(url, options: nil) { [weak self] success in
                self?.close()
            }
        } else {
            // フォールバック: responder chainを使う
            var responder: UIResponder? = self
            while let r = responder {
                if let application = r as? UIApplication {
                    application.open(url)
                    break
                }
                responder = r.next
            }
            close()
        }
    }

    private func close() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
