//
//  MainView.swift
//  RealtimeTranslator
//
//  主畫面
//

import SwiftUI
import Foundation

/// 主視圖
struct MainView: View {
    // MARK: - 環境物件

    @EnvironmentObject var appState: AppState

    // MARK: - 狀態物件

    @StateObject private var apiService = RealtimeAPIService()

    // MARK: - 狀態

    @State private var selectedLanguage: LanguageOption = .defaultLanguage
    @State private var showingSettings = false
    @State private var showingLanguagePicker = false
    @State private var showingInputLanguagePicker = false
    @State private var selectedInputLanguage: LanguageOption = .defaultInputLanguage
    @State private var translationMode: TranslationMode = .live

    // MARK: - 枚舉
    
    /// 翻譯模式
    enum TranslationMode: String, CaseIterable {
        case live = "即時翻譯"
        case recording = "錄音翻譯"
        
        var icon: String {
            switch self {
            case .recording:
                return "mic.circle"
            case .live:
                return "waveform.circle"
            }
        }
        
        var activeIcon: String {
            switch self {
            case .recording:
                return "mic.circle.fill"
            case .live:
                return "waveform.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .recording:
                return .blue
            case .live:
                return .purple
            }
        }
        
        var activeColor: Color {
            switch self {
            case .recording:
                return .red
            case .live:
                return .purple
            }
        }
    }

    // MARK: - 計算屬性
    
    /// 是否正在翻譯（任一模式）
    private var isTranslating: Bool {
        return apiService.isRecording || apiService.isLiveTranslating
    }
    
    /// 按鈕是否可用
    private var isEnabled: Bool {
        return apiService.connectionState == .connected
    }
    
    /// 按鈕文字
    private var buttonText: String {
        switch translationMode {
        case .recording:
            return apiService.isRecording ? "停止錄音" : "開始錄音"
        case .live:
            return apiService.isLiveTranslating ? "停止即時翻譯" : "開始即時翻譯"
        }
    }
    
    /// 按鈕圖示
    private var buttonIcon: String {
        switch translationMode {
        case .recording:
            return apiService.isRecording ? translationMode.activeIcon : translationMode.icon
        case .live:
            return apiService.isLiveTranslating ? translationMode.activeIcon : translationMode.icon
        }
    }
    
    /// 按鈕背景顏色（即時翻譯模式使用顏色變化取代呼吸效果）
    private var buttonBackgroundColor: Color {
        if !isEnabled {
            return .gray
        }
        
        switch translationMode {
        case .recording:
            // 錄音模式：使用紅色表示正在錄音
            return apiService.isRecording ? .red : .blue
        case .live:
            // 即時翻譯模式：綠色表示開始，紅色表示停止
            return apiService.isLiveTranslating ? .red : .green
        }
    }
    
    /// 清除按鈕文字
    private var clearButtonText: String {
        switch translationMode {
        case .recording:
            return "清除記錄"
        case .live:
            return "清除內容"
        }
    }
    
    /// 清除按鈕是否禁用
    private var clearButtonDisabled: Bool {
        switch translationMode {
        case .recording:
            return apiService.transcriptionHistory.isEmpty
        case .live:
            return apiService.currentTranscription.isEmpty && apiService.currentTranslation.isEmpty
        }
    }
    
    /// 即時翻譯按鈕背景顏色
    private var liveTranslationBackgroundColor: Color {
        if apiService.connectionState != .connected {
            return .gray
        } else if apiService.isLiveTranslating {
            return .purple
        } else if apiService.isRecording && !apiService.isLiveTranslating {
            return .gray  // 錄音翻譯進行時禁用
        } else {
            return .orange
        }
    }

