//
//  RealtimeTranslatorApp.swift
//  RealtimeTranslator
//
//  應用程式入口點
//

import SwiftUI

@main
struct RealtimeTranslatorApp: App {
    // MARK: - 狀態物件

    @StateObject private var appState = AppState()

    // MARK: - 視圖

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
