//
//  StatusBar.swift
//  RealtimeTranslator
//
//  狀態列元件
//

import SwiftUI

/// 狀態列視圖
struct StatusBar: View {
    let connectionState: ConnectionState
    let tokenUsage: TokenUsage

    var body: some View {
        HStack {
            // 連線狀態
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionState.statusColor)
                    .frame(width: 10, height: 10)

                Text(connectionState.displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Token 使用統計
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Tokens: \(tokenUsage.totalTokens)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 預覽

#Preview {
    VStack {
        StatusBar(
            connectionState: .connected,
            tokenUsage: TokenUsage(totalTokens: 1234)
        )
        .padding()

        StatusBar(
            connectionState: .connecting,
            tokenUsage: TokenUsage()
        )
        .padding()

        StatusBar(
            connectionState: .error("連線失敗"),
            tokenUsage: TokenUsage()
        )
        .padding()
    }
}
