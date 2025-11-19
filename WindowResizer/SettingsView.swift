//
//  SettingsView.swift
//  WindowResizer
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Settings Tab Enum
enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case exclusions = "Exclusions"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .exclusions: return "app.badge.checkmark"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
            .navigationTitle("Settings")
            .frame(minWidth: 200)
        } detail: {
            // Detail view based on selected tab
            Group {
                switch selectedTab {
                case .general:
                    GeneralView()
                case .exclusions:
                    ExclusionsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - General Tab
struct GeneralView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("General Settings")
                .font(.title)
                .fontWeight(.semibold)

            Text("General settings will be added here")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(40)
        .navigationTitle("General")
    }
}

// MARK: - Exclusions Tab
struct ExclusionsView: View {
    @ObservedObject var manager = AccessibilityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Excluded Apps")
                .font(.title)
                .fontWeight(.semibold)

            Text("Apps excluded from global hotkeys won't respond to resize shortcuts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if manager.excludedAppBundleIDs.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("No excluded apps")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Use the menu bar to exclude apps from shortcuts")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List of excluded apps
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(manager.excludedAppBundleIDs).sorted(), id: \.self) { bundleID in
                            ExcludedAppRow(bundleID: bundleID)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(40)
        .navigationTitle("Exclusions")
    }
}

// MARK: - Excluded App Row
struct ExcludedAppRow: View {
    let bundleID: String
    @ObservedObject var manager = AccessibilityManager.shared

    var appName: String {
        manager.getAppName(for: bundleID)
    }

    var appIcon: NSImage? {
        manager.getAppIcon(for: bundleID)
    }

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }

            // App name
            Text(appName)
                .font(.body)

            Spacer()

            // Remove button with glass style
            if #available(macOS 26.0, *) {
                Button("Remove") {
                    withAnimation {
                        manager.removeAppExclusion(bundleID: bundleID)
                    }
                }
                .buttonStyle(.glass)
            } else {
                Button("Remove") {
                    withAnimation {
                        manager.removeAppExclusion(bundleID: bundleID)
                    }
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - About Tab
struct AboutView: View {
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            // App icon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(radius: 8)
            } else {
                Image(systemName: "rectangle.resize")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 128, height: 128)
            }

            VStack(spacing: 8) {
                Text("WindowResizer")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(appVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.horizontal, 60)

            VStack(spacing: 12) {
                InfoRow(label: "Developer", value: "Oluwaseun Adetunji")
                InfoRow(label: "Copyright", value: "© 2024 Oluwaseun Adetunji")
            }

            Spacer()
        }
        .padding(40)
        .navigationTitle("About")
    }
}

// MARK: - Info Row for About Tab
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}
