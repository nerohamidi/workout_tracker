import Foundation
import StoreKit
import SwiftUI

/// Manages StoreKit 2 subscriptions and exposes the user's current plan to the app.
///
/// Injected into the environment as `@EnvironmentObject` from the app root. Listens
/// for transaction updates so the plan stays current if the user subscribes, cancels,
/// or gets a renewal outside the app.
///
/// Also tracks lifetime AI-generation counts in `UserDefaults` and checks them against
/// the current plan's limits.
@MainActor
final class SubscriptionManager: ObservableObject {
    /// The user's active plan. Derived from current StoreKit entitlements.
    @Published var currentPlan: SubscriptionPlan = .base

    /// StoreKit products fetched at launch. Empty until `loadProducts()` completes.
    @Published var products: [Product] = []

    /// Set briefly during a purchase flow.
    @Published var isPurchasing = false

    /// Last purchase error, shown in UI then cleared.
    @Published var purchaseError: String?

    // MARK: - AI usage counters (persisted in UserDefaults)

    @AppStorage("aiRoutinesGenerated") var aiRoutinesGenerated: Int = 0
    @AppStorage("aiSplitsGenerated") var aiSplitsGenerated: Int = 0

    private var transactionListener: Task<Void, Never>?

    private static let productIDs: Set<String> = [
        "com.workouttracker.plus",
        "com.workouttracker.pro"
    ]

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            // Products unavailable (sandbox, no network, etc.) — degrade gracefully.
            products = []
        }
    }

    /// Find the StoreKit `Product` for a given plan.
    func product(for plan: SubscriptionPlan) -> Product? {
        guard let id = plan.productID else { return nil }
        return products.first { $0.id == id }
    }

    // MARK: - Purchase

    func purchase(_ plan: SubscriptionPlan) async {
        guard let product = product(for: plan) else {
            purchaseError = "Product not available. Try again later."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// Walk current entitlements and determine the active plan. Highest tier wins.
    func refreshEntitlements() async {
        var best: SubscriptionPlan = .base

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if let plan = SubscriptionPlan.from(productID: transaction.productID) {
                if plan == .pro { best = .pro }
                else if plan == .plus && best != .pro { best = .plus }
            }
        }

        currentPlan = best
    }

    // MARK: - Limit checks

    /// Whether the user can create another custom exercise.
    func canCreateCustomExercise(currentCount: Int) -> Bool {
        currentCount < currentPlan.maxCustomExercises
    }

    /// Whether the user can generate another AI routine.
    var canGenerateAIRoutine: Bool {
        aiRoutinesGenerated < currentPlan.maxAIRoutines
    }

    /// Whether the user can generate another AI split.
    var canGenerateAISplit: Bool {
        aiSplitsGenerated < currentPlan.maxAISplits
    }

    /// Record that an AI routine was generated.
    func recordAIRoutineGenerated() {
        aiRoutinesGenerated += 1
    }

    /// Record that an AI split was generated.
    func recordAISplitGenerated() {
        aiSplitsGenerated += 1
    }

    /// The best model the user's plan allows. If their stored preference is above their
    /// plan tier, falls back to their plan's default.
    var effectiveModel: GeminiModel {
        let stored = UserDefaults.standard.string(forKey: "geminiModel") ?? ""
        if let chosen = GeminiModel(rawValue: stored),
           currentPlan.availableModels.contains(chosen) {
            return chosen
        }
        return currentPlan.allowedModel
    }

    // MARK: - Remaining counts (for display)

    var remainingAIRoutines: String {
        let limit = currentPlan.maxAIRoutines
        if limit == .max { return "Unlimited" }
        let remaining = max(0, limit - aiRoutinesGenerated)
        return "\(remaining) left"
    }

    var remainingAISplits: String {
        let limit = currentPlan.maxAISplits
        if limit == .max { return "Unlimited" }
        let remaining = max(0, limit - aiSplitsGenerated)
        return "\(remaining) left"
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                guard let transaction = try? await self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
