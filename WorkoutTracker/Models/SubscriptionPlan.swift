import Foundation

/// The three subscription tiers. Base is free; Plus and Pro are paid via StoreKit.
///
/// Each plan defines hard limits on AI features and custom exercises. The limits are
/// lifetime caps (not monthly), so upgrading immediately grants more capacity.
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case base = "base"
    case plus = "plus"
    case pro  = "pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .base: return "Base"
        case .plus: return "Plus"
        case .pro:  return "Pro"
        }
    }

    /// Monthly price string for display. Base is free.
    var priceLabel: String {
        switch self {
        case .base: return "Free"
        case .plus: return "$3/mo"
        case .pro:  return "$5/mo"
        }
    }

    // MARK: - Model access

    /// The Gemini model this plan is allowed to use.
    var allowedModel: GeminiModel {
        switch self {
        case .base: return .flashLite
        case .plus: return .flash
        case .pro:  return .pro
        }
    }

    /// All models this plan can access (includes lower-tier models).
    var availableModels: [GeminiModel] {
        switch self {
        case .base: return [.flashLite]
        case .plus: return [.flashLite, .flash]
        case .pro:  return GeminiModel.allCases
        }
    }

    // MARK: - Custom exercise limits

    /// Maximum number of custom exercises the user can create. `Int.max` = unlimited.
    var maxCustomExercises: Int {
        switch self {
        case .base: return 3
        case .plus: return 10
        case .pro:  return .max
        }
    }

    /// Human-readable limit string for display.
    var customExerciseLabel: String {
        switch self {
        case .base: return "3 custom exercises"
        case .plus: return "10 custom exercises"
        case .pro:  return "Unlimited custom exercises"
        }
    }

    // MARK: - AI generation limits

    /// Maximum number of AI-generated splits (lifetime).
    var maxAISplits: Int {
        switch self {
        case .base: return 1
        case .plus: return 3
        case .pro:  return .max
        }
    }

    /// Maximum number of AI-generated routines (lifetime).
    var maxAIRoutines: Int {
        switch self {
        case .base: return 6
        case .plus: return 10
        case .pro:  return .max
        }
    }

    var aiSplitLabel: String {
        switch self {
        case .base: return "1 AI split"
        case .plus: return "3 AI splits"
        case .pro:  return "Unlimited AI splits"
        }
    }

    var aiRoutineLabel: String {
        switch self {
        case .base: return "6 AI routines"
        case .plus: return "10 AI routines"
        case .pro:  return "Unlimited AI routines"
        }
    }

    var modelLabel: String {
        switch self {
        case .base: return "Flash Lite model"
        case .plus: return "Flash model"
        case .pro:  return "Pro model"
        }
    }

    // MARK: - StoreKit product IDs

    /// The StoreKit product ID for this plan. Base has none (free).
    var productID: String? {
        switch self {
        case .base: return nil
        case .plus: return "com.workouttracker.plus"
        case .pro:  return "com.workouttracker.pro"
        }
    }

    /// Reverse-lookup a plan from a StoreKit product ID.
    static func from(productID: String) -> SubscriptionPlan? {
        switch productID {
        case "com.workouttracker.plus": return .plus
        case "com.workouttracker.pro":  return .pro
        default: return nil
        }
    }
}
