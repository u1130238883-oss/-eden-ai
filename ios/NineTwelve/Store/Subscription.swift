import Foundation
import StoreKit

/// 會員訂閱（Apple 官方 In-App Purchase，StoreKit 2）。
///
/// App Store 規定：App 內解鎖數位功能一律要走 Apple 的內購，
/// 不能接微信支付、支付寶或其他第三方收款，否則會被拒審或下架。
/// 因此這裡使用自動續訂型訂閱（auto-renewable subscription）。
///
/// 兩個語言版本是兩個不同的 App，各自需要在 App Store Connect
/// 建立自己的訂閱商品，所以商品編號也分開。
@MainActor
final class Subscription: ObservableObject {

    /// 月費訂閱的商品編號。上架時 App Store Connect 裡要建一模一樣的。
    static let monthlyID: String = {
        #if LOCALE_LATIN
        return "com.ninetwelve.fortune.latin.pro.monthly"
        #else
        return "com.ninetwelve.fortune.pro.monthly"
        #endif
    }()

    /// 這個版本有沒有付費機制。
    ///
    /// 帶 `UNLOCKED` 旗標建置時全部功能直接開放，不接任何商店 ——
    /// 用來自己試用與給人看，不是上架用的版本。
    static let isUnlocked: Bool = {
        #if UNLOCKED
        return true
        #else
        return false
        #endif
    }()

    /// 目前是否為會員。解鎖版永遠為 true。
    @Published private(set) var isActive = false
    /// 從 App Store 取回的商品（含當地價格）。
    @Published private(set) var product: Product?
    /// 是否正在向 App Store 查詢。
    @Published private(set) var isLoading = true
    /// 是否正在付款中。
    @Published private(set) var isPurchasing = false
    /// 最近一次錯誤，供介面顯示。
    @Published var errorMessage: String?

    private var updateTask: Task<Void, Never>?

    init() {
        if Self.isUnlocked {
            isActive = true
            isLoading = false
            return
        }
        // 續訂、退款、家庭共享等變動都會從這裡進來
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.settle(result)
            }
        }
        Task { await refresh() }
    }

    /// 取商品資訊並確認目前的訂閱狀態。
    func refresh() async {
        guard !Self.isUnlocked else { return }
        isLoading = true
        do {
            product = try await Product.products(for: [Self.monthlyID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
        await updateEntitlement()
        isLoading = false
    }

    /// 購買訂閱。
    func purchase() async {
        guard !Self.isUnlocked else { return }
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await settle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 回復購買（換裝置或重裝後使用）。
    func restore() async {
        guard !Self.isUnlocked else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await updateEntitlement()
    }

    // MARK: - 內部

    private func settle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await updateEntitlement()
    }

    /// 以 Apple 目前授予的權益為準，不自行記帳。
    private func updateEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyID, transaction.revocationDate == nil {
                active = true
            }
        }
        isActive = active
    }
}
