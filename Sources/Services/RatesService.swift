import SwiftUI
import Combine

/// Fetches live fiat & crypto rates from free, key-less public APIs and
/// computes any base→quote conversion from a unified USD-denominated table.
///
/// - Fiat: `https://open.er-api.com/v6/latest/USD`
/// - Crypto: `https://api.coingecko.com/api/v3/simple/price`
///
/// `usdRate[symbol]` is "how many USD one unit of `symbol` is worth":
///   USD = 1, EUR ≈ 1.08, BTC ≈ 64000. From that, the rate of any pair is
///   `quotePerBase = usdRate[base] / usdRate[quote]`.
@MainActor
final class RatesService: ObservableObject {
    @Published private(set) var usdRate: [String: Double] = ["USD": 1.0]
    @Published var pairs: [Pair] = []
    @Published private(set) var loading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private let d = UserDefaults.standard
    private let pairsKey = "rately.pairs"
    private var timer: Timer?

    init() {
        pairs = Self.loadPairs() ?? Self.defaultPairs
        Task { await refresh() }
        // 10-min auto-refresh (the interval can be overridden by Settings via
        // `restartTimer(minutes:)`).
        restartTimer(minutes: Settings.shared.refreshMinutes)
    }

    // MARK: - Pairs persistence

    private static let defaultPairs: [Pair] = [
        Pair(base: "USD", quote: "EUR"),
        Pair(base: "BTC", quote: "USD"),
        Pair(base: "USD", quote: "JPY")
    ]

    private static func loadPairs() -> [Pair]? {
        guard let data = UserDefaults.standard.data(forKey: "rately.pairs"),
              let decoded = try? JSONDecoder().decode([Pair].self, from: data),
              !decoded.isEmpty else { return nil }
        return decoded
    }

    private func savePairs() {
        if let data = try? JSONEncoder().encode(pairs) {
            d.set(data, forKey: pairsKey)
        }
    }

    /// The pair shown in the menu bar (first tracked pair).
    var primary: Pair? { pairs.first }

    func makePrimary(_ pair: Pair) {
        guard let idx = pairs.firstIndex(of: pair), idx != 0 else { return }
        pairs.remove(at: idx)
        pairs.insert(pair, at: 0)
        savePairs()
    }

    func addPair(base: String, quote: String) {
        let pair = Pair(base: base, quote: quote)
        guard !pairs.contains(where: { $0.base == base && $0.quote == quote }) else { return }
        pairs.append(pair)
        savePairs()
    }

    func removePair(_ pair: Pair) {
        pairs.removeAll { $0.id == pair.id }
        savePairs()
    }

    // MARK: - Rate computation

    /// quotePerBase, e.g. for USD/EUR returns EUR per 1 USD.
    func rate(for pair: Pair) -> Double? {
        guard let b = usdRate[pair.base], let q = usdRate[pair.quote], q != 0 else { return nil }
        return b / q
    }

    /// Convert an amount of `from` into `to`.
    func convert(amount: Double, from: String, to: String) -> Double? {
        guard let f = usdRate[from], let t = usdRate[to], t != 0 else { return nil }
        return amount * (f / t)
    }

    // MARK: - Menu-bar text

    /// Compact text for the menu-bar label, e.g. "EUR 0.92" or "BTC 64.0k".
    var menuBarText: String {
        guard let pair = primary else { return "Rately" }
        guard let r = rate(for: pair) else { return pair.quote }
        return "\(pair.quote) \(Self.compact(r))"
    }

    // MARK: - Networking

    func refresh() async {
        loading = true
        defer { loading = false }
        var newError: String?

        var map: [String: Double] = ["USD": 1.0]

        // Fiat
        if let fiat = await fetchFiat() {
            for code in Catalog.fiat where code != "USD" {
                if let perUSD = fiat[code], perUSD != 0 {
                    // er-api gives "units of CODE per 1 USD"; invert to USD-per-unit.
                    map[code] = 1.0 / perUSD
                }
            }
        } else {
            newError = "Couldn't load currency rates."
        }

        // Crypto (price already in USD per coin)
        if let crypto = await fetchCrypto() {
            for (code, id) in Catalog.cryptoIDs {
                if let usd = crypto[id]?["usd"], usd != 0 {
                    map[code] = usd
                }
            }
        } else if newError == nil {
            newError = "Couldn't load crypto prices."
        }

        // Merge: keep previously-known values for anything missing this round.
        if map.count > 1 {
            for (k, v) in map { usdRate[k] = v }
            lastUpdated = Date()
        }
        lastError = newError
    }

    private func fetchFiat() async -> [String: Double]? {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(FiatResponse.self, from: data)
            guard decoded.result == "success" else { return nil }
            return decoded.rates
        } catch {
            return nil
        }
    }

    private func fetchCrypto() async -> [String: [String: Double]]? {
        let ids = Catalog.crypto.compactMap { Catalog.cryptoIDs[$0] }.joined(separator: ",")
        let str = "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd"
        guard let url = URL(string: str) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode([String: [String: Double]].self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Timer

    func restartTimer(minutes: Int) {
        timer?.invalidate()
        let interval = TimeInterval(max(1, minutes) * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Formatting

    private static let plain: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    /// Full formatting for in-app rate display, e.g. "0.92", "156.7", "64,000".
    static func format(_ value: Double) -> String {
        let abs = Swift.abs(value)
        let digits: Int
        if abs >= 1000 { digits = 0 }
        else if abs >= 1 { digits = 2 }
        else { digits = 4 }
        plain.maximumFractionDigits = digits
        return plain.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Very compact formatting for the menu bar, e.g. "0.92" or "64.0k".
    static func compact(_ value: Double) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if abs >= 1_000 {
            return String(format: "%.1fk", value / 1_000)
        } else if abs >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.4f", value)
        }
    }
}

// MARK: - Decoding

private struct FiatResponse: Decodable {
    let result: String
    let base_code: String
    let rates: [String: Double]
}
