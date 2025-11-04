//
//  Constants.swift
//  RealtimeTranslator
//
//  常數定義
//

import Foundation
import SwiftUI
import AVFAudio

/// 應用程式常數
enum Constants {
    // MARK: - API 相關

    enum API {
        /// WebSocket 基礎 URL
        static let baseURL = "wss://api.openai.com/v1/realtime"

        /// API 文件 URL
        static let documentationURL = "https://platform.openai.com/docs/guides/realtime"

        /// API Key 取得 URL
        static let apiKeyURL = "https://platform.openai.com/api-keys"
    }

    // MARK: - 音訊相關

    enum Audio {
        /// 目標採樣率（Hz）
        static let sampleRate: Double = 24000.0

        /// 聲道數
        static let channels: AVAudioChannelCount = 1

        /// 位元深度
        static let bitDepth = 16

        /// Buffer 大小（frames）
        static let bufferSize: AVAudioFrameCount = 1024

        /// 音訊 chunk 間隔（秒）
        static let chunkInterval: TimeInterval = 0.1
        
        /// 語音停頓檢測閾值（秒）
        static let voicePauseThreshold: TimeInterval = 1.5
        
        /// 最大音訊緩衝區大小（即時翻譯模式）
        static let maxAudioBufferSize = 150
        
        /// 智能提交檢查間隔（秒）
        static let smartSubmissionCheckInterval: TimeInterval = 0.2
    }

    // MARK: - UI 相關

    enum UI {
        /// 主色調
        static let primaryColor = Color.blue

        /// 原文區塊背景色
        static let originalTextBackground = Color.gray.opacity(0.1)

        /// 翻譯區塊背景色
        static let translationBackground = Color.gray.opacity(0.15)

        /// 錄音中狀態色
        static let recordingColor = Color.red

        /// 即時翻譯狀態色
        static let liveTranslationColor = Color.purple

        /// 成功狀態色
        static let successColor = Color.green

        /// 錯誤狀態色
        static let errorColor = Color.red

        /// 圓角半徑
        static let cornerRadius: CGFloat = 12

        /// 間距
        static let spacing: CGFloat = 16

        /// 內邊距
        static let padding: CGFloat = 16
    }

    // MARK: - 動畫相關

    enum Animation {
        /// 預設動畫時長
        static let duration: TimeInterval = 0.3

        /// 脈衝動畫時長
        static let pulseDuration: TimeInterval = 1.0
    }

    // MARK: - 儲存相關

    enum Storage {
        /// UserDefaults Keys
        enum UserDefaultsKey {
            static let hasCompletedOnboarding = "hasCompletedOnboarding"
            static let targetLanguageCode = "targetLanguageCode"
            static let tokenUsage = "tokenUsage"
        }

        /// Keychain Keys
        enum KeychainKey {
            static let service = "com.realtimetranslator.apikey"
            static let account = "openai_api_key"
        }
    }

    // MARK: - 限制相關

    enum Limits {
        /// 最大歷史記錄數
        static let maxHistoryItems = 100

        /// 最大重連次數
        static let maxReconnectAttempts = 5

        /// Keepalive 間隔（秒）
        static let keepaliveInterval: TimeInterval = 4.0
    }
}
