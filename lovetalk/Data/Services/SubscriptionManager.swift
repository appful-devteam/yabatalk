import Foundation
import StoreKit

// MARK: - Subscription Tier
enum SubscriptionTier: String, CaseIterable {
    case free
    case premium
    case premiumPlus

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .premiumPlus: return "Premium+"
        }
    }
}

// MARK: - Subscription Product
enum SubscriptionProduct: String, CaseIterable {
    case weekly = "yaba.weekly"
    case monthly = "yaba.monthly"
    case yearly = "yaba.yearly"
    case plusWeekly = "yaba.plus.weekly"
    case plusMonthly = "yaba.plus.monthly"
    case plusYearly = "yaba.plus.yearly"

    var tier: SubscriptionTier {
        switch self {
        case .weekly, .monthly, .yearly: return .premium
        case .plusWeekly, .plusMonthly, .plusYearly: return .premiumPlus
        }
    }

    var displayName: String {
        switch self {
        case .weekly, .plusWeekly: return String(localized: "1週間", bundle: LanguageManager.appBundle)
        case .monthly, .plusMonthly: return String(localized: "1ヶ月", bundle: LanguageManager.appBundle)
        case .yearly, .plusYearly: return String(localized: "1年間", bundle: LanguageManager.appBundle)
        }
    }

    /// ハードコード価格（StoreKit未読み込み時のフォールバック）
    var fallbackPrice: String {
        switch self {
        case .weekly: return "¥500"
        case .monthly: return "¥980"
        case .yearly: return "¥5,000"
        case .plusWeekly: return "¥980"
        case .plusMonthly: return "¥1,980"
        case .plusYearly: return "¥12,800"
        }
    }

    /// 日数（1日あたり計算用）
    var daysInPeriod: Int {
        switch self {
        case .weekly, .plusWeekly: return 7
        case .monthly, .plusMonthly: return 30
        case .yearly, .plusYearly: return 365
        }
    }

    /// StoreKit Productからローカライズ済み価格を取得
    func localizedPrice(from storeProduct: Product?) -> String {
        storeProduct?.displayPrice ?? fallbackPrice
    }

    /// StoreKit Productから1日あたり価格を計算
    func localizedPricePerDay(from storeProduct: Product?) -> String {
        guard let storeProduct = storeProduct else {
            return Self.formatPerDay(fallbackPricePerDay)
        }
        let perDay = storeProduct.price / Decimal(daysInPeriod)
        let formatted = storeProduct.priceFormatStyle.format(perDay)
        return Self.formatPerDay(formatted)
    }

    private var fallbackPricePerDay: String {
        switch self {
        case .weekly: return "¥71"
        case .monthly: return "¥33"
        case .yearly: return "¥14"
        case .plusWeekly: return "¥140"
        case .plusMonthly: return "¥66"
        case .plusYearly: return "¥35"
        }
    }

    /// 「約{price}/日」を表示言語に応じてフォーマット
    private static func formatPerDay(_ price: String) -> String {
        let lang = LanguageManager.resolvedLanguage
        switch lang {
        case "en": return "~\(price)/day"
        case "es": return "~\(price)/día"
        case "ko": return "약\(price)/일"
        case "zh-Hans": return "约\(price)/天"
        default: return "約\(price)/日"
        }
    }

    /// StoreKit Productから割引率を計算（同Tier週間プランとの比較）
    func localizedSavings(weeklyProduct: Product?, thisProduct: Product?) -> String? {
        // 週間プランは割引なし
        if self == .weekly || self == .plusWeekly { return nil }
        let weeklyDays = 7
        let percent: Int
        if let weekly = weeklyProduct, let current = thisProduct {
            let weeklyPerDay = weekly.price / Decimal(weeklyDays)
            let currentPerDay = current.price / Decimal(daysInPeriod)
            guard weeklyPerDay > 0 else { return nil }
            percent = Int(round(Double(truncating: (1 - currentPerDay / weeklyPerDay) as NSDecimalNumber) * 100))
            guard percent > 0 else { return nil }
        } else {
            // フォールバック
            switch self {
            case .monthly: percent = 53
            case .yearly: percent = 81
            case .plusMonthly: percent = 53
            case .plusYearly: percent = 75
            default: return nil
            }
        }
        return Self.formatSavings(percent)
    }

    /// 「週間より{n}%お得」を表示言語に応じてフォーマット
    private static func formatSavings(_ percent: Int) -> String {
        let lang = LanguageManager.resolvedLanguage
        switch lang {
        case "en": return "\(percent)% less than weekly"
        case "es": return "\(percent)% menos que semanal"
        case "ko": return "주간보다 \(percent)% 절약"
        case "zh-Hans": return "比周订阅省\(percent)%"
        default: return "週間より\(percent)%お得"
        }
    }

