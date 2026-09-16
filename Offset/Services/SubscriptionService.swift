import Foundation
import RevenueCat

@MainActor
final class SubscriptionService: ObservableObject {
    enum PurchaseState: Equatable {
        case idle
        case loadingProducts
        case purchasing
        case pending
        case succeeded
        case restoring
        case restored
        case restoredNoPurchase
        case cancelled
        case failed(String)
    }

    enum AccessStatus: Equatable {
        case checking
        case free
        case active(expirationDate: Date?, willRenew: Bool, isTrial: Bool)
        case billingIssue(expirationDate: Date?)
        case expired(expirationDate: Date?)
        case unavailable(String)

        var grantsPremiumAccess: Bool {
            switch self {
            case .active, .billingIssue: true
            default: false
            }
        }
    }

    struct EntitlementSnapshot: Equatable {
        let exists: Bool
        let isActive: Bool
        let expirationDate: Date?
        let willRenew: Bool
        let isTrial: Bool
        let hasBillingIssue: Bool
    }

    @Published private(set) var products: [StoreProduct] = []
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var accessStatus: AccessStatus = .checking
    @Published private(set) var state: PurchaseState = .idle
    @Published private(set) var managementURL: URL?

    private let configuration: AppConfiguration
    private let isUITestPurchaseMode: Bool
    private let isUITestRestoreMode: Bool
    private var customerInfoTask: Task<Void, Never>?

    init(configuration: AppConfiguration) {
        self.configuration = configuration

#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // Debug installs default to a deterministic local purchase preview while
        // App Store Connect products are being prepared. Pass `-use-live-store`
        // from Xcode when the products are ready for real sandbox testing.
        isUITestPurchaseMode = !arguments.contains("-use-live-store")
        isUITestRestoreMode = arguments.contains("-ui-testing-restore-premium")
        if arguments.contains("-ui-testing-premium") {
            applyAccess(.active(expirationDate: nil, willRenew: true, isTrial: false))
            return
        }
        if isUITestPurchaseMode || isUITestRestoreMode {
            applyAccess(.free)
            return
        }
#else
        isUITestPurchaseMode = false
        isUITestRestoreMode = false
#endif

        guard let apiKey = configuration.revenueCatAPIKey else {
            applyAccess(.unavailable("RevenueCat is not configured for this build."))
            state = .failed("Purchases are not configured for this build.")
            return
        }

        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey)
        }

        customerInfoTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self?.apply(customerInfo)
            }
        }
    }

    deinit { customerInfoTask?.cancel() }

    func refresh() async {
        if isUITestPurchaseMode || isUITestRestoreMode { return }
        guard Purchases.isConfigured else { return }
        state = .loadingProducts

        async let products = Purchases.shared.products(configuration.revenueCatProductIDs)
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.products = await products.sorted { $0.price < $1.price }
            apply(customerInfo)
            state = .idle
        } catch {
            self.products = await products.sorted { $0.price < $1.price }
            state = .failed(Self.friendlyMessage(for: error))
        }
    }

    func refreshEntitlement() async {
        guard !isUITestPurchaseMode, !isUITestRestoreMode, Purchases.isConfigured else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            state = .failed(Self.friendlyMessage(for: error))
        }
    }

    func purchase(productID: String) async {
#if DEBUG
        if isUITestPurchaseMode {
            state = .purchasing
            await Task.yield()
            applyAccess(.active(expirationDate: nil, willRenew: true, isTrial: false))
            state = .succeeded
            return
        }
#endif
        guard let product = products.first(where: { $0.productIdentifier == productID }) else {
            state = .failed("The selected subscription is unavailable from the App Store.")
            return
        }

        state = .purchasing
        do {
            let result = try await Purchases.shared.purchase(product: product)
            apply(result.customerInfo)
            if result.userCancelled {
                state = .cancelled
            } else if hasPremiumAccess {
                state = .succeeded
            } else {
                state = .failed("The purchase completed, but Premium access is not available yet. Try Restore Purchases.")
            }
        } catch ErrorCode.paymentPendingError {
            state = .pending
        } catch ErrorCode.purchaseCancelledError {
            state = .cancelled
        } catch {
            state = .failed(Self.friendlyMessage(for: error))
        }
    }

    func restore() async {
#if DEBUG
        if isUITestRestoreMode {
            state = .restoring
            await Task.yield()
            applyAccess(.active(expirationDate: nil, willRenew: true, isTrial: false))
            state = .restored
            return
        }
#endif
        guard Purchases.isConfigured else {
            state = .failed("Purchases are not configured for this build.")
            return
        }
        state = .restoring
        do {
            apply(try await Purchases.shared.restorePurchases())
            state = hasPremiumAccess ? .restored : .restoredNoPurchase
        } catch {
            state = .failed(Self.friendlyMessage(for: error))
        }
    }

    func product(id: String) -> StoreProduct? {
        products.first { $0.productIdentifier == id }
    }

    func canPurchase(productID: String) -> Bool {
        product(id: productID) != nil || isUITestPurchaseMode
    }

    static func resolve(_ snapshot: EntitlementSnapshot, now: Date = Date()) -> AccessStatus {
        guard snapshot.exists else { return .free }
        if snapshot.isActive {
            if snapshot.hasBillingIssue {
                return .billingIssue(expirationDate: snapshot.expirationDate)
            }
            return .active(
                expirationDate: snapshot.expirationDate,
                willRenew: snapshot.willRenew,
                isTrial: snapshot.isTrial
            )
        }
        if let expirationDate = snapshot.expirationDate, expirationDate <= now {
            return .expired(expirationDate: expirationDate)
        }
        return .free
    }

    private func apply(_ customerInfo: CustomerInfo) {
        managementURL = customerInfo.managementURL
        let entitlement = customerInfo.entitlements[configuration.revenueCatEntitlementID]
        applyAccess(Self.resolve(EntitlementSnapshot(
            exists: entitlement != nil,
            isActive: entitlement?.isActive == true,
            expirationDate: entitlement?.expirationDate,
            willRenew: entitlement?.willRenew == true,
            isTrial: entitlement?.periodType == .trial,
            hasBillingIssue: entitlement?.billingIssueDetectedAt != nil
        )))
    }

    private func applyAccess(_ status: AccessStatus) {
        accessStatus = status
        hasPremiumAccess = status.grantsPremiumAccess
    }

    private static func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "The App Store could not complete that request. Please try again." : message
    }
}
