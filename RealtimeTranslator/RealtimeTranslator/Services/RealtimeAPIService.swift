//
//  RealtimeAPIService.swift
//  RealtimeTranslator
//
//  OpenAI Realtime API 服務
//

import Foundation
import Combine

/// Realtime API 服務類別
class RealtimeAPIService: ObservableObject {
    // MARK: - 發布屬性

    /// 連線狀態
    @Published var connectionState: ConnectionState = .disconnected

    /// 當前轉錄文字（即時更新）
    @Published var currentTranscription: String = ""

    /// 當前翻譯文字（即時更新）
    @Published var currentTranslation: String = ""

    /// 歷史記錄
    @Published var transcriptionHistory: [TranscriptionItem] = [] {
        didSet {
            // 每次歷史記錄變更時自動儲存
            HistoryManager.shared.saveHistory(transcriptionHistory)
        }
    }

    /// Token 使用統計
    @Published var tokenUsage: TokenUsage = TokenUsage()

    /// 是否正在錄音
    @Published var isRecording: Bool = false

    /// 是否正在進行即時翻譯
    @Published var isLiveTranslating: Bool = false

    /// 輸入音訊語言
    @Published var inputLanguage: LanguageOption = .defaultInputLanguage

    // MARK: - 私有屬性

    /// WebSocket 管理器
    private let webSocketManager = WebSocketManager()

    /// 音訊錄製器
    private let audioRecorder = AudioRecorder()
    
    /// 語音活動檢測器（Speech Framework）
    private var voiceActivityDetector: VoiceActivityDetector?

    /// 目標翻譯語言
    private var targetLanguage: LanguageOption = .defaultLanguage

    /// API Key
    private var apiKey: String?

    /// WebSocket URL
    private let baseURL = "wss://api.openai.com/v1/realtime"

    /// 當前使用的模型
    private var selectedModel: RealtimeModel = .defaultModel

    /// 當前會話 ID
    private var currentSessionId: String?

    /// 當前轉錄是否完成
    private var isTranscriptionComplete = false

    /// 即時翻譯模式定時器
    private var liveTranslationTimer: Timer?
    
    /// 語音活動檢測狀態
    private var isVoiceActive = false
    
    /// 語音停頓檢測計時器
    private var voicePauseTimer: Timer?
    
    /// 語音停頓閾值（秒）- 檢測到停頓後提交音訊
    private var voicePauseThreshold: TimeInterval = 1.5
    
    /// 最後一次音訊活動時間
    private var lastAudioActivityTime = Date()
    
    /// 音訊累積緩衝區大小計數器
    private var audioBufferSize = 0
    
    /// 最大音訊緩衝區大小（避免過長的音訊片段）
    private var maxAudioBufferSize = 150 // 約5秒的音訊
    
    /// 強制提交音訊的最長時間間隔（秒）- 安全網機制
    private var maxAudioSubmissionInterval: TimeInterval = 4.0
    
    /// 是否為新的翻譯回應（用於添加斷行）
    private var isNewTranslationResponse = true
    
    /// 是否啟用 VAD（語音活動檢測）
    private var isVADEnabled = true
    
    /// VAD 靈敏度閾值（0.0-1.0，越低越靈敏）- 舊版音量檢測用
    private var vadThreshold: Float = 0.01
    
    /// 是否啟用智能 VAD（Speech Framework）
    private var isSmartVADEnabled = false
    
    /// 智能 VAD 靜默閾值（秒）
    private var smartVADSilenceThreshold: TimeInterval = 1.0
    
    /// 智能 VAD 最短語音長度（秒）
    private var smartVADMinimumDuration: TimeInterval = 0.05
    
    /// 是否正在語音片段中（由 VAD 檢測）
    private var isInSpeechSegment = false
    
    /// 即時翻譯模式是否正在等待最後的回應
    private var isWaitingForFinalResponse = false
    
    /// 是否正在等待 API 回應（用於控制提交速率）
    private var isWaitingForResponse = false

    // MARK: - 初始化

    init() {
        setupWebSocketCallbacks()
        setupAudioRecorderCallbacks()
        loadHistory()
        setupVoiceActivityDetector()
    }
    
    // MARK: - VAD 設定
    
