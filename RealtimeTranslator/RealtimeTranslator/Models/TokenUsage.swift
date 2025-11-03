//
//  TokenUsage.swift
//  RealtimeTranslator
//
//  Token 使用統計模型
//

import Foundation

/// Token 使用統計
struct TokenUsage: Codable {
    /// 總 token 數
    var totalTokens: Int

    /// 輸入 token 數
    var inputTokens: Int

    /// 輸出 token 數
    var outputTokens: Int

    /// 音訊 token 數
    var audioTokens: Int

    /// 初始化（預設值為 0）
    init(totalTokens: Int = 0, inputTokens: Int = 0, outputTokens: Int = 0, audioTokens: Int = 0) {
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.audioTokens = audioTokens
    }

    /// 預估成本（美元）
    /// 注意：實際費率可能會變動，請參考 OpenAI 官方定價
    var estimatedCost: Double {
        // GPT-4o Realtime API 定價（2024）
        // Input: $0.01 / 1K tokens
        // Output: $0.02 / 1K tokens
        let inputCost = Double(inputTokens) / 1000.0 * 0.01
        let outputCost = Double(outputTokens) / 1000.0 * 0.02
        return inputCost + outputCost
    }

    /// 格式化的成本字串
    var formattedCost: String {
        String(format: "$%.4f", estimatedCost)
    }
}
