import Foundation
import UserNotifications
import PlaidBarCore

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private static let notifiedTxKey = "notifiedTransactionIds"
    private static let notifiedAccountKey = "notifiedAccountIds"

    private var notifiedTransactionIds: Set<String>
    private var notifiedAccountIds: Set<String>

    private init() {
        // Restore persisted dedup sets
        let defaults = UserDefaults.standard
        if let txIds = defaults.stringArray(forKey: Self.notifiedTxKey) {
            notifiedTransactionIds = Set(txIds)
        } else {
            notifiedTransactionIds = []
        }
        if let acctIds = defaults.stringArray(forKey: Self.notifiedAccountKey) {
            notifiedAccountIds = Set(acctIds)
        } else {
            notifiedAccountIds = []
        }
    }

    private func persistNotifiedIds() {
        let defaults = UserDefaults.standard
        defaults.set(Array(notifiedTransactionIds), forKey: Self.notifiedTxKey)
        defaults.set(Array(notifiedAccountIds), forKey: Self.notifiedAccountKey)
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            return granted
        } catch {
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Triggers

    func evaluateTriggers(
        transactions: [TransactionDTO],
        accounts: [AccountDTO],
        largeTransactionThreshold: Double,
        lowBalanceThreshold: Double,
        creditUtilizationThreshold: Double,
        triggers: NotificationTriggers
    ) async {
        if triggers.largeTransaction {
            await checkLargeTransactions(
                transactions: transactions,
                threshold: largeTransactionThreshold
            )
        }

        if triggers.lowBalance {
            await checkLowBalance(
                accounts: accounts,
                threshold: lowBalanceThreshold
            )
        }

        if triggers.highUtilization {
            await checkHighUtilization(
                accounts: accounts,
                threshold: creditUtilizationThreshold
            )
        }

        persistNotifiedIds()
    }

    /// Clear dedup for an account when its condition resolves (balance recovers, utilization drops)
    func clearAccountNotification(for accountId: String) {
        notifiedAccountIds.remove(accountId)
        persistNotifiedIds()
    }

    private func checkLargeTransactions(transactions: [TransactionDTO], threshold: Double) async {
        let large = transactions.filter {
            !$0.isIncome && $0.displayAmount >= threshold && !notifiedTransactionIds.contains($0.id)
        }

        for tx in large {
            notifiedTransactionIds.insert(tx.id)
            await sendNotification(
                title: "Large Transaction",
                body: "\(tx.displayName): \(Formatters.currency(tx.displayAmount, format: .full))",
                identifier: "large-tx-\(tx.id)"
            )
        }

        // Cap stored IDs to last 500 to prevent unbounded growth
        if notifiedTransactionIds.count > 500 {
            notifiedTransactionIds = Set(notifiedTransactionIds.suffix(500))
        }
    }

    private func checkLowBalance(accounts: [AccountDTO], threshold: Double) async {
        let lowAccounts = accounts.filter {
            $0.type == .depository && $0.balances.effectiveBalance < threshold
        }

        // Clear dedup for accounts that recovered
        let lowIds = Set(lowAccounts.map(\.id))
        let depositoryIds = Set(accounts.filter { $0.type == .depository }.map(\.id))
        for id in depositoryIds where !lowIds.contains(id) {
            notifiedAccountIds.remove("low-\(id)")
        }

        for account in lowAccounts {
            let key = "low-\(account.id)"
            guard !notifiedAccountIds.contains(key) else { continue }
            notifiedAccountIds.insert(key)
            await sendNotification(
                title: "Low Balance",
                body: "\(account.name): \(Formatters.currency(account.balances.effectiveBalance, format: .full))",
                identifier: "low-balance-\(account.id)"
            )
        }
    }

    private func checkHighUtilization(accounts: [AccountDTO], threshold: Double) async {
        let highUtil = accounts.filter {
            $0.type == .credit && ($0.balances.utilizationPercent ?? 0) > threshold
        }

        // Clear dedup for accounts that dropped below threshold
        let highIds = Set(highUtil.map(\.id))
        let creditIds = Set(accounts.filter { $0.type == .credit }.map(\.id))
        for id in creditIds where !highIds.contains(id) {
            notifiedAccountIds.remove("util-\(id)")
        }

        for account in highUtil {
            let key = "util-\(account.id)"
            guard !notifiedAccountIds.contains(key) else { continue }
            notifiedAccountIds.insert(key)
            let util = account.balances.utilizationPercent ?? 0
            await sendNotification(
                title: "High Credit Utilization",
                body: "\(account.name): \(Formatters.percent(util)) used",
                identifier: "high-util-\(account.id)"
            )
        }
    }

    private func sendNotification(title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

struct NotificationTriggers: Sendable {
    var largeTransaction: Bool = true
    var lowBalance: Bool = true
    var highUtilization: Bool = true
}
