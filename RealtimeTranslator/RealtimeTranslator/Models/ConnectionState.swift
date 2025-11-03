//
//  ConnectionState.swift
//  RealtimeTranslator
//
//  連線狀態模型
//

import Foundation
import SwiftUI

/// WebSocket 連線狀態
enum ConnectionState: Equatable {
    /// 未連線
    case disconnected

    /// 連線中
    case connecting

    /// 已連線
    case connected

    /// 錯誤狀態
    case error(String)

    /// 顯示文字
    var displayText: String {
        switch self {
        case .disconnected:
            return "未連線"
        case .connecting:
            return "連線中..."
        case .connected:
            return "已連線"
        case .error(let message):
            return "錯誤: \(message)"
        }
    }

    /// 狀態顏色
    var statusColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }

    /// Equatable 實作
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected, .connected):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