    /// 設定語音活動檢測器
    private func setupVoiceActivityDetector() {
        // 根據輸入語言創建對應的 VAD
        let locale = getLocaleForLanguage(inputLanguage)
        voiceActivityDetector = VoiceActivityDetector(locale: locale)
        
        // 設定參數
        voiceActivityDetector?.silenceThreshold = smartVADSilenceThreshold
        voiceActivityDetector?.minimumSpeechDuration = smartVADMinimumDuration
        
        // 設定回調
        voiceActivityDetector?.onSpeechStarted = { [weak self] in
            self?.handleSpeechStarted()
        }
        
        voiceActivityDetector?.onSpeechEnded = { [weak self] in
            self?.handleSpeechEnded()
        }
    }
    
    /// 根據語言選項獲取 Locale
    private func getLocaleForLanguage(_ language: LanguageOption) -> Locale {
        switch language.code {
        case "auto":
            return Locale.current // 使用系統語言
        case "zh-TW":
            return Locale(identifier: "zh-TW")
        case "zh":
            return Locale(identifier: "zh-CN")
        case "en":
            return Locale(identifier: "en-US")
        case "ja":
            return Locale(identifier: "ja-JP")
        case "ko":
            return Locale(identifier: "ko-KR")
        case "es":
            return Locale(identifier: "es-ES")
        case "fr":
            return Locale(identifier: "fr-FR")
        case "de":
            return Locale(identifier: "de-DE")
        case "pt":
            return Locale(identifier: "pt-PT")
        case "ru":
            return Locale(identifier: "ru-RU")
        case "it":
            return Locale(identifier: "it-IT")
        case "ar":
            return Locale(identifier: "ar-SA")
        case "hi":
            return Locale(identifier: "hi-IN")
        case "th":
            return Locale(identifier: "th-TH")
        case "vi":
            return Locale(identifier: "vi-VN")
        default:
            return Locale.current
        }
    }
    
    /// 處理開始說話事件
    private func handleSpeechStarted() {
        print("🗣️ 檢測到開始說話，開始累積音訊")
        isInSpeechSegment = true
        audioBufferSize = 0
        lastAudioActivityTime = Date()
    }
    
    /// 處理停止說話事件
    private func handleSpeechEnded() {
        print("🤐 檢測到停止說話")
        
        guard isInSpeechSegment else { return }
        isInSpeechSegment = false
        
        // 檢查是否有足夠的音訊數據（避免提交空音訊導致幻覺回應）
        let minAudioBufferSize = 10 // 最少需要 10 個音訊片段（約 0.3 秒）
        if audioBufferSize < minAudioBufferSize {
            print("⚠️ 音訊數據不足 (\(audioBufferSize) < \(minAudioBufferSize))，跳過提交")
            audioBufferSize = 0
            return
        }
        
        print("✅ 音訊數據充足 (\(audioBufferSize) 片段)，提交音訊片段")
        
        // 只有在即時翻譯模式下才提交
        if isLiveTranslating && !isWaitingForResponse {
            commitAudioBuffer()
            audioBufferSize = 0
        }
    }
    
    // MARK: - 歷史記錄管理
    
    /// 載入歷史記錄
    private func loadHistory() {
        let loadedHistory = HistoryManager.shared.loadHistory()
        DispatchQueue.main.async {
            self.transcriptionHistory = loadedHistory
        }
    }

    // MARK: - 公開方法

    /// 連線到 Realtime API
    /// - Parameter apiKey: OpenAI API Key
    func connect(apiKey: String) {
        self.apiKey = apiKey

        // 建立 WebSocket URL
        guard var urlComponents = URLComponents(string: baseURL) else {
            connectionState = .error("無效的 URL")
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "model", value: selectedModel.rawValue)
        ]

        guard let url = urlComponents.url else {
            connectionState = .error("無法建立連線 URL")
            return
        }

