import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var settings = Settings.shared
    var onBack: () -> Void
    var showPaywall: () -> Void

    private var theme: AppTheme { settings.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Color.secondary)
                }.buttonStyle(.plain)
                Text("Settings").font(.headline)
                Spacer()
            }

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .font(.system(size: 13))

            // Refresh interval (Pro-locked; free fixed at 10 min)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Refresh interval").font(.caption).foregroundStyle(Color.secondary)
                    if !model.isPro {
                        Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(theme.accent)
                    }
                }
                if model.isPro {
                    Stepper(value: $settings.refreshMinutes, in: 1...60) {
                        Text("Every \(settings.refreshMinutes) min").font(.system(size: 13))
                    }
                } else {
                    Button {
                        showPaywall()
                    } label: {
                        HStack {
                            Text("Every 10 min").font(.system(size: 13))
                            Spacer()
                            Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(Color.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }

            // Theme picker (Aurora free, others Pro)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Theme").font(.caption).foregroundStyle(Color.secondary)
                    if !model.isPro {
                        Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(theme.accent)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(AppTheme.allCases) { t in
                        Button {
                            if model.isPro || t == .aurora { settings.themeID = t.rawValue }
                            else { showPaywall() }
                        } label: {
                            Circle()
                                .fill(LinearGradient(colors: t.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.white, lineWidth: settings.themeID == t.rawValue ? 2 : 0))
                                .overlay(alignment: .bottomTrailing) {
                                    if !model.isPro && t != .aurora {
                                        Image(systemName: "lock.fill").font(.system(size: 7)).foregroundStyle(.white)
                                    }
                                }
                        }.buttonStyle(.plain)
                    }
                }
            }

            Divider()

            HStack {
                Text(model.isPro ? "Rately Pro · active" : "Free version")
                    .font(.caption).foregroundStyle(model.isPro ? theme.accent : Color.secondary)
                Spacer()
                if !model.isPro {
                    Button("Restore") { Task { await model.entitlements.restore() } }
                        .buttonStyle(.link).font(.caption)
                }
            }
        }
        .padding(16)
    }
}
