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
    @State private var isVADEnabled: Bool = true
    @State private var vadThreshold: Double = 0.01
    @State private var isSmartVADEnabled: Bool = true
    @State private var smartVADSilenceThreshold: Double = 1.0
    @State private var smartVADMinimumDuration: Double = 0.05
    @State private var selectedInputLanguage: LanguageOption = .defaultInputLanguage
    @State private var selectedModel: RealtimeModel = .defaultModel

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
                
                // API 模型選擇
                Section(header: Text("API 模型")) {
                    Picker("Realtime 模型", selection: $selectedModel) {
                        ForEach(RealtimeModel.allCases) { model in
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                if model.isDeprecated {
                                    Text(model.description)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            .tag(model)
                        }
                    }
                    .onChange(of: selectedModel) { _, newValue in
                        apiService.setRealtimeModel(newValue)
                    }
                    
                    Text(selectedModel.description)
                        .font(.caption)
                        .foregroundColor(selectedModel.isDeprecated ? .orange : .secondary)
                        .padding(.vertical, 4)
                }
                
                // 語言設定區塊
                Section(header: Text("語言設定")) {
                    Picker("輸入語言", selection: $selectedInputLanguage) {
                        ForEach(LanguageOption.availableInputLanguages) { language in
                            HStack {
                                Text(language.flag)
                                Text(language.name)
                            }
                            .tag(language)
                        }
                    }
                    .onChange(of: selectedInputLanguage) { _, newValue in
                        apiService.updateInputLanguage(newValue)
                    }
                    
                    Text("選擇輸入音訊的語言以提高辨識準確度。選擇「自動偵測」讓系統自動判斷。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
                
                // 智能 VAD 設定（Speech Framework）
                Section(header: Text("智能語音檢測 (推薦)")) {
                    Toggle(isOn: $isSmartVADEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("啟用智能 VAD")
                            Text("使用 AI 精準檢測人聲，大幅降低成本")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: isSmartVADEnabled) { _, newValue in
                        apiService.setSmartVADEnabled(newValue)
                    }
                    
                    if isSmartVADEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("停頓檢測時間")
                                Spacer()
                                Text(String(format: "%.1f 秒", smartVADSilenceThreshold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $smartVADSilenceThreshold, in: 0.5...2.0, step: 0.1)
                                .onChange(of: smartVADSilenceThreshold) { _, newValue in
                                    apiService.setSmartVADSilenceThreshold(newValue)
                                }
                            
                            Text("說話停頓超過此時間後送出翻譯")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("最短語音長度")
                                Spacer()
                                Text(String(format: "%.2f 秒", smartVADMinimumDuration))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $smartVADMinimumDuration, in: 0.05...1.0, step: 0.05)
                                .onChange(of: smartVADMinimumDuration) { _, newValue in
                                    apiService.setSmartVADMinimumDuration(newValue)
                                }
                            
                            Text("低於此長度的語音會被忽略（避免誤觸發）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Text("💡 智能 VAD 使用 iOS 語音識別技術，能準確區分人聲和噪音，只在真正說話時才送出 API 請求，可節省 60-80% 成本")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.vertical, 4)
                    }
                }
                
                // 傳統 VAD 設定（備用）
                Section(header: Text("傳統語音檢測 (備用)")) {
                    Toggle(isOn: $isVADEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("啟用傳統 VAD")
                            Text("基於音量的簡單檢測")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: isVADEnabled) { _, newValue in
                        apiService.setVADEnabled(newValue)
                    }
                    .disabled(isSmartVADEnabled)
                    
                    if isVADEnabled && !isSmartVADEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("靈敏度")
                                Spacer()
                                Text(formatVADThreshold(vadThreshold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $vadThreshold, in: 0.005...0.05, step: 0.001)
                                .onChange(of: vadThreshold) { _, newValue in
                                    apiService.setVADThreshold(Float(newValue))
                                }
                            
                            Text("越低越靈敏，建議範圍 0.005-0.05")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
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
                    
                    HStack {
                        Text("儲存空間")
                        Spacer()
                        Text(formatFileSize(HistoryManager.shared.getHistoryFileSize()))
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
                        Text("1.3.3")
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
        
        let vadSettings = apiService.getVADSettings()
        isVADEnabled = vadSettings.enabled
        vadThreshold = Double(vadSettings.threshold)
        
        let smartVADSettings = apiService.getSmartVADSettings()
        isSmartVADEnabled = smartVADSettings.enabled
        smartVADSilenceThreshold = smartVADSettings.silenceThreshold
        smartVADMinimumDuration = smartVADSettings.minimumDuration
        
        // 載入當前輸入語言設定
        selectedInputLanguage = apiService.getInputLanguage()
        
        // 載入當前模型設定
        selectedModel = apiService.getRealtimeModel()
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
        isVADEnabled = true
        vadThreshold = 0.01
        isSmartVADEnabled = true
        smartVADSilenceThreshold = 1.0
        smartVADMinimumDuration = 0.05
        
        updateAudioSettings()
        apiService.setVADEnabled(isVADEnabled)
        apiService.setVADThreshold(Float(vadThreshold))
        apiService.setSmartVADEnabled(isSmartVADEnabled)
        apiService.setSmartVADSilenceThreshold(smartVADSilenceThreshold)
        apiService.setSmartVADMinimumDuration(smartVADMinimumDuration)
    }
    
    /// 格式化 VAD 閾值顯示
    private func formatVADThreshold(_ value: Double) -> String {
        if value < 0.01 {
            return String(format: "%.3f (高靈敏)", value)
        } else if value < 0.02 {
            return String(format: "%.3f (標準)", value)
        } else {
            return String(format: "%.3f (低靈敏)", value)
        }
    }

    /// 重置統計
    private func resetStatistics() {
        apiService.tokenUsage = TokenUsage()
    }
    
    /// 格式化檔案大小
    private func formatFileSize(_ sizeInKB: Double) -> String {
        if sizeInKB < 1 {
            return "< 1 KB"
        } else if sizeInKB < 1024 {
            return String(format: "%.1f KB", sizeInKB)
        } else {
            return String(format: "%.2f MB", sizeInKB / 1024.0)
        }
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
