import SwiftUI
import CryptoKit

// MARK: - Image Cache (memory + disk)

/// 二段キャッシュ:
/// 1) メモリ (NSCache) — 最速、アプリ生存中のみ
/// 2) ディスク (Caches/ImageCache) — アプリ再起動・低メモリ後も生き残る
///
/// 元実装はメモリキャッシュのみだったため、再起動・バックグラウンド復帰のたびに
/// 全画像を再ダウンロードしていた (= Firebase Cloud Storage の egress 課金が膨れる主因)。
final class ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let diskQueue = DispatchQueue(label: "ImageCache.disk", qos: .utility)

    /// ディスクキャッシュの上限 (これを超えたら古い順に削除)。
    private let diskCacheBudget: Int = 500 * 1024 * 1024  // 500 MB

    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100MB

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // 起動時に容量を超えてたら掃除 (バックグラウンドで)
        diskQueue.async { [weak self] in
            self?.trimDiskCacheIfNeeded()
        }
    }

    // MARK: Get

    func get(_ url: URL) -> UIImage? {
        // 1) メモリ
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        // 2) ディスク
        let path = diskCacheURL.appendingPathComponent(diskKey(for: url))
        guard fileManager.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else {
            return nil
        }
        // メモリにも昇格 (次回はメモリヒット)
        memoryCache.setObject(image, forKey: url as NSURL, cost: data.count)
        // 最終アクセス時刻を更新 (LRU 風の trimming に使う)
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: path.path)
        return image
    }

    // MARK: Set

    /// `data` には URL からダウンロードしたバイト列をそのまま渡すこと (再エンコードしない)。
    /// 再エンコードすると CPU と容量を無駄にするうえ、可逆では無いので画質も落ちる。
    func set(_ image: UIImage, data: Data, for url: URL) {
        // メモリ: 実バイト数をコストに使う (元実装は jpegData(compressionQuality:1) を毎回生成してたので激重だった)
        memoryCache.setObject(image, forKey: url as NSURL, cost: data.count)
        // ディスク: 非同期で書き込み
        let path = diskCacheURL.appendingPathComponent(diskKey(for: url))
        diskQueue.async {
            try? data.write(to: path, options: .atomic)
        }
    }

    // MARK: Prefetch

    /// 複数 URL を並列に取得してキャッシュに乗せる。すでにキャッシュがあるものはスキップ。
    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                guard get(url) == nil else { continue }
                group.addTask { [weak self] in
                    guard let self,
                          let (data, _) = try? await URLSession.shared.data(from: url),
                          let image = UIImage(data: data) else { return }
                    self.set(image, data: data, for: url)
                }
            }
        }
    }

    // MARK: Disk key

    /// URL を SHA-256 ハッシュにしてファイル名にする (パス安全 / 衝突回避)。
    private func diskKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Disk trim (LRU-ish)

    private func trimDiskCacheIfNeeded() {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let infos: [(url: URL, size: Int, modified: Date)] = entries.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            let modified = values?.contentModificationDate ?? .distantPast
            return (url, size, modified)
        }

        let total = infos.reduce(0) { $0 + $1.size }
        guard total > diskCacheBudget else { return }

        // 古い順に消して predef budget の 80% まで縮める
        let target = Int(Double(diskCacheBudget) * 0.8)
        var current = total
        for info in infos.sorted(by: { $0.modified < $1.modified }) {
            if current <= target { break }
            try? fileManager.removeItem(at: info.url)
            current -= info.size
        }
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
                    .onAppear { loadImage() }
            }
        }
    }

    private func loadImage() {
        guard let url, !isLoading else { return }

        if let cached = ImageCache.shared.get(url) {
            image = cached
            return
        }

        isLoading = true
        Task.detached(priority: .utility) {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run { isLoading = false }
                return
            }
            ImageCache.shared.set(uiImage, data: data, for: url)
            await MainActor.run {
                image = uiImage
                isLoading = false
            }
        }
    }
}
