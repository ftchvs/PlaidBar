import SwiftUI
import PlaidBarCore
import Sparkle
import AppKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    let updater: SPUUpdater

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environment(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AccountSettingsView()
                .environment(appState)
                .tabItem {
                    Label("Accounts", systemImage: "building.columns")
                }

            NotificationSettingsView()
                .environment(appState)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AboutView(updater: updater)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 500)
    }
}

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingResetConfirmation = false
    @State private var resetResultMessage: String?
    @State private var resetErrorMessage: String?

    var body: some View {
        @Bindable var state = appState

        Form {
            Picker("Menu bar shows", selection: $state.menuBarSummaryMode) {
                ForEach(MenuBarSummaryMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Picker("Balance format", selection: $state.balanceFormat) {
                Text("$12,450.32").tag(CurrencyFormat.full)
                Text("$12.4K").tag(CurrencyFormat.abbreviated)
                Text("$12,450").tag(CurrencyFormat.compact)
            }
            .disabled(appState.menuBarSummaryMode == .creditUtilization || appState.menuBarSummaryMode == .iconOnly)

            Picker("Refresh interval", selection: $state.refreshInterval) {
                Text("5 minutes").tag(TimeInterval(5 * 60))
                Text("15 minutes").tag(TimeInterval(15 * 60))
                Text("30 minutes").tag(TimeInterval(30 * 60))
                Text("1 hour").tag(TimeInterval(60 * 60))
            }

            HStack {
                Text("Credit warning")
                Spacer()
                TextField(
                    "",
                    value: $state.creditUtilizationThreshold,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)
                Text("%")
            }
            .help("Credit cards above this utilization threshold show warning colors")

            Toggle("Launch at login", isOn: $state.launchAtLogin)

            Section("Local Data") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    LabeledContent("Storage path") {
                        Text(appState.localStoragePathText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    Text(appState.localStorageResolvedPathText)
                        .detailText()
                        .textSelection(.enabled)

                    HStack {
                        Button {
                            revealStorageDirectory()
                        } label: {
                            Label("Reveal", systemImage: "folder")
                        }

                        Button {
                            copyStoragePath()
                        } label: {
                            Label("Copy Path", systemImage: "doc.on.doc")
                        }

                        Spacer()

                        Button(role: .destructive) {
                            isShowingResetConfirmation = true
                        } label: {
                            Label("Reset Local Data", systemImage: "trash")
                        }
                    }

                    Text("Stores the local server database, Plaid item tokens, sync cursors, and app/server auth token. App preferences such as menu bar display, notification thresholds, and launch-at-login are kept.")
                        .detailText()
                }
            }
        }
        .padding()
        .alert("Reset Local PlaidBar Data?", isPresented: $isShowingResetConfirmation) {
            Button("Reset Local Data", role: .destructive) {
                resetLocalData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes files under \(appState.localStoragePathText), including the SQLite database, stored Plaid access tokens, sync cursors, and the app/server auth token. It also clears currently loaded accounts, transactions, and balance history from this app. It does not revoke bank permissions, remove Plaid dashboard Items, delete Plaid credentials from your shell environment, or change app preferences. Stop and restart PlaidBarServer after resetting.")
        }
        .alert("Local Data Reset", isPresented: Binding(
            get: { resetResultMessage != nil },
            set: { if !$0 { resetResultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetResultMessage ?? "")
        }
        .alert("Reset Failed", isPresented: Binding(
            get: { resetErrorMessage != nil },
            set: { if !$0 { resetErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetErrorMessage ?? "")
        }
    }

    private func revealStorageDirectory() {
        let url = appState.localStorageDirectoryURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyStoragePath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.localStorageResolvedPathText, forType: .string)
    }

    private func resetLocalData() {
        do {
            let result = try appState.resetLocalData()
            if result.removedEntryCount == 0 {
                resetResultMessage = "No existing files were found. \(appState.localStoragePathText) is ready for a fresh local server start."
            } else {
                resetResultMessage = "Removed \(result.removedEntryCount) item\(result.removedEntryCount == 1 ? "" : "s") from \(appState.localStoragePathText). Restart PlaidBarServer before reconnecting accounts."
            }
        } catch {
            resetErrorMessage = error.localizedDescription
        }
    }
}

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading) {
            if appState.accounts.isEmpty {
                ContentUnavailableView("No Accounts", systemImage: "building.columns")
            } else {
                List {
                    ForEach(appState.accounts) { account in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(account.name)
                                Text(account.type.rawValue.capitalized)
                                    .detailText()
                            }
                            Spacer()
                            Button("Remove") {
                                Task { await appState.removeAccount(itemId: account.itemId) }
                            }
                            .foregroundStyle(SemanticColors.negative)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Add Account") {
                    Task { await appState.addAccount() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var permissionDenied = false

    var body: some View {
        @Bindable var state = appState

        Form {
            Toggle("Enable notifications", isOn: $state.notificationsEnabled)
                .onChange(of: appState.notificationsEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await appState.requestNotificationPermission()
                            if !granted {
                                permissionDenied = true
                                appState.notificationsEnabled = false
                            }
                        }
                    }
                }

            if permissionDenied {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(SemanticColors.warning)
                    Text("Notifications denied. Enable in System Settings > Notifications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Transaction Alerts") {
                Toggle("Large transactions", isOn: $state.notifyLargeTransaction)
                    .disabled(!appState.notificationsEnabled)

                HStack {
                    Text("Threshold")
                    Spacer()
                    Text("$")
                    TextField(
                        "",
                        value: $state.largeTransactionThreshold,
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                }
                .disabled(!appState.notificationsEnabled || !appState.notifyLargeTransaction)

                Toggle("Low balance warning", isOn: $state.notifyLowBalance)
                    .disabled(!appState.notificationsEnabled)

                HStack {
                    Text("Threshold")
                    Spacer()
                    Text("$")
                    TextField(
                        "",
                        value: $state.lowBalanceThreshold,
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                }
                .disabled(!appState.notificationsEnabled || !appState.notifyLowBalance)
            }

            Section("Credit Alerts") {
                Toggle("High utilization", isOn: $state.notifyHighUtilization)
                    .disabled(!appState.notificationsEnabled)
                Text("Uses credit warning threshold (\(Formatters.percent(appState.creditUtilizationThreshold, decimals: 0)))")
                    .detailText()
            }
        }
        .padding()
    }
}

struct AboutView: View {
    let updater: SPUUpdater

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SemanticColors.brand)

            Text("PlaidBar")
                .font(.title2)
                .fontWeight(.bold)

            Text("Version \(PlaidBarConstants.appVersion)")
                .foregroundStyle(.secondary)

            Text("Your bank accounts, credit cards, and spending -- always one click away.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Divider()

            HStack(spacing: Spacing.lg) {
                Button("Check for Updates\u{2026}") {
                    updater.checkForUpdates()
                }

                if let repoURL = URL(string: "https://github.com/ftchvs/PlaidBar") {
                    Link("View on GitHub", destination: repoURL)
                        .font(.callout)
                }
            }

            Text("MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}
