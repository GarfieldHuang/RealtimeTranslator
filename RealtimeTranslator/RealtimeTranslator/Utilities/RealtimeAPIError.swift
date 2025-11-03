//
//  RealtimeAPIError.swift
//  RealtimeTranslator
//
//  錯誤處理
//

import Foundation

/// Realtime API 錯誤類型
enum RealtimeAPIError: LocalizedError {
    /// 無效的 API Key
    case invalidAPIKey

    /// 連線失敗
    case connectionFailed(String)

    /// 音訊錄製失敗
    case audioRecordingFailed

    /// 音訊格式轉換失敗
    case audioFormatConversionFailed

    /// Session 更新失敗
    case sessionUpdateFailed

    /// 麥克風權限被拒絕
    case microphonePermissionDenied

    /// 網路錯誤
    case networkError(Error)

    /// 錯誤描述
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API Key 無效，請檢查設定"

        case .connectionFailed(let reason):
            return "連線失敗：\(reason)"

        case .audioRecordingFailed:
            return "無法開始錄音，請檢查麥克風權限"

        case .audioFormatConversionFailed:
            return "音訊格式轉換失敗"

        case .sessionUpdateFailed:
            return "Session 設定更新失敗"

        case .microphonePermissionDenied:
            return "麥克風權限被拒絕，請到設定中開啟權限"

        case .networkError(let error):
            return "網路錯誤：\(error.localizedDescription)"
        }
    }

    /// 恢復建議
    var recoverySuggestion: String? {
        switch self {
        case .invalidAPIKey:
            return "請前往設定頁面檢查您的 API Key 是否正確"

        case .connectionFailed:
            return "請檢查網路連線並重試"

        case .audioRecordingFailed, .microphonePermissionDenied:
            return "請前往「設定 > 隱私權與安全性 > 麥克風」開啟權限"

        case .audioFormatConversionFailed:
            return "請重新啟動應用程式"

        case .sessionUpdateFailed:
            return "請重新連線"

        case .networkError:
            return "請檢查網路連線"
        }
    }
}
