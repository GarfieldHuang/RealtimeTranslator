//
//  AppState.swift
//  RealtimeTranslator
//
//  應用程式全域狀態
//

import Foundation
import Combine

/// 應用程式狀態管理
class AppState: ObservableObject {
    /// 是否已完成初次設定
    @Published var hasCompletedOnboarding: Bool

    /// 是否有有效的 API Key
    @Published var hasValidAPIKey: Bool

    /// 是否應顯示 API Key 設定畫面
    @Published var shouldShowAPIKeySetup: Bool

    /// 初始化
    init() {
        // 檢查是否已經完成初始設定
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // 檢查是否有有效的 API Key
        let hasAPIKey = KeychainManager.shared.hasAPIKey()
        self.hasValidAPIKey = hasAPIKey
        self.shouldShowAPIKeySetup = !hasAPIKey
    }

    /// 完成初次設定
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    /// 設定 API Key 配置狀態
    func setAPIKeyConfigured(_ configured: Bool) {
        hasValidAPIKey = configured
        shouldShowAPIKeySetup = !configured
    }
}