        // 設定標頭
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "OpenAI-Beta": "realtime=v1"
        ]

        // 連線
        webSocketManager.connect(url: url, headers: headers)
    }

    /// 中斷連線
    func disconnect() {
        stopRecording()
        webSocketManager.disconnect()
        connectionState = .disconnected
    }

    /// 更新目標翻譯語言
    /// - Parameter language: 目標語言
    func updateTargetLanguage(_ language: LanguageOption) {
        targetLanguage = language

        // 如果已連線，更新 session 設定
        if connectionState == .connected {
            sendSessionUpdate()
        }
    }
    
    /// 更新輸入音訊語言
    /// - Parameter language: 輸入語言
    func updateInputLanguage(_ language: LanguageOption) {
        inputLanguage = language
        
        // 如果已連線，更新 session 設定
        if connectionState == .connected {
            sendSessionUpdate()
        }
    }

    /// 開始錄音
    func startRecording() {
        guard connectionState == .connected else {
            print("⚠️ 未連線，無法開始錄音")
            return
        }

        // 請求麥克風權限
        audioRecorder.requestMicrophonePermission { [weak self] granted in
            guard granted else {
                print("❌ 麥克風權限被拒絕")
                return
            }

            do {
                try self?.audioRecorder.startRecording()
            } catch {
                print("❌ 開始錄音失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 停止錄音並提交音訊
    func stopRecording() {
        audioRecorder.stopRecording()

        // 提交音訊 buffer
        commitAudioBuffer()
    }

    /// 清除歷史記錄
    func clearHistory() {
        transcriptionHistory.removeAll()
        currentTranscription = ""
        currentTranslation = ""
        HistoryManager.shared.clearHistory()
    }

    /// 開始即時翻譯模式
    func startLiveTranslation() {
        guard connectionState == .connected else {
            print("⚠️ 未連線，無法開始即時翻譯")
            return
        }

        // 如果啟用智能 VAD，先請求語音識別權限
        if isSmartVADEnabled {
            voiceActivityDetector?.requestAuthorization { [weak self] (granted: Bool) in
                guard granted else {
                    print("❌ 語音識別權限被拒絕，回退到舊版 VAD")
                    self?.isSmartVADEnabled = false
                    self?.startLiveTranslation()
                    return
                }
                
                self?.startLiveTranslationWithVAD()
            }
        } else {
            startLiveTranslationWithVAD()
        }
    }
    
    /// 啟動即時翻譯（帶 VAD）
    private func startLiveTranslationWithVAD() {
        // 請求麥克風權限
        audioRecorder.requestMicrophonePermission { [weak self] (granted: Bool) in
            guard granted else {
                print("❌ 麥克風權限被拒絕")
                return
            }

            do {
                try self?.audioRecorder.startRecording()
                DispatchQueue.main.async {
                    self?.isLiveTranslating = true
                    self?.isNewTranslationResponse = true
                    self?.isWaitingForResponse = false
                    self?.currentTranscription = ""
                    self?.audioBufferSize = 0
                    self?.lastAudioActivityTime = Date()
                    self?.isInSpeechSegment = false
                }
                
                // 如果啟用智能 VAD，啟動檢測
                if self?.isSmartVADEnabled == true {
                    do {
                        try self?.voiceActivityDetector?.startDetecting()
                        print("✅ 智能 VAD 已啟動")
                    } catch {
                        print("❌ 智能 VAD 啟動失敗: \(error.localizedDescription)")
                        print("⚠️ 回退到舊版 VAD")
                        self?.isSmartVADEnabled = false
                    }
                }
                
                // 啟動檢查機制（用於舊版 VAD 或作為備用）
                self?.startSmartAudioSubmission()
            } catch {
                print("❌ 開始即時翻譯錄音失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 停止即時翻譯模式
    func stopLiveTranslation() {
        // 停止智能 VAD
        if isSmartVADEnabled {
            voiceActivityDetector?.stopDetecting()
        }
        
        // 停止錄音和定時器
        audioRecorder.stopRecording()
        stopSmartAudioSubmission()
        
        // 如果還在語音片段中，提交最後的音訊
        if isInSpeechSegment {
            commitAudioBuffer()
        }
        
        // 標記為等待最後的回應
        isWaitingForFinalResponse = true
        
        // 設定安全網：最多等待 10 秒，如果還沒收到回應就強制保存
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, self.isWaitingForFinalResponse else { return }
            print("⏰ 安全網觸發：強制保存（10秒超時）")
            self.saveCurrentTranslationToHistory()
        }
        
        // 立即更新部分 UI 狀態（但保持 isLiveTranslating = true，直到保存完成）
        DispatchQueue.main.async {
            self.isVoiceActive = false
            self.audioBufferSize = 0
            self.isInSpeechSegment = false
        }
    }
    
    /// 保存當前翻譯到歷史記錄
    private func saveCurrentTranslationToHistory() {
        guard isWaitingForFinalResponse else { return }
        
        isWaitingForFinalResponse = false
        
        print("💾 準備保存即時翻譯內容")
        print("📝 當前轉錄內容: '\(currentTranscription)'")
        print("📝 當前翻譯內容: '\(currentTranslation)'")
        
        let shouldSaveHistory = !currentTranscription.isEmpty || !currentTranslation.isEmpty
        
        if shouldSaveHistory {
            let transcription = currentTranscription.isEmpty ? "（無轉錄內容）" : currentTranscription
            let translation = currentTranslation.isEmpty ? "（無翻譯內容）" : currentTranslation
            
            let item = TranscriptionItem(
                originalText: transcription,
                translatedText: translation,
                targetLanguage: targetLanguage.code
            )
            
            DispatchQueue.main.async {
                self.transcriptionHistory.append(item)
                print("✅ 即時翻譯內容已保存到歷史記錄")
                print("📝 記錄數量: \(self.transcriptionHistory.count)")
                print("📝 原文: \(transcription)")
                print("📝 翻譯: \(translation)")
                
                // 保存完成後才設置為非即時翻譯模式
                self.isLiveTranslating = false
                print("✅ 即時翻譯模式已結束")
            }
        } else {
            print("⚠️ 沒有內容需要保存")
            DispatchQueue.main.async {
                self.isLiveTranslating = false
                print("✅ 即時翻譯模式已結束（無內容）")
            }
        }
    }

    /// 清除當前翻譯內容（即時翻譯模式專用）
    func clearCurrentContent() {
        currentTranscription = ""
        currentTranslation = ""
    }
    
    /// 更新音訊提交參數
    /// - Parameters:
    ///   - pauseThreshold: 語音停頓閾值（秒，建議範圍：0.5-3.0）
    ///   - bufferSize: 最大音訊緩衝區大小（建議範圍：50-300）
    ///   - submissionInterval: 強制提交音訊的最長時間間隔（秒，建議範圍：2-10）
    func updateAudioSubmissionSettings(pauseThreshold: TimeInterval, bufferSize: Int, submissionInterval: TimeInterval) {
        voicePauseThreshold = max(0.5, min(3.0, pauseThreshold)) // 限制在 0.5-3.0 秒之間
        maxAudioBufferSize = max(50, min(300, bufferSize)) // 限制在 50-300 之間
        maxAudioSubmissionInterval = max(2.0, min(10.0, submissionInterval)) // 限制在 2-10 秒之間
        print("⚙️ 更新音訊提交設定: 停頓閾值=\(voicePauseThreshold)秒, 緩衝區大小=\(maxAudioBufferSize), 提交間隔=\(maxAudioSubmissionInterval)秒")
    }
    
    /// 獲取當前音訊提交設定
    /// - Returns: (停頓閾值, 緩衝區大小, 提交間隔)
    func getAudioSubmissionSettings() -> (pauseThreshold: TimeInterval, bufferSize: Int, submissionInterval: TimeInterval) {
        return (voicePauseThreshold, maxAudioBufferSize, maxAudioSubmissionInterval)
    }
    
    /// 啟用或停用 VAD（語音活動檢測）
    /// - Parameter enabled: 是否啟用 VAD
    func setVADEnabled(_ enabled: Bool) {
        isVADEnabled = enabled
        print("⚙️ VAD \(enabled ? "已啟用" : "已停用")")
    }
    
    /// 設定 VAD 靈敏度
    /// - Parameter threshold: 靈敏度閾值（0.0-1.0，越低越靈敏，建議範圍：0.005-0.05）
    func setVADThreshold(_ threshold: Float) {
        vadThreshold = max(0.001, min(0.1, threshold)) // 限制在 0.001-0.1 之間
        print("⚙️ VAD 靈敏度已設定為: \(vadThreshold)")
    }
    
    /// 獲取 VAD 設定
    /// - Returns: (是否啟用, 靈敏度閾值)
    func getVADSettings() -> (enabled: Bool, threshold: Float) {
        return (isVADEnabled, vadThreshold)
    }
    
    /// 獲取當前輸入語言
    /// - Returns: 當前輸入語言
    func getInputLanguage() -> LanguageOption {
        return inputLanguage
    }
    
    /// 啟用或停用智能 VAD（Speech Framework）
    /// - Parameter enabled: 是否啟用
    func setSmartVADEnabled(_ enabled: Bool) {
        isSmartVADEnabled = enabled
        print("⚙️ 智能 VAD \(enabled ? "已啟用" : "已停用")")
    }
    
    /// 設定智能 VAD 靜默閾值
    /// - Parameter threshold: 靜默時間（秒），建議範圍 0.5-2.0
    func setSmartVADSilenceThreshold(_ threshold: TimeInterval) {
        smartVADSilenceThreshold = max(0.5, min(3.0, threshold))
        voiceActivityDetector?.silenceThreshold = smartVADSilenceThreshold
        print("⚙️ 智能 VAD 靜默閾值已設定為: \(smartVADSilenceThreshold)秒")
    }
    
    /// 設定智能 VAD 最短語音長度
    /// - Parameter duration: 最短長度（秒），建議範圍 0.05-1.0
    func setSmartVADMinimumDuration(_ duration: TimeInterval) {
        smartVADMinimumDuration = max(0.05, min(2.0, duration))
        voiceActivityDetector?.minimumSpeechDuration = smartVADMinimumDuration
        print("⚙️ 智能 VAD 最短語音長度已設定為: \(smartVADMinimumDuration)秒")
    }
    
    /// 獲取智能 VAD 設定
    /// - Returns: (是否啟用, 靜默閾值, 最短語音長度)
    func getSmartVADSettings() -> (enabled: Bool, silenceThreshold: TimeInterval, minimumDuration: TimeInterval) {
        return (isSmartVADEnabled, smartVADSilenceThreshold, smartVADMinimumDuration)
    }
    
    /// 設定 Realtime API 模型
    /// - Parameter model: 模型選項
    func setRealtimeModel(_ model: RealtimeModel) {
        selectedModel = model
        print("⚙️ Realtime API 模型已設定為: \(model.rawValue)")
    }
    
    /// 獲取當前使用的模型
    /// - Returns: 當前模型
    func getRealtimeModel() -> RealtimeModel {
        return selectedModel
    }

    /// 匯出歷史記錄為文字
    /// - Returns: 文字內容
    func exportHistoryAsText() -> String {
        var text = "RealtimeTranslator 翻譯記錄\n"
        text += "匯出時間: \(Date())\n"
        text += "目標語言: \(targetLanguage.name)\n"
        text += "記錄總數: \(transcriptionHistory.count)\n"
        text += String(repeating: "=", count: 50) + "\n\n"

        if transcriptionHistory.isEmpty {
            text += "（暫無翻譯記錄）\n"
            return text
        }

        for (index, item) in transcriptionHistory.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let timeString = timeFormatter.string(from: item.timestamp)

            text += "記錄 #\(index + 1) [\(timeString)]\n"
            text += "原文: \(item.originalText)\n"
            text += "翻譯: \(item.translatedText)\n\n"
        }

        return text
    }

    // MARK: - 私有方法 - WebSocket

    /// 設定 WebSocket 回調
    private func setupWebSocketCallbacks() {
        webSocketManager.onConnectionStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.connectionState = state

                // 連線成功後，發送 session 設定
                if case .connected = state {
                    self?.sendSessionUpdate()
                }
            }
        }

        webSocketManager.onMessageReceived = { [weak self] data in
            self?.handleWebSocketMessage(data)
        }
    }

    /// 處理 WebSocket 訊息
    private func handleWebSocketMessage(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            return
        }

        print("📩 收到事件: \(eventType)")

        switch eventType {
        case "session.created":
            handleSessionCreated(json)

        case "session.updated":
            handleSessionUpdated(json)

        case "conversation.item.created":
            handleConversationItemCreated(json)

        case "response.text.delta":
            handleTextDelta(json)

        case "response.text.done":
            handleTextDone(json)

        case "response.done":
            handleResponseDone(json)

        case "error":
            handleError(json)

        default:
            break
        }
    }

    /// 處理 session.created 事件
    private func handleSessionCreated(_ json: [String: Any]) {
        if let session = json["session"] as? [String: Any],
           let sessionId = session["id"] as? String {
            currentSessionId = sessionId
            print("✅ Session 建立成功: \(sessionId)")
        }
    }

    /// 處理 session.updated 事件
    private func handleSessionUpdated(_ json: [String: Any]) {
        print("✅ Session 更新成功")
    }

    /// 處理 conversation.item.created 事件
    private func handleConversationItemCreated(_ json: [String: Any]) {
        print("📝 建立對話項目")
    }

    /// 臨時累積的回應文字（用於處理串流式回應）
    private var accumulatedResponseText = ""

    /// 處理翻譯文字片段（GPT-4o 的串流式回應）
    private func handleTextDelta(_ json: [String: Any]) {
        guard let delta = json["delta"] as? String else { return }
        
        // 累積文字片段
        accumulatedResponseText += delta
    }

    /// 處理翻譯完成（解析完整的 JSON 回應）
    private func handleTextDone(_ json: [String: Any]) {
        guard let text = json["text"] as? String else { return }
        
        print("📥 收到完整回應: \(text)")
        
        // 解析 JSON 格式的回應
        parseTranslationResponse(text)
        
        // 清空累積的文字
        accumulatedResponseText = ""
    }
    
    /// 解析翻譯回應（JSON 格式）
    private func parseTranslationResponse(_ responseText: String) {
        // 嘗試提取 JSON（移除可能的 markdown 標記）
        var jsonString = responseText
        
        // 移除 ```json 和 ``` 標記
        jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
        jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 嘗試解析 JSON
        guard let jsonData = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
              let transcription = parsed["transcription"],
              let translation = parsed["translation"] else {
            print("⚠️ 無法解析 JSON 回應，使用原始文字")
            // 如果解析失敗，將整個回應視為翻譯結果
            handleFallbackResponse(responseText)
            return
        }
        
        print("✅ 成功解析 JSON")
        print("📝 轉錄: \(transcription)")
        print("🌐 翻譯: \(translation)")
        
        DispatchQueue.main.async {
            if self.isLiveTranslating {
                // 即時翻譯模式：累積內容
                if !transcription.isEmpty {
                    if !self.currentTranscription.isEmpty {
                        self.currentTranscription += " " + transcription
                    } else {
                        self.currentTranscription = transcription
                    }
                }
                
                if !translation.isEmpty {
                    // 如果是新的翻譯回應，且已有內容，則添加斷行
                    if self.isNewTranslationResponse && !self.currentTranslation.isEmpty {
                        self.currentTranslation += "\n"
                    }
                    self.currentTranslation += translation
                    self.isNewTranslationResponse = false
                }
                
                print("📝 當前累積轉錄: \(self.currentTranscription)")
                print("📝 當前累積翻譯: \(self.currentTranslation)")
            } else {
                // 錄音翻譯模式：替換內容
                self.currentTranscription = transcription
                self.currentTranslation = translation
                self.isTranscriptionComplete = true
                
                print("✅ 錄音翻譯完成")
                
                // 加入歷史記錄
                if !self.currentTranscription.isEmpty || !self.currentTranslation.isEmpty {
                    let item = TranscriptionItem(
                        originalText: self.currentTranscription.isEmpty ? "（無轉錄內容）" : self.currentTranscription,
                        translatedText: self.currentTranslation.isEmpty ? "（無翻譯內容）" : self.currentTranslation,
                        targetLanguage: self.targetLanguage.code
                    )
                    self.transcriptionHistory.append(item)
                }
            }
        }
    }
    
    /// 處理無法解析 JSON 的回應（回退方案）
    private func handleFallbackResponse(_ text: String) {
        DispatchQueue.main.async {
            if self.isLiveTranslating {
                // 即時翻譯模式：將回應視為翻譯結果
                if self.isNewTranslationResponse && !self.currentTranslation.isEmpty {
                    self.currentTranslation += "\n"
                }
                self.currentTranslation += text
                self.isNewTranslationResponse = false
            } else {
                // 錄音翻譯模式：將回應視為翻譯結果
                self.currentTranslation = text
                
                // 加入歷史記錄
                let item = TranscriptionItem(
                    originalText: self.currentTranscription.isEmpty ? "（無法識別原文）" : self.currentTranscription,
                    translatedText: text,
                    targetLanguage: self.targetLanguage.code
                )
                self.transcriptionHistory.append(item)
            }
        }
    }

    /// 處理回應完成
    private func handleResponseDone(_ json: [String: Any]) {
        if let response = json["response"] as? [String: Any],
           let usage = response["usage"] as? [String: Any] {
            updateTokenUsage(usage)
        }
        print("✅ 回應完成")
        
        // 清除等待回應標誌，允許下一次提交
        isWaitingForResponse = false
        print("🔓 清除等待回應標誌 (isWaitingForResponse = false)")
        
        // 如果是即時翻譯模式且正在等待最後的回應，現在保存
        if isWaitingForFinalResponse {
            print("📥 收到最後的回應，立即保存")
            saveCurrentTranslationToHistory()
        }
    }

    /// 處理錯誤
    private func handleError(_ json: [String: Any]) {
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            DispatchQueue.main.async {
                self.connectionState = .error(message)
            }
            print("❌ API 錯誤: \(message)")
        }
    }

    /// 更新 token 使用統計
    private func updateTokenUsage(_ usage: [String: Any]) {
        DispatchQueue.main.async {
            if let totalTokens = usage["total_tokens"] as? Int {
                self.tokenUsage.totalTokens += totalTokens
            }
            if let inputTokens = usage["input_tokens"] as? Int {
                self.tokenUsage.inputTokens += inputTokens
            }
            if let outputTokens = usage["output_tokens"] as? Int {
                self.tokenUsage.outputTokens += outputTokens
            }
        }
    }

    /// 發送 session 更新
    private func sendSessionUpdate() {
        let instructions = generateInstructions()
        
        // 使用 Decimal 確保精確的數值，避免浮點精度問題
        let temperature = Decimal(string: "0.8")!

        let sessionUpdate: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],  // 啟用音訊輸入
                "instructions": instructions,
                "voice": "alloy",  // 設定語音（雖然我們只用文字輸出）
                "input_audio_format": "pcm16",  // 音訊格式
                "output_audio_format": "pcm16",
                "turn_detection": NSNull(),  // 停用自動回合檢測，我們手動控制
                "temperature": temperature,
                "max_response_output_tokens": 4096
            ]
        ]

        sendEvent(sessionUpdate)
    }

    /// 生成翻譯指令
    private func generateInstructions() -> String {
        let targetLanguageName = targetLanguage.name
        let targetLanguageCode = targetLanguage.code
        let inputLanguageName = inputLanguage.name
        let inputLanguageCode = inputLanguage.code
        
        // 根據輸入語言設定，生成對應的提示
        let inputLanguagePrompt: String
        if inputLanguageCode == "auto" {
            inputLanguagePrompt = "你會收到使用者的語音輸入（可能是任何語言）"
        } else {
            inputLanguagePrompt = "你會收到使用者的**\(inputLanguageName)**語音輸入（語言代碼: \(inputLanguageCode)）"
        }

        return """
        你是一個專業的即時翻譯助手。\(inputLanguagePrompt)，請執行以下任務：

        1. 將語音轉錄成文字（原文）
        2. 將原文翻譯成 \(targetLanguageName)（語言代碼: \(targetLanguageCode)）

        **重要：請以 JSON 格式回覆，格式如下：**
        ```json
        {
          "transcription": "使用者說的原文內容",
          "translation": "翻譯後的\(targetLanguageName)內容"
        }
        ```

        注意事項：
        - 只輸出 JSON 格式，不要加上任何其他文字或解釋
        - 確保 JSON 格式正確，可以被解析
        - 保持轉錄和翻譯的準確性和流暢性
        - 如果語音不清晰或無法理解，transcription 和 translation 都設為空字串
        \(inputLanguageCode != "auto" ? "- 輸入音訊應為 \(inputLanguageName)，這有助於提高辨識準確度" : "- 請自動識別輸入音訊的語言")
        """
    }

    /// 發送事件到 WebSocket
    private func sendEvent(_ event: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: event) else {
            print("❌ 無法序列化事件")
            return
        }

        webSocketManager.send(message: data)
    }

    /// 開始智能音訊提交機制
    private func startSmartAudioSubmission() {
        // 使用較短的檢查間隔來監控語音活動
        liveTranslationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkAudioSubmissionConditions()
        }
    }

    /// 停止智能音訊提交機制
    private func stopSmartAudioSubmission() {
        liveTranslationTimer?.invalidate()
        liveTranslationTimer = nil
        voicePauseTimer?.invalidate()
        voicePauseTimer = nil
    }
    
    /// 檢查音訊提交條件
    private func checkAudioSubmissionConditions() {
        // 如果正在等待回應，不提交新的音訊
        guard !isWaitingForResponse else {
            return
        }
        
        // 如果啟用智能 VAD，則主要依賴 Speech Framework 的檢測
        // 這裡只保留緩衝區過大的檢查作為安全網
        if isSmartVADEnabled {
            // 只有在語音片段中才檢查緩衝區大小
            if isInSpeechSegment && audioBufferSize > maxAudioBufferSize {
                print("📦 語音片段過長，提前提交 (buffer size: \(audioBufferSize))")
                commitAudioBuffer()
                audioBufferSize = 0
                lastAudioActivityTime = Date()
            }
            return
        }
        
        // 舊版 VAD 邏輯（回退方案）
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastAudioActivityTime)
        
        // 條件1：檢測到語音停頓超過閾值
        if isVoiceActive && timeSinceLastActivity > voicePauseThreshold {
            print("🔍 [舊版VAD] 檢測到語音停頓，提交音訊片段")
            commitAudioBufferIfNeeded()
            isVoiceActive = false
        }
        
        // 條件2：音訊緩衝區過大（避免過長片段）
        else if audioBufferSize > maxAudioBufferSize {
            print("📦 [舊版VAD] 音訊緩衝區已滿，強制提交")
            commitAudioBufferIfNeeded()
        }
        
        // 條件3：安全網 - 最長不超過設定的時間提交一次
        // 注意：智能 VAD 模式下這個安全網已被移除，節省成本
        else if timeSinceLastActivity > maxAudioSubmissionInterval {
            print("⏰ [舊版VAD] 安全網觸發")
            commitAudioBufferIfNeeded()
        }
    }
    
    /// 有條件地提交音訊緩衝區
    private func commitAudioBufferIfNeeded() {
        // 即時翻譯模式下，即使 audioBufferSize 為 0，也應該提交
        // 因為音訊數據一直在發送到 API，只是 VAD 可能沒有檢測到語音活動
        // （例如：背景噪音、麥克風靈敏度、說話音量小等因素）
        
        commitAudioBuffer()
        audioBufferSize = 0
        lastAudioActivityTime = Date()
        
        // 重置語音停頓檢測
        voicePauseTimer?.invalidate()
        voicePauseTimer = nil
    }

    /// 提交音訊 buffer
    private func commitAudioBuffer() {
        // 標記為新的翻譯回應
        isNewTranslationResponse = true
        
        // 標記為正在等待回應
        isWaitingForResponse = true
        print("🔒 設置等待回應標誌 (isWaitingForResponse = true)")
        
        // 1. 提交音訊
        let commitEvent: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]
        sendEvent(commitEvent)
        print("📤 已發送 input_audio_buffer.commit")

        // 2. 請求產生回應
        let responseEvent: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text"]
            ]
        ]
        sendEvent(responseEvent)
        print("📤 已發送 response.create")
        
        // 3. ⭐️ 清空音訊緩衝區（避免重複處理舊音訊）
        let clearEvent: [String: Any] = [
            "type": "input_audio_buffer.clear"
        ]
        sendEvent(clearEvent)
        print("🗑️ 已發送 input_audio_buffer.clear（清空緩衝區）")
    }

    // MARK: - 私有方法 - Audio

    /// 設定音訊錄製回調
    private func setupAudioRecorderCallbacks() {
        audioRecorder.onAudioDataAvailable = { [weak self] data, volume in
            self?.sendAudioData(data, volume: volume)
        }

        audioRecorder.onRecordingStateChanged = { [weak self] isRecording in
            DispatchQueue.main.async {
                self?.isRecording = isRecording

                // 只在錄音翻譯模式下重置當前文字（即時翻譯模式下不重置）
                if isRecording && !(self?.isLiveTranslating ?? false) {
                    self?.currentTranscription = ""
                    self?.currentTranslation = ""
                    self?.isTranscriptionComplete = false
                }
            }
        }

        audioRecorder.onError = { error in
            print("❌ 音訊錄製錯誤: \(error.localizedDescription)")
        }
    }

    /// 發送音訊資料
    private func sendAudioData(_ data: Data, volume: Float) {
        // 如果正在語音片段中（由智能 VAD 或舊版 VAD 檢測），累積音訊數據
        if isInSpeechSegment {
            audioBufferSize += 1
        }
        
        // VAD 語音活動檢測（舊版 VAD 用於備用）
        let hasVoiceActivity: Bool
        
        if isVADEnabled && !isSmartVADEnabled {
            // 使用 iOS AVFoundation 提供的音量檢測
            hasVoiceActivity = volume > vadThreshold
            
            if hasVoiceActivity {
                isVoiceActive = true
                lastAudioActivityTime = Date()
            }
            
            // 可選：記錄 VAD 狀態（用於調試）
            #if DEBUG
            if hasVoiceActivity && !isVoiceActive {
                print("🎤 檢測到語音活動 (音量: \(String(format: "%.4f", volume)))")
            }
            #endif
        } else if !isSmartVADEnabled {
            // VAD 停用時，根據數據大小判斷（舊邏輯）
            hasVoiceActivity = data.count > 100
            
            if hasVoiceActivity {
                isVoiceActive = true
                lastAudioActivityTime = Date()
            }
        }

        // 始終發送音訊數據到 API（讓伺服器端處理）
        let base64Audio = AudioProcessor.convertToBase64PCM16(audioData: data)

        let audioEvent: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]

        sendEvent(audioEvent)
    }
}
