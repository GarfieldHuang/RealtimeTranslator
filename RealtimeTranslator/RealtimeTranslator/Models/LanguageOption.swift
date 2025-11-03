//
//  LanguageOption.swift
//  RealtimeTranslator
//
//  支援的語言選項
//

import Foundation

/// 語言選項模型
struct LanguageOption: Identifiable, Hashable, Codable {
    /// 唯一識別碼（使用語言代碼）
    let id: String

    /// 語言名稱
    let name: String

    /// 語言代碼
    let code: String

    /// 國旗 emoji
    let flag: String

    /// 支援的翻譯目標語言列表
    static let availableLanguages: [LanguageOption] = [
        LanguageOption(id: "zh-TW", name: "繁體中文", code: "zh-TW", flag: "🇹🇼"),
        LanguageOption(id: "en", name: "English", code: "en", flag: "🇺🇸"),
        LanguageOption(id: "ja", name: "日本語", code: "ja", flag: "🇯🇵"),
        LanguageOption(id: "ko", name: "한국어", code: "ko", flag: "🇰🇷"),
        LanguageOption(id: "es", name: "Español", code: "es", flag: "🇪🇸"),
        LanguageOption(id: "fr", name: "Français", code: "fr", flag: "🇫🇷")
    ]
    
    /// 支援的輸入語言列表（用於語音辨識）
    static let availableInputLanguages: [LanguageOption] = [
        LanguageOption(id: "auto", name: "自動偵測", code: "auto", flag: "🌐"),
        LanguageOption(id: "zh-TW", name: "繁體中文（台灣）", code: "zh-TW", flag: "🇹🇼"),
        LanguageOption(id: "zh", name: "簡體中文", code: "zh", flag: "🇨🇳"),
        LanguageOption(id: "en", name: "English", code: "en", flag: "🇺🇸"),
        LanguageOption(id: "ja", name: "日本語", code: "ja", flag: "🇯🇵"),
        LanguageOption(id: "ko", name: "한국어", code: "ko", flag: "🇰🇷"),
        LanguageOption(id: "es", name: "Español", code: "es", flag: "🇪🇸"),
        LanguageOption(id: "fr", name: "Français", code: "fr", flag: "🇫🇷"),
        LanguageOption(id: "de", name: "Deutsch", code: "de", flag: "🇩🇪"),
        LanguageOption(id: "pt", name: "Português", code: "pt", flag: "🇵🇹"),
        LanguageOption(id: "ru", name: "Русский", code: "ru", flag: "🇷🇺"),
        LanguageOption(id: "it", name: "Italiano", code: "it", flag: "🇮🇹"),
        LanguageOption(id: "ar", name: "العربية", code: "ar", flag: "🇸🇦"),
        LanguageOption(id: "hi", name: "हिन्दी", code: "hi", flag: "🇮🇳"),
        LanguageOption(id: "th", name: "ไทย", code: "th", flag: "🇹🇭"),
        LanguageOption(id: "vi", name: "Tiếng Việt", code: "vi", flag: "🇻🇳")
    ]

    /// 預設翻譯目標語言（繁體中文）
    static let defaultLanguage = availableLanguages[0]
    
    /// 預設輸入語言（自動偵測）
    static let defaultInputLanguage = availableInputLanguages[0]

    /// 根據語言代碼取得語言選項
    static func language(forCode code: String) -> LanguageOption? {
        availableLanguages.first { $0.code == code }
    }
}
