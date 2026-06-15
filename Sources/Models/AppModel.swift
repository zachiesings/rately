import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    let rates = RatesService()
    let entitlements = Entitlements()
    let settings = Settings.shared

    /// Free tier limit on the number of tracked pairs.
    static let freePairLimit = 3

    private var bag = Set<AnyCancellable>()

    init() {
        // Re-broadcast nested ObservableObject changes so SwiftUI views update.
        rates.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        entitlements.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        // Keep the refresh timer in sync with the (Pro-controlled) interval.
        settings.$refreshMinutes
            .sink { [weak self] minutes in self?.rates.restartTimer(minutes: minutes) }
            .store(in: &bag)
    }

    var isPro: Bool { entitlements.isPro }

    /// Free users may track up to `freePairLimit` pairs; Pro is unlimited.
    var canAddPair: Bool { isPro || rates.pairs.count < Self.freePairLimit }
}
