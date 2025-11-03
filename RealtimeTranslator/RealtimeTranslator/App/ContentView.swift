//
//  ContentView.swift
//  RealtimeTranslator
//
//  主要內容視圖
//

import SwiftUI

/// 內容視圖（根據狀態顯示不同畫面）
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.shouldShowAPIKeySetup {
            // 顯示 API Key 設定畫面
            APIKeySetupView()
                .transition(.opacity)
        } else {
            // 顯示主畫面（包含錄音翻譯和即時翻譯功能）
            MainView()
                .transition(.opacity)
        }
    }
}

// MARK: - 預覽

#Preview {
    ContentView()
        .environmentObject(AppState())
}
