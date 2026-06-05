import SwiftUI

/// 匿名投稿用に、めろまるとあいまつのペア画像 (mero_pair_01〜16) から
/// 決定論的にひとつ選んで表示する。`seed` (= postId 等) のハッシュをインデックスに
/// 使うので、同じ投稿は何度開いても同じ画像になる。
enum AnonymousAvatarPicker {
    /// アセット内のペア画像数。`mero_pair_01` から始まる連番想定。
    private static let pairImageCount = 16

    /// `seed` から再現性のある 1〜pairImageCount のインデックスを返し、
    /// `mero_pair_NN` 形式のアセット名を返す。
    static func imageName(forSeed seed: String) -> String {
        let hash = seed.unicodeScalars.reduce(into: UInt64(5_381)) { acc, scalar in
            acc = acc &* 33 &+ UInt64(scalar.value)
        }
        let index = Int(hash % UInt64(pairImageCount)) + 1
        return String(format: "mero_pair_%02d", index)
    }
}