    var isRecommended: Bool {
        self == .yearly || self == .plusYearly
    }

    /// Premiumプラン一覧
    static var premiumProducts: [SubscriptionProduct] {
        [.weekly, .monthly, .yearly]
    }

    /// Premium+プラン一覧
    static var premiumPlusProducts: [SubscriptionProduct] {
        [.plusWeekly, .plusMonthly, .plusYearly]
    }

    /// Tier別プラン一覧
    static func products(for tier: SubscriptionTier) -> [SubscriptionProduct] {
        allCases.filter { $0.tier == tier }
    }
}

// MARK: - Subscription Manager
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // MARK: - Properties
    private let productIDs = SubscriptionProduct.allCases.map { $0.rawValue }
    private var updateListenerTask: Task<Void, Error>?
    private var initialLoadTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var isSubscribed: Bool {
        !purchasedProductIDs.isEmpty
    }

    var currentTier: SubscriptionTier {
        let plusIDs = Set(SubscriptionProduct.premiumPlusProducts.map { $0.rawValue })
        if !purchasedProductIDs.intersection(plusIDs).isEmpty {
            return .premiumPlus
        }
        let premiumIDs = Set(SubscriptionProduct.premiumProducts.map { $0.rawValue })
        if !purchasedProductIDs.intersection(premiumIDs).isEmpty {
            return .premium
        }
        return .free
    }

    var isPremiumPlus: Bool {
        return currentTier == .premiumPlus
    }

    // MARK: - Initialization
    private init() {
        updateListenerTask = listenForTransactions()

        initialLoadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadProducts()
            await self.updatePurchasedProducts()
        }
    }

    /// 初回 entitlement 読込が終わるまで待機する。
    /// 起動直後に課金状態を判定したい場面(例: 起動広告)で使う。
    func awaitInitialLoad() async {
        await initialLoadTask?.value
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// 商品を読み込む
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await Product.products(for: productIDs)
            products.sort { product1, product2 in
                let order1 = SubscriptionProduct.allCases.firstIndex { $0.rawValue == product1.id } ?? 0
                let order2 = SubscriptionProduct.allCases.firstIndex { $0.rawValue == product2.id } ?? 0
                return order1 < order2
            }
        } catch {
            errorMessage = String(localized: "商品の読み込みに失敗しました", bundle: LanguageManager.appBundle)
            print("Failed to load products: \(error)")
        }

        isLoading = false
    }

    /// 購入処理
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                isLoading = false
                return transaction

            case .userCancelled:
                isLoading = false
                return nil

            case .pending:
                isLoading = false
                return nil

            @unknown default:
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            errorMessage = String(localized: "購入処理に失敗しました", bundle: LanguageManager.appBundle)
            throw error
        }
    }

    /// 購入を復元
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = String(localized: "購入の復元に失敗しました", bundle: LanguageManager.appBundle)
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        var latestTransaction: Transaction?
        var latestDate = Date.distantPast
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 取り消されていないトランザクションのみ
                if transaction.revocationDate == nil {
                    // サブスクリプションの場合、最新のトランザクションのみを保持
                    let transactionDate = transaction.purchaseDate
                    if transactionDate > latestDate {
                        latestDate = transactionDate
                        latestTransaction = transaction
                    }
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        
        // 最新のトランザクションのみを有効なサブスクリプションとして設定
        if let transaction = latestTransaction {
            purchasedIDs.insert(transaction.productID)
        }

        let didChange = purchasedProductIDs != purchasedIDs
        purchasedProductIDs = purchasedIDs

        // GA4: 課金状態を user property に反映（全イベントを課金/無課金・tier で層別するため）。
        // init / Transaction 監視の両経路でここを通るので、起動時も購入/解約時も最新化される。
        AnalyticsManager.shared.setSubscriptionState(isSubscribed: isSubscribed, tier: currentTier.rawValue)

        // サブスク状態が変化したら分析ドキュメントへ反映（tier 変化時のみ実書き込み）。
        // bootstrap 時の 1 回だけでは購入/アップグレード/解約を取りこぼすため。
        if didChange {
            Task { await AppDataFirestoreService.shared.pushSubscriptionStateIfChanged() }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// 特定の商品を取得
    func product(for subscriptionProduct: SubscriptionProduct) -> Product? {
        products.first { $0.id == subscriptionProduct.rawValue }
    }
}

// MARK: - Store Error
enum StoreError: Error {
    case failedVerification
    case purchaseFailed
}
