import UIKit

/// アップロード前に画像を縮小・JPEG 化するユーティリティ。
/// クライアント側で確実にサイズを落とし、R2 egress (= ダウンロード帯域料金) を最小化するためのもの。
enum ImageCompressor {

    /// 投稿/返信画像用 (長辺 1600px, JPEG quality 0.7)
    static func compressForPost(_ data: Data) -> Data? {
        return compress(data, longEdge: 1600, quality: 0.7)
    }

    /// プロフィール画像用 (長辺 512px, JPEG quality 0.8)
    static func compressForProfile(_ data: Data) -> Data? {
        return compress(data, longEdge: 512, quality: 0.8)
    }

    /// 任意のサイズ・品質で JPEG にダウンサイズ。
    /// HEIC/PNG 入力でも JPEG として normalize して返す。
    /// 元画像が longEdge より小さい場合はリサイズせずに JPEG 再エンコードのみ行う。
    static func compress(_ data: Data, longEdge: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = resize(image, longEdge: longEdge)
        return resized.jpegData(compressionQuality: quality)
    }

    private static func resize(_ image: UIImage, longEdge: CGFloat) -> UIImage {
        let size = image.size
        let maxEdge = max(size.width, size.height)
        guard maxEdge > longEdge else { return image }

        let scale = longEdge / maxEdge
        let newSize = CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1                     // 等倍で書き出す (デフォルトは 2x で無駄に大きくなる)
        format.opaque = true                 // JPEG なのでアルファ不要
        format.preferredRange = .standard    // sRGB 8bit

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
