import SwiftUI

@main
struct RatelyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
        } label: {
            Text(model.rates.menuBarText)
                .font(.system(size: 12, weight: .medium))
        }
        .menuBarExtraStyle(.window)
    }
}
