import Foundation

public struct RecurringTransaction: Sendable, Identifiable, Hashable {
    public var id: String { merchantName }
    public let merchantName: String
    public let frequency: RecurringFrequency
    public let averageAmount: Double
    public let lastDate: String
    public let nextExpectedDate: String
    public let category: SpendingCategory?
    public let transactionCount: Int
    public let confidence: Double

    public init(
        merchantName: String,
        frequency: RecurringFrequency,
        averageAmount: Double,
        lastDate: String,
        nextExpectedDate: String,
        category: SpendingCategory?,
        transactionCount: Int,
        confidence: Double
    ) {
        self.merchantName = merchantName
        self.frequency = frequency
        self.averageAmount = averageAmount
        self.lastDate = lastDate
        self.nextExpectedDate = nextExpectedDate
        self.category = category
        self.transactionCount = transactionCount
        self.confidence = confidence
    }
}

public enum RecurringFrequency: String, Sendable, CaseIterable, Hashable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case annual

    public var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annual: "Annual"
        }
    }

    public var iconName: String {
        switch self {
        case .weekly: "arrow.clockwise"
        case .biweekly: "arrow.2.squarepath"
        case .monthly: "calendar"
        case .quarterly: "calendar.badge.clock"
        case .annual: "calendar.circle"
        }
    }

    public var estimatedDays: Int {
        switch self {
        case .weekly: 7
        case .biweekly: 14
        case .monthly: 30
        case .quarterly: 90
        case .annual: 365
        }
    }
}
