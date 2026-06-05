import SwiftUI
import GoogleMobileAds

// MARK: - Ad Unit IDs
enum AdUnitID {
    static let appOpen = "ca-app-pub-9654811308679484/5076891455"
    static let bannerHome = "ca-app-pub-9654811308679484/7690409091"
    static let bannerSettings = "ca-app-pub-9654811308679484/4777305291"
    static let bannerChat = "ca-app-pub-9654811308679484/3147792762"
    static let bannerBoard = "ca-app-pub-9654811308679484/2837537664"
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

    var body: some View {
        if !subscriptionManager.isSubscribed {
            BannerAdView(adUnitID: adUnitID, adSize: adSize)
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(adSize.size.height))
                .padding(padding)
        }
    }
}
