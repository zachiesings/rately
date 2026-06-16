import SwiftUI

struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showAddPair = false

    // Converter state
    @State private var amountText = "1"
    @State private var convFrom = "USD"
    @State private var convTo = "EUR"

    private var theme: AppTheme { model.settings.theme }
    private var rates: RatesService { model.rates }

    var body: some View {
        VStack(spacing: 0) {
            if showPaywall {
                PaywallView(onClose: { showPaywall = false })
                    .environmentObject(model)
            } else if showSettings {
                SettingsView(onBack: { showSettings = false },
                             showPaywall: { showSettings = false; showPaywall = true })
                    .environmentObject(model)
            } else if showAddPair {
                AddPairView { base, quote in
                    rates.addPair(base: base, quote: quote)
                    showAddPair = false
                } onCancel: { showAddPair = false }
                .environmentObject(model)
            } else {
                main
            }
        }
        .frame(width: 320)
    }

    private var main: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Text("Rately").font(.headline)
                Spacer()
                if rates.loading { ProgressView().controlSize(.small) }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").foregroundStyle(Color.secondary)
                }.buttonStyle(.plain)
            }

            // Tracked pairs
            VStack(spacing: 6) {
                ForEach(rates.pairs) { pair in
                    pairRow(pair)
                }
            }

            // Add pair
            Button {
                if model.canAddPair { showAddPair = true } else { showPaywall = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add pair").font(.system(size: 12, weight: .medium))
                    if !model.canAddPair {
                        Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(theme.accent)
                    }
                    Spacer()
                }
                .foregroundStyle(theme.accent)
            }.buttonStyle(.plain)

            Divider()

            converter

            Divider()

            // Last updated + refresh
            HStack {
                Text(updatedText).font(.caption2).foregroundStyle(Color.secondary)
                Spacer()
                Button {
                    Task { await rates.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.secondary)
                }.buttonStyle(.plain).disabled(rates.loading)
            }

            if let err = rates.lastError {
                Text(err).font(.caption2).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }

            // Unlock Pro
            if !model.isPro {
                Button(action: { showPaywall = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Unlock Rately Pro").bold()
                        Spacer()
                        if !model.entitlements.priceText.isEmpty {
                            Text(model.entitlements.priceText).font(.caption).opacity(0.9)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .background(LinearGradient(colors: theme.gradient, startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
            }

            HStack {
                Button("Settings") { showSettings = true }.buttonStyle(.link)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.link)
            }
            .font(.caption)
        }
        .padding(16)
    }

    // MARK: - Pair row

    private func pairRow(_ pair: Pair) -> some View {
        let isPrimary = pair == rates.primary
        return Button {
            rates.makePrimary(pair)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(pair.base).font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(Color.secondary)
                        Text(pair.quote).font(.system(size: 13, weight: .semibold))
                    }
                    if isPrimary {
                        Text("Menu bar").font(.system(size: 9)).foregroundStyle(theme.accent)
                    }
                }
                Spacer()
                if let r = rates.rate(for: pair) {
                    Text(RatesService.format(r))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                } else {
                    Text("—").font(.system(size: 14, design: .monospaced)).foregroundStyle(Color.secondary)
                }
                Button {
                    rates.removePair(pair)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }.buttonStyle(.plain)
            }
            .padding(.vertical, 7).padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPrimary
                          ? AnyShapeStyle(LinearGradient(colors: theme.gradient.map { $0.opacity(0.16) },
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.primary.opacity(0.05)))
            )
        }.buttonStyle(.plain)
    }

    // MARK: - Converter

    private var converter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Converter").font(.caption).foregroundStyle(Color.secondary)
            HStack(spacing: 8) {
                TextField("Amount", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                Picker("", selection: $convFrom) {
                    ForEach(Catalog.all, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(maxWidth: .infinity)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(Color.secondary)
                Picker("", selection: $convTo) {
                    ForEach(Catalog.all, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(maxWidth: .infinity)
            }
            HStack {
                Spacer()
                Text(convertedText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
            }
        }
    }

    private var convertedText: String {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        if let out = rates.convert(amount: amount, from: convFrom, to: convTo) {
            return "\(RatesService.format(out)) \(convTo)"
        }
        return "—"
    }

    private var updatedText: String {
        guard let d = rates.lastUpdated else { return "Not updated yet" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return "Updated \(f.string(from: d))"
    }
}

// MARK: - Add pair sheet

struct AddPairView: View {
    @EnvironmentObject var model: AppModel
    var onAdd: (String, String) -> Void
    var onCancel: () -> Void

    @State private var base = "USD"
    @State private var quote = "EUR"

    private var theme: AppTheme { model.settings.theme }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Add a pair").font(.title3.bold()).foregroundStyle(.white)
                Text("Track any fiat or crypto rate")
                    .font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 14) {
                pickerRow("Base", selection: $base)
                pickerRow("Quote", selection: $quote)

                if base == quote {
                    Text("Pick two different symbols.")
                        .font(.caption2).foregroundStyle(.red)
                }

                HStack {
                    Button("Cancel") { onCancel() }.buttonStyle(.bordered)
                    Spacer()
                    Button("Add") { onAdd(base, quote) }
                        .buttonStyle(.borderedProminent).tint(theme.accent)
                        .disabled(base == quote)
                }
            }
            .padding(18)
        }
        .frame(width: 320)
    }

    private func pickerRow(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).frame(width: 56, alignment: .leading)
            Picker("", selection: selection) {
                Section("Fiat") {
                    ForEach(Catalog.fiat, id: \.self) { Text($0).tag($0) }
                }
                Section("Crypto") {
                    ForEach(Catalog.crypto, id: \.self) { Text(Catalog.label($0)).tag($0) }
                }
            }.labelsHidden().frame(maxWidth: .infinity)
        }
    }
}
