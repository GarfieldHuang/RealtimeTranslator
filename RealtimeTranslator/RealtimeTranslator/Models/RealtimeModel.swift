//
//  RealtimeModel.swift
//  RealtimeTranslator
//
//  OpenAI Realtime API 模型選項
//

import Foundation

/// Realtime API 模型選項
enum RealtimeModel: String, CaseIterable, Identifiable, Codable {
    /// 穩定版本（推薦，無 preview 無日期）
    case stable = "gpt-realtime"
    
    /// Preview 版本 2024-12-17
    case preview_2024_12_17 = "gpt-4o-realtime-preview-2024-12-17"
    
    /// Preview 版本 2024-10-01（即將棄用）
    case preview_2024_10_01 = "gpt-4o-realtime-preview-2024-10-01"
    
    var id: String { rawValue }
    
    /// 顯示名稱
    var displayName: String {
        switch self {
        case .stable:
            return "gpt-realtime (穩定版，推薦)"
        case .preview_2024_12_17:
            return "gpt-4o-realtime-preview (2024-12-17)"
        case .preview_2024_10_01:
            return "gpt-4o-realtime-preview (2024-10-01，即將棄用)"
        }
    }
    
    /// 簡短名稱
    var shortName: String {
        switch self {
        case .stable:
            return "穩定版"
        case .preview_2024_12_17:
            return "Preview (12/17)"
        case .preview_2024_10_01:
            return "Preview (10/01)"
        }
    }
    
    /// 描述
    var description: String {
        switch self {
        case .stable:
            return "最新穩定版本，價格比 preview 便宜 20%"
        case .preview_2024_12_17:
            return "2024 年 12 月發布的 preview 版本"
        case .preview_2024_10_01:
            return "⚠️ 將於 2025 年 9 月棄用"
        }
    }
    
    /// 是否已棄用
    var isDeprecated: Bool {
        switch self {
        case .preview_2024_10_01:
            return true
        default:
            return false
        }
    }
    
    /// 預設模型
    static var defaultModel: RealtimeModel {
        return .stable
    }
}
