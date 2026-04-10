import SwiftUI

/// Full-screen paywall showing the three subscription tiers with features and
/// purchase buttons. Presented as a sheet from Settings or from limit-reached alerts.
struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Text("Upgrade Your Plan")
                            .font(.title2.weight(.bold))
                        Text("Unlock more AI power and custom exercises")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Plan cards
                    ForEach(SubscriptionPlan.allCases) { plan in
                        PlanCard(plan: plan)
                    }

                    // Restore
                    Button {
                        Task { await subscriptionManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Purchase Failed", isPresented: Binding(
                get: { subscriptionManager.purchaseError != nil },
                set: { if !$0 { subscriptionManager.purchaseError = nil } }
            ), presenting: subscriptionManager.purchaseError) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: SubscriptionPlan
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private var isCurrent: Bool {
        subscriptionManager.currentPlan == plan
    }

    private var isUpgrade: Bool {
        let plans = SubscriptionPlan.allCases
        guard let currentIdx = plans.firstIndex(of: subscriptionManager.currentPlan),
              let planIdx = plans.firstIndex(of: plan) else { return false }
        return planIdx > currentIdx
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.displayName)
                        .font(.headline.weight(.bold))
                    Text(plan.priceLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isCurrent {
                    Text("Current")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            // Features
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "sparkles", text: plan.modelLabel)
                featureRow(icon: "dumbbell", text: plan.customExerciseLabel)
                featureRow(icon: "list.bullet.rectangle", text: plan.aiRoutineLabel)
                featureRow(icon: "arrow.triangle.2.circlepath", text: plan.aiSplitLabel)
            }

            // Action button
            if isCurrent {
                // No button needed
            } else if isUpgrade {
                Button {
                    Task { await subscriptionManager.purchase(plan) }
                } label: {
                    HStack {
                        if subscriptionManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 4)
                        }
                        Text("Upgrade to \(plan.displayName)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(plan == .pro ? Color.purple : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(subscriptionManager.isPurchasing)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}
