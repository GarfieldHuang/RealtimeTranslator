//
//  SettingsView.swift
//  RealtimeTranslator
//
//  設定頁面
//

import SwiftUI

/// 設定視圖
struct SettingsView: View {
    // MARK: - 環境

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    // MARK: - 觀察物件

    @ObservedObject var apiService: RealtimeAPIService

    // MARK: - 計算屬性
    
    private var tokenUsage: TokenUsage {
        return apiService.tokenUsage
    }
    
    private var transcriptionHistoryCount: Int {
        return apiService.transcriptionHistory.count
    }

    // MARK: - 狀態

    @State private var showingAPIKeyManagement = false
    @State private var showingAbout = false
    @State private var showingDeleteConfirmation = false
    @State private var voicePauseThreshold: Double = 1.5
    @State private var audioBufferSize: Double = 150
    @State private var audioSubmissionInterval: Double = 4.0

    // MARK: - 視圖

    var body: some View {
        NavigationView {
            List {
                // API Key 區塊
                Section(header: Text("API Key 設定")) {
                    HStack {
                        Text("狀態")
                        Spacer()
                        Text(KeychainManager.shared.hasAPIKey() ? "已設定" : "未設定")
                            .foregroundColor(KeychainManager.shared.hasAPIKey() ? .green : .red)
                    }

                    Button(action: { showingAPIKeyManagement = true }) {
                        Label("管理 API Key", systemImage: "key.fill")
                    }
                }
                
                // 即時翻譯參數設定
                Section(header: Text("即時翻譯參數")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("語音停頓閾值")
                            Spacer()
                            Text(String(format: "%.1f 秒", voicePauseThreshold))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $voicePauseThreshold, in: 0.5...3.0, step: 0.1)
                            .onChange(of: voicePauseThreshold) { _, newValue in
                                updateAudioSettings()
                            }
                        
                        Text("偵測語音停頓超過此時間後提交翻譯")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("音訊緩衝區大小")
                            Spacer()
                            Text("\(Int(audioBufferSize))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $audioBufferSize, in: 50...300, step: 10)
                            .onChange(of: audioBufferSize) { _, newValue in
                                updateAudioSettings()
                            }
                        
                        Text("緩衝區累積到此大小時強制提交翻譯")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("強制提交間隔")
                            Spacer()
                            Text(String(format: "%.1f 秒", audioSubmissionInterval))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $audioSubmissionInterval, in: 2.0...10.0, step: 0.5)
                            .onChange(of: audioSubmissionInterval) { _, newValue in
                                updateAudioSettings()
                            }
                        
                        Text("超過此時間後強制提交翻譯")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: resetAudioSettings) {
                        Label("重置為預設值", systemImage: "arrow.counterclockwise")
                    }
                }

                // 統計區塊
                Section(header: Text("使用統計")) {
                    HStack {
                        Text("總 Token 數")
                        Spacer()
                        Text("\(tokenUsage.totalTokens)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("輸入 Token")
                        Spacer()
                        Text("\(tokenUsage.inputTokens)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("輸出 Token")
                        Spacer()
                        Text("\(tokenUsage.outputTokens)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("預估成本")
                        Spacer()
                        Text(tokenUsage.formattedCost)
                            .foregroundColor(.secondary)
                    }

                    Button(action: resetStatistics) {
                        Label("重置統計", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }

                // 歷史記錄區塊
                Section(header: Text("歷史記錄")) {
                    HStack {
                        Text("記錄數量")
                        Spacer()
                        Text("\(transcriptionHistoryCount)")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: HistoryListView(apiService: apiService)) {
                        Label("查看所有記錄", systemImage: "list.bullet")
                    }
                    .disabled(transcriptionHistoryCount == 0)

                    // 使用 ShareLink 進行分享（匯出全部）
                    if transcriptionHistoryCount > 0 {
                        ShareLink(item: apiService.exportHistoryAsText()) {
                            Label("匯出全部記錄", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button(action: {}) {
                            Label("匯出全部記錄", systemImage: "square.and.arrow.up")
                        }
                        .disabled(true)
                    }

                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("清除所有記錄", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(transcriptionHistoryCount == 0)
                }

                // 關於區塊
                Section(header: Text("關於")) {
                    Button(action: { showingAbout = true }) {
                        Label("關於 RealtimeTranslator", systemImage: "info.circle")
                    }

                    Link(destination: URL(string: Constants.API.documentationURL)!) {
                        Label("API 文件", systemImage: "book")
                    }

                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAPIKeyManagement) {
                APIKeyManagementView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert("確認刪除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    apiService.clearHistory()
                }
            } message: {
                Text("確定要清除所有歷史記錄嗎？此操作無法復原。")
            }
            .onAppear {
                loadAudioSettings()
            }
        }
    }

    // MARK: - 方法

    /// 載入音訊設定
    private func loadAudioSettings() {
        let settings = apiService.getAudioSubmissionSettings()
        voicePauseThreshold = settings.pauseThreshold
        audioBufferSize = Double(settings.bufferSize)
        audioSubmissionInterval = settings.submissionInterval
    }
    
    /// 更新音訊設定
    private func updateAudioSettings() {
        apiService.updateAudioSubmissionSettings(
            pauseThreshold: voicePauseThreshold,
            bufferSize: Int(audioBufferSize),
            submissionInterval: audioSubmissionInterval
        )
    }
    
    /// 重置音訊設定為預設值
    private func resetAudioSettings() {
        voicePauseThreshold = 1.5
        audioBufferSize = 150
        audioSubmissionInterval = 4.0
        updateAudioSettings()
    }

    /// 重置統計
    private func resetStatistics() {
        apiService.tokenUsage = TokenUsage()
    }
}

// MARK: - 歷史記錄列表視圖

struct HistoryListView: View {
    @ObservedObject var apiService: RealtimeAPIService
    
    var body: some View {
        List {
            if apiService.transcriptionHistory.isEmpty {
                Text("暫無記錄")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(apiService.transcriptionHistory.reversed()) { item in
                    HistoryItemRow(item: item, onDelete: {
                        deleteItem(item)
                    })
                }
            }
        }
        .navigationTitle("翻譯記錄")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteItem(_ item: TranscriptionItem) {
        if let index = apiService.transcriptionHistory.firstIndex(where: { $0.id == item.id }) {
            apiService.transcriptionHistory.remove(at: index)
        }
    }
}

// MARK: - 歷史記錄項目行

struct HistoryItemRow: View {
    let item: TranscriptionItem
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 時間標籤和操作按鈕
            HStack {
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 分享按鈕（使用 ShareLink）
                ShareLink(item: formatSingleItem()) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                // 刪除按鈕
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            // 原文
            VStack(alignment: .leading, spacing: 4) {
                Text("原文")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.originalText)
                    .font(.body)
            }
            
            Divider()
            
            // 翻譯
            VStack(alignment: .leading, spacing: 4) {
                Text("翻譯")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.translatedText)
                    .font(.body)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .alert("確認刪除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("確定要刪除這筆記錄嗎？")
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter.string(from: item.timestamp)
    }
    
    private func formatSingleItem() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = timeFormatter.string(from: item.timestamp)
        
        return """
        RealtimeTranslator 翻譯記錄
        
        時間: \(timeString)
        目標語言: \(item.targetLanguage)
        
        原文:
        \(item.originalText)
        
        翻譯:
        \(item.translatedText)
        """
    }
}

// MARK: - 預覽

#Preview {
    Text("SettingsView Preview")
}
