import Foundation

/// A tracked currency pair, e.g. base "EUR" quoted in "USD".
/// Symbols are short codes like "USD", "EUR", "BTC".
struct Pair: Identifiable, Codable, Equatable {
    var id = UUID()
    var base: String
    var quote: String
}

/// Static catalog of supported symbols. Fiat codes resolve against
/// `open.er-api.com`; crypto codes map to CoinGecko ids.
enum Catalog {
    /// ~20 common fiat currency codes (all present in open.er-api.com/USD).
    static let fiat: [String] = [
        "USD", "EUR", "JPY", "GBP", "AUD", "CAD", "CHF", "CNY",
        "HKD", "NZD", "SGD", "KRW", "INR", "IDR", "MYR", "THB",
        "PHP", "MXN", "BRL", "ZAR"
    ]

    /// Crypto code → CoinGecko coin id.
    static let cryptoIDs: [String: String] = [
        "BTC":  "bitcoin",
        "ETH":  "ethereum",
        "SOL":  "solana",
        "ADA":  "cardano",
        "DOGE": "dogecoin",
        "XRP":  "ripple"
    ]

    /// Crypto codes in display order.
    static let crypto: [String] = ["BTC", "ETH", "SOL", "ADA", "DOGE", "XRP"]

    /// All selectable symbols (fiat first, then crypto).
    static let all: [String] = fiat + crypto

    static func isCrypto(_ symbol: String) -> Bool {
        cryptoIDs[symbol] != nil
    }

    /// Human label for a symbol, e.g. "BTC · Bitcoin".
    static func label(_ symbol: String) -> String {
        if let id = cryptoIDs[symbol] {
            return "\(symbol) · \(id.capitalized)"
        }
        return symbol
    }
}
