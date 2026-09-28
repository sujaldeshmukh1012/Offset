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
    private var packagesByProductID: [String: RevenueCat.Package] = [:]
    private let isUITestPurchaseMode: Bool
    private let isUITestRestoreMode: Bool
    private var customerInfoTask: Task<Void, Never>?

    init(configuration: AppConfiguration) {
        self.configuration = configuration

#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // Normal Debug installs use the official App Store/RevenueCat app.
        // Deterministic purchase behavior is restricted to automated UI tests.
        isUITestPurchaseMode = arguments.contains { $0.hasPrefix("-ui-testing-") }
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

    func bindAppUserID(_ appUserID: String) async {
        guard !isUITestPurchaseMode, !isUITestRestoreMode, Purchases.isConfigured else { return }
        guard Purchases.shared.appUserID != appUserID else { return }
        do {
            let result = try await Purchases.shared.logIn(appUserID)
            apply(result.customerInfo)
            if !hasPremiumAccess {
                // A subscriber may have purchased before the Supabase-backed
                // RevenueCat identity was available. Silently reconcile the
                // App Store receipt so Restore Purchases is only a recovery
                // action, not a required launch step.
                apply(try await Purchases.shared.syncPurchases())
            }
        } catch {
            applyAccess(.unavailable(Self.friendlyMessage(for: error)))
            state = .failed("Premium identity verification failed. Please try again.")
        }
    }

    func refresh() async {
        if isUITestPurchaseMode || isUITestRestoreMode { return }
        guard Purchases.isConfigured else { return }
        state = .loadingProducts

        async let offeringsRequest = Purchases.shared.offerings()
        async let customerInfoRequest = Purchases.shared.customerInfo()

        do {
            apply(try await customerInfoRequest)
        } catch {
            applyAccess(.unavailable(Self.friendlyMessage(for: error)))
        }

        do {
            let loadedOfferings = try await offeringsRequest
            let configuredIDs = Set(configuration.revenueCatProductIDs)
            let packages = loadedOfferings.current?.availablePackages.filter {
                configuredIDs.contains($0.storeProduct.productIdentifier)
            } ?? []

            packagesByProductID = Dictionary(
                packages.map { ($0.storeProduct.productIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            products = configuration.revenueCatProductIDs
                .compactMap { packagesByProductID[$0]?.storeProduct }
                .sorted { $0.price < $1.price }

            if products.count == configuration.revenueCatProductIDs.count {
                state = .idle
            } else {
                state = .failed("Premium plans are temporarily unavailable. Please try again later.")
            }
        } catch {
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
        guard let package = packagesByProductID[productID] else {
            state = .failed("The selected subscription is unavailable from the App Store.")
            return
        }

        state = .purchasing
        do {
            let result = try await Purchases.shared.purchase(package: package)
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

    func presentOfferCodeRedemption() {
#if DEBUG
        guard !isUITestPurchaseMode else {
            state = .failed("Offer codes are unavailable during automated UI testing.")
            return
        }
#endif
        guard Purchases.isConfigured else {
            state = .failed("Purchases are not configured for this build.")
            return
        }

        state = .idle
        Purchases.shared.presentCodeRedemptionSheet()
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
