//
//  HistoryManager.swift
//  RealtimeTranslator
//
//  歷史記錄管理器
//

import Foundation

/// 歷史記錄管理器（使用檔案系統儲存）
class HistoryManager {
    // MARK: - 單例
    
    static let shared = HistoryManager()
    
    // MARK: - 私有屬性
    
    /// 歷史記錄檔案 URL
    private var historyFileURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentDirectory.appendingPathComponent("transcription_history.json")
    }
    
    // MARK: - 初始化
    
    private init() {
        print("📁 歷史記錄檔案路徑: \(historyFileURL.path)")
    }
    
    // MARK: - 公開方法
    
    /// 儲存歷史記錄
    /// - Parameter items: 要儲存的項目列表
    func saveHistory(_ items: [TranscriptionItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: historyFileURL, options: [.atomic])
            print("✅ 歷史記錄已儲存: \(items.count) 筆")
        } catch {
            print("❌ 儲存歷史記錄失敗: \(error.localizedDescription)")
        }
    }
    
    /// 載入歷史記錄
    /// - Returns: 歷史記錄列表
    func loadHistory() -> [TranscriptionItem] {
        do {
            // 檢查檔案是否存在
            guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
                print("ℹ️ 歷史記錄檔案不存在，返回空列表")
                return []
            }
            
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([TranscriptionItem].self, from: data)
            print("✅ 歷史記錄已載入: \(items.count) 筆")
            return items
        } catch {
            print("❌ 載入歷史記錄失敗: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 清除歷史記錄
    func clearHistory() {
        do {
            if FileManager.default.fileExists(atPath: historyFileURL.path) {
                try FileManager.default.removeItem(at: historyFileURL)
                print("✅ 歷史記錄檔案已刪除")
            }
        } catch {
            print("❌ 刪除歷史記錄檔案失敗: \(error.localizedDescription)")
        }
    }
    
    /// 取得歷史記錄檔案大小（以 KB 為單位）
    /// - Returns: 檔案大小（KB），如果檔案不存在則返回 0
    func getHistoryFileSize() -> Double {
        do {
            guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
                return 0
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: historyFileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                return Double(fileSize) / 1024.0
            }
        } catch {
            print("❌ 取得檔案大小失敗: \(error.localizedDescription)")
        }
        return 0
    }
}
