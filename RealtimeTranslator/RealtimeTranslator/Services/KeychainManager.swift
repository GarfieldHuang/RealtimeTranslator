//
//  KeychainManager.swift
//  RealtimeTranslator
//
//  Keychain 管理服務
//  安全地儲存和讀取 API Key
//

import Foundation
import Security

/// Keychain 相關錯誤
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "找不到儲存的項目"
        case .duplicateItem:
            return "項目已存在"
        case .invalidData:
            return "資料格式無效"
        case .unexpectedStatus(let status):
            return "發生錯誤（狀態碼: \(status)）"
        }
    }
}

/// Keychain 管理類別
class KeychainManager {
    // MARK: - 單例模式

    static let shared = KeychainManager()

    private init() {}

    // MARK: - 常數定義

    /// Service 名稱
    private let service = "com.realtimetranslator.apikey"

    /// Account 名稱
    private let account = "openai_api_key"

    // MARK: - 公開方法

    /// 儲存 API Key
    /// - Parameter apiKey: OpenAI API Key
    /// - Throws: KeychainError
    func saveAPIKey(_ apiKey: String) throws {
        // 檢查格式
        guard Self.validateAPIKeyFormat(apiKey) else {
            throw KeychainError.invalidData
        }

        // 轉換為 Data
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // 準備查詢字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // 先嘗試刪除舊的項目
        SecItemDelete(query as CFDictionary)

        // 新增項目
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 讀取 API Key
    /// - Returns: API Key 字串，若不存在則返回 nil
    func getAPIKey() -> String? {
        // 準備查詢字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }

    /// 刪除 API Key
    /// - Throws: KeychainError
    func deleteAPIKey() throws {
        // 準備查詢字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 檢查是否已設定 API Key
    /// - Returns: 是否存在 API Key
    func hasAPIKey() -> Bool {
        getAPIKey() != nil
    }

    // MARK: - 靜態方法

    /// 驗證 API Key 格式
    /// - Parameter apiKey: 待驗證的 API Key
    /// - Returns: 是否為有效格式
    static func validateAPIKeyFormat(_ apiKey: String) -> Bool {
        // OpenAI API Key 格式：以 "sk-" 或 "sk-proj-" 開頭
        // 長度通常在 40-60 個字元之間
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("sk-") || trimmed.hasPrefix("sk-proj-")) &&
               trimmed.count >= 20 &&
               trimmed.count <= 200
    }
}
