//
//  TranscriptionItem.swift
//  RealtimeTranslator
//
//  即時翻譯項目模型
//

import Foundation

/// 轉錄與翻譯項目
struct TranscriptionItem: Identifiable, Codable {
    /// 唯一識別碼
    let id: UUID

    /// 原始語言文字
    let originalText: String

    /// 翻譯後的文字
    let translatedText: String

    /// 時間戳記
    let timestamp: Date

    /// 來源語言（可選）
    let sourceLanguage: String?

    /// 目標語言
    let targetLanguage: String

    /// 初始化方法
    init(originalText: String, translatedText: String, targetLanguage: String, sourceLanguage: String? = nil) {
        self.id = UUID()
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = Date()
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}