    // MARK: - 視圖

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 狀態列
                StatusBar(
                    connectionState: apiService.connectionState,
                    tokenUsage: apiService.tokenUsage
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // 原文顯示區
                TranscriptionView(
                    text: apiService.currentTranscription,
                    language: apiService.inputLanguage
                )
                .frame(maxHeight: .infinity)

                Divider()

                // 翻譯顯示區
                TranslationView(
                    text: apiService.currentTranslation,
                    language: selectedLanguage
                )
                .frame(maxHeight: .infinity)

                Divider()

                // 控制按鈕區
                VStack(spacing: 12) {
                    // 翻譯模式選擇器
                    VStack(spacing: 4) {
                        Text("翻譯模式")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Picker("翻譯模式", selection: $translationMode) {
                            ForEach(TranslationMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isTranslating)
                    }
                    
                    // 統一翻譯按鈕
                    Button(action: {
                        toggleTranslation()
                    }) {
                        HStack(spacing: 10) {
                            // 圖示
                            Image(systemName: buttonIcon)
                                .font(.title3)

                            // 文字
                            Text(buttonText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(buttonBackgroundColor)
                        .cornerRadius(10)
                    }
                    .disabled(!isEnabled)
                    .animation(.easeInOut(duration: 0.3), value: buttonBackgroundColor)

                    // 功能按鈕列
                    HStack(spacing: 12) {
                        // 動態清除按鈕
                        Button(action: {
                            switch translationMode {
                            case .recording:
                                apiService.clearHistory()
                            case .live:
                                if apiService.isLiveTranslating {
                                    apiService.clearCurrentContent()
                                } else {
                                    apiService.clearCurrentContent()
                                }
                            }
                        }) {
                            Label(clearButtonText, systemImage: "trash")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .disabled(clearButtonDisabled)

                        // 重新連線按鈕（當連線狀態異常時顯示）
                        if case .disconnected = apiService.connectionState {
                            Button(action: {
                                connectToAPI()
                            }) {
                                Label("重新連線", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.blue)
                        } else if case .error = apiService.connectionState {
                            Button(action: {
                                connectToAPI()
                            }) {
                                Label("重新連線", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.orange)
                        }

                        // 輸入語言選擇按鈕
                        Button(action: {
                            showingInputLanguagePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Text("輸入:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(selectedInputLanguage.flag)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.bordered)

                        // 輸出語言選擇按鈕
                        Button(action: {
                            showingLanguagePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Text("輸出:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(selectedLanguage.flag)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationTitle("RealtimeTranslator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(apiService: apiService)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView(
                    selectedLanguage: $selectedLanguage,
                    title: "選擇輸出語言",
                    languages: LanguageOption.availableLanguages
                )
            }
            .sheet(isPresented: $showingInputLanguagePicker) {
                LanguagePickerView(
                    selectedLanguage: $selectedInputLanguage,
                    title: "選擇輸入語言",
                    languages: LanguageOption.availableInputLanguages
                )
            }
            .onAppear {
                connectToAPI()
                selectedInputLanguage = apiService.getInputLanguage()
            }
            .onDisappear {
                apiService.disconnect()
            }
            .onChange(of: selectedLanguage) { _, newLanguage in
                apiService.updateTargetLanguage(newLanguage)
            }
            .onChange(of: selectedInputLanguage) { _, newLanguage in
                apiService.updateInputLanguage(newLanguage)
            }
        }
    }

    // MARK: - 方法

    /// 連線到 API
    private func connectToAPI() {
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            appState.setAPIKeyConfigured(false)
            return
        }

        apiService.connect(apiKey: apiKey)
    }

    /// 切換翻譯狀態（統一方法）
    private func toggleTranslation() {
        switch translationMode {
        case .recording:
            toggleRecording()
        case .live:
            toggleLiveTranslation()
        }
    }

    /// 切換錄音狀態
    private func toggleRecording() {
        if apiService.isRecording {
            apiService.stopRecording()
        } else {
            apiService.startRecording()
        }
    }

    /// 切換即時翻譯狀態
    private func toggleLiveTranslation() {
        if apiService.isLiveTranslating {
            apiService.stopLiveTranslation()
        } else {
            apiService.startLiveTranslation()
        }
    }
}

/// 語言選擇視圖
struct LanguagePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLanguage: LanguageOption
    let title: String
    let languages: [LanguageOption]

    var body: some View {
        NavigationView {
            List(languages) { language in
                Button(action: {
                    selectedLanguage = language
                    dismiss()
                }) {
                    HStack {
                        Text(language.flag)
                            .font(.title2)

                        Text(language.name)
                            .font(.body)

                        Spacer()

                        if language.id == selectedLanguage.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 預覽

#Preview {
    MainView()
        .environmentObject(AppState())
}
