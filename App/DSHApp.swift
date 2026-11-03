import SwiftUI

@main
struct DSHApp: App {
    @State private var store = AppStore()
    @State private var connection = ConnectionStore()
    @AppStorage("appearance") private var appearance = "system"
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(connection)
                .tint(DSHTheme.blue)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { store.stopAll() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        RootLayout()
            .sheet(item: $store.presentedPanel) { panel in
                NavigationStack {
                    switch panel {
                    case .computers:
                        DevicesView()
                            .toolbar { closeButton }
                    case .settings:
                        SettingsView()
                            .toolbar { closeButton }
                    case .pairing:
                        PairingView()
                    }
                }
            }
    }

    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("完成") { store.presentedPanel = nil }
        }
    }
}
