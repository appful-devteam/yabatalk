import SwiftUI
import GoogleMobileAds
import FirebaseRemoteConfig
import os

// MARK: - Ad Gate
/// 広告表示の可否を一元管理するゲート。
///
/// Remote Config の `ads_enabled_yabatalk`(デフォルト false) を読み、`true` になるまで広告を出さない。
/// 審査・公開前は false（広告なし）、ストア公開後に Console で true に切り替えて広告 ON。
///
/// ⚠️ キーは共有の `ads_enabled` ではなく **`ads_enabled_yabatalk`**。
/// 同一 Firebase プロジェクト(darkmerotalk)を darkめろとーくと共有しており、RemoteConfig は
/// プロジェクト単位のため、アプリ別キーで独立に ON/OFF 制御する
/// （darkめろとーく=`ads_enabled` / やばトーク=`ads_enabled_yabatalk`）。
///
/// 既存の `SubscriptionManager.shared` と同じ ObservableObject singleton 流儀。
/// `AdBannerContainer` が `@StateObject = AdGate.shared` で監視し、フラグ変化で再描画する。
final class AdGate: ObservableObject {
    static let shared = AdGate()

    /// 広告を表示してよいか（Remote Config の ads_enabled_yabatalk）。
    @Published private(set) var adsEnabled: Bool = false

    /// やばトーク専用キー（darkめろとーくの `ads_enabled` と独立）。
    private let key = "ads_enabled_yabatalk"
    private let remoteConfig = RemoteConfig.remoteConfig()
    private let logger = Logger(subsystem: "appful.yabatalk", category: "AdGate")

    private init() {
        // アプリ内デフォルトは false（審査・初回起動で広告を出さない安全側）。
        remoteConfig.setDefaults([key: false as NSObject])
    }

    /// 起動後に呼ぶ。Remote Config を fetch & activate して adsEnabled を更新。
    @MainActor
    func refresh() async {
        do {
            try await remoteConfig.fetchAndActivate()
            adsEnabled = remoteConfig[key].boolValue
            logger.info("adsEnabled = \(self.adsEnabled, privacy: .public)")
        } catch {
            adsEnabled = false   // 失敗時は安全側（広告オフ）
            logger.error("remote config fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Ad Unit IDs
/// AdMob 広告ユニット ID。
/// Debug は Google 公式テスト ID、Release は本番 ID を返す。
///
/// ⚠️ 開発中は必ずテスト ID を使う（本番 ID を叩くと無効トラフィック判定で
///    AdMob アカウント停止のリスク）。
enum AdUnitID {
    static var appOpen: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/5575463023"   // Google 公式テスト: App Open
        #else
        "ca-app-pub-9654811308679484/7231220389"   // yabatalk 本番ユニットID
        #endif
    }

    static var bannerHome: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2934735716"   // Google 公式テスト: Banner
        #else
        "ca-app-pub-9654811308679484/7960474973"   // yabatalk 本番ユニットID
        #endif
    }

    static var bannerSettings: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2934735716"   // Google 公式テスト: Banner
        #else
        "ca-app-pub-9654811308679484/7960474973"   // yabatalk 本番ユニットID
        #endif
    }

    static var bannerChat: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2934735716"   // Google 公式テスト: Banner
        #else
        "ca-app-pub-9654811308679484/5104087203"   // yabatalk 本番ユニットID
        #endif
    }

    static var bannerBoard: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2934735716"   // Google 公式テスト: Banner
        #else
        "ca-app-pub-9654811308679484/4301804718"   // yabatalk 本番ユニットID
        #endif
    }
}

// MARK: - Banner Ad View
/// AdMobバナー広告のSwiftUIラッパー
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    init(adUnitID: String, adSize: AdSize = AdSizeBanner) {
        self.adUnitID = adUnitID
        self.adSize = adSize
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }

        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

// MARK: - Ad Banner Container
/// プレミアム課金チェック付きバナー広告コンテナ
struct AdBannerContainer: View {
    let adUnitID: String
    var adSize: AdSize = AdSizeBanner
    var padding: EdgeInsets = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var adGate = AdGate.shared

    var body: some View {
        // 広告は Remote Config の ads_enabled が true かつ非課金ユーザーのみ表示。
        // ads_enabled が false（公開前デフォルト）の間は枠を確保せず EmptyView。
        if adGate.adsEnabled && !subscriptionManager.isSubscribed {
            BannerAdView(adUnitID: adUnitID, adSize: adSize)
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(adSize.size.height))
                .padding(padding)
        }
    }
}
