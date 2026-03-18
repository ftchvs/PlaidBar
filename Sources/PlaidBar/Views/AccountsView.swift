import SwiftUI
import PlaidBarCore

struct AccountsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.accounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts", systemImage: "building.columns")
                } description: {
                    Text("Add a bank account to get started.")
                }
                .padding()
            } else {
                // Depository accounts
                if !appState.depositoryAccounts.isEmpty {
                    sectionHeader("Bank Accounts")
                    ForEach(appState.depositoryAccounts) { account in
                        AccountRow(account: account)
                    }
                }

                // Credit accounts
                if !appState.creditAccounts.isEmpty {
                    sectionHeader("Credit Cards")
                    ForEach(appState.creditAccounts) { account in
                        AccountRow(account: account)
                    }
                }

                // Other accounts
                let otherAccounts = appState.accounts.filter {
                    $0.type != .depository && $0.type != .credit
                }
                if !otherAccounts.isEmpty {
                    sectionHeader("Other")
                    ForEach(otherAccounts) { account in
                        AccountRow(account: account)
                    }
                }

                // Net balance footer (inside scroll)
                Divider()
                    .padding(.top, 4)
                HStack {
                    Text("Net Balance")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(Formatters.currency(appState.netBalance, format: .full))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .background(.quaternary.opacity(0.3))
    }
}

// MARK: - Institution Avatar

private struct InstitutionAvatar: View {
    let name: String

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    private var color: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        Text(initial)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color, in: Circle())
    }
}

struct AccountRow: View {
    let account: AccountDTO
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            InstitutionAvatar(name: account.institutionName ?? account.name)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                if let mask = account.mask {
                    Text("\u{2022}\u{2022}\u{2022}\u{2022} \(mask)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .monospacedDigit()
                    .foregroundStyle(amountColor)

                if let utilization = account.balances.utilizationPercent {
                    Text(Formatters.percent(utilization))
                        .font(.caption)
                        .foregroundStyle(utilization > 30 ? .orange : .secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var formattedAmount: String {
        let amount = account.balances.current ?? account.balances.effectiveBalance
        if account.type == .credit {
            return Formatters.currency(abs(amount), format: .full)
        }
        return Formatters.currency(amount, format: .full)
    }

    private var amountColor: Color {
        account.type == .credit ? .red : .primary
    }
}
