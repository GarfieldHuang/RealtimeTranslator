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
    @Published var transcriptionHistory: [TranscriptionItem] = []

    /// Token 使用統計
    @Published var tokenUsage: TokenUsage = TokenUsage()

    /// 是否正在錄音
    @Published var isRecording: Bool = false

    /// 是否正在進行即時翻譯
    @Published var isLiveTranslating: Bool = false

    // MARK: - 私有屬性

    /// WebSocket 管理器
    private let webSocketManager = WebSocketManager()

    /// 音訊錄製器
    private let audioRecorder = AudioRecorder()

    /// 目標翻譯語言
    private var targetLanguage: LanguageOption = .defaultLanguage

    /// API Key
    private var apiKey: String?

    /// WebSocket URL
    private let baseURL = "wss://api.openai.com/v1/realtime"

    /// 模型名稱
    private let model = "gpt-4o-realtime-preview-2024-12-17"

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

    // MARK: - 初始化

    init() {
        setupWebSocketCallbacks()
        setupAudioRecorderCallbacks()
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
            URLQueryItem(name: "model", value: model)
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
    }

    /// 開始即時翻譯模式
    func startLiveTranslation() {
        guard connectionState == .connected else {
            print("⚠️ 未連線，無法開始即時翻譯")
            return
        }

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
                    self?.isNewTranslationResponse = true // 重置新翻譯標誌
                    // 不清除 currentTranslation，保留之前的內容
                    self?.currentTranscription = ""
                    self?.audioBufferSize = 0
                    self?.lastAudioActivityTime = Date()
                }
                
                // 開始智能音訊提交機制
                self?.startSmartAudioSubmission()
            } catch {
                print("❌ 開始即時翻譯錄音失敗: \(error.localizedDescription)")
            }
        }
    }

    /// 停止即時翻譯模式
    func stopLiveTranslation() {
        // 停止錄音和定時器
        audioRecorder.stopRecording()
        stopSmartAudioSubmission()
        
        // 最後提交一次音訊（如果有剩餘的緩衝）
        commitAudioBuffer()
        
        // 延遲保存記錄，等待最後的 API 回應
        // 因為轉錄和翻譯事件可能在停止按鈕按下後才到達
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⏰ 延遲保存觸發")
            print("📝 當前轉錄內容: '\(self.currentTranscription)'")
            print("📝 當前翻譯內容: '\(self.currentTranslation)'")
            
            let shouldSaveHistory = !self.currentTranscription.isEmpty || !self.currentTranslation.isEmpty
            
            if shouldSaveHistory {
                let transcription = self.currentTranscription.isEmpty ? "（無轉錄內容）" : self.currentTranscription
                let translation = self.currentTranslation.isEmpty ? "（無翻譯內容）" : self.currentTranslation
                
                let item = TranscriptionItem(
                    originalText: transcription,
                    translatedText: translation,
                    targetLanguage: self.targetLanguage.code
                )
                
                self.transcriptionHistory.append(item)
                print("💾 即時翻譯內容已保存到歷史記錄")
                print("📝 記錄數量: \(self.transcriptionHistory.count)")
                print("📝 原文: \(transcription)")
                print("📝 翻譯: \(translation)")
            } else {
                print("⚠️ 延遲後仍沒有內容需要保存")
            }
        }
        
        // 立即更新 UI 狀態
        DispatchQueue.main.async {
            self.isLiveTranslating = false
            self.isVoiceActive = false
            self.audioBufferSize = 0
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

        case "conversation.item.input_audio_transcription.completed":
            handleTranscriptionCompleted(json)

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

    /// 處理轉錄完成事件
    private func handleTranscriptionCompleted(_ json: [String: Any]) {
        guard let transcript = json["transcript"] as? String else { return }

        DispatchQueue.main.async {
            if self.isLiveTranslating {
                // 即時翻譯模式：累積轉錄文字
                if !self.currentTranscription.isEmpty {
                    self.currentTranscription += " " + transcript
                } else {
                    self.currentTranscription = transcript
                }
                print("✅ 即時轉錄累積: \(transcript)")
                print("📝 當前累積轉錄: \(self.currentTranscription)")
            } else {
                // 錄音翻譯模式：替換轉錄文字
                self.currentTranscription = transcript
                self.isTranscriptionComplete = true
                print("✅ 錄音轉錄完成: \(transcript)")
            }
        }
    }

    /// 處理翻譯文字片段
    private func handleTextDelta(_ json: [String: Any]) {
        guard let delta = json["delta"] as? String else { return }

        DispatchQueue.main.async {
            if self.isLiveTranslating {
                // 如果是新的翻譯回應，且已有內容，則添加斷行
                if self.isNewTranslationResponse && !self.currentTranslation.isEmpty {
                    self.currentTranslation += "\n"
                    self.isNewTranslationResponse = false
                }
                self.currentTranslation += delta
            } else {
                // 錄音翻譯模式：直接累積
                self.currentTranslation += delta
            }
        }
    }

    /// 處理翻譯完成
    private func handleTextDone(_ json: [String: Any]) {
        guard let text = json["text"] as? String else { return }

        DispatchQueue.main.async {
            if self.isLiveTranslating {
                // 即時翻譯模式：textDelta 已經累積了完整翻譯，不需要重複處理
                // 確保內容不被覆蓋，只記錄日誌
                print("✅ 即時翻譯片段完成: \(text)")
                print("📝 當前完整翻譯: \(self.currentTranslation)")
                // 不修改 currentTranslation，保持 textDelta 累積的內容
            } else {
                // 錄音翻譯模式：使用完整翻譯文字並加入歷史記錄
                self.currentTranslation = text
                print("✅ 錄音翻譯完成: \(text)")

                // 加入歷史記錄
                if !self.currentTranscription.isEmpty {
                    let item = TranscriptionItem(
                        originalText: self.currentTranscription,
                        translatedText: self.currentTranslation,
                        targetLanguage: self.targetLanguage.code
                    )
                    self.transcriptionHistory.append(item)
                }
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
                "modalities": ["text"],
                "instructions": instructions,
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": NSNull(),
                "temperature": temperature,
                "max_response_output_tokens": 4096
            ]
        ]

        sendEvent(sessionUpdate)
    }

    /// 生成翻譯指令
    private func generateInstructions() -> String {
        let languageName = targetLanguage.name
        let languageCode = targetLanguage.code

        return """
        你是一個專業的即時翻譯助手。請將使用者的語音內容準確翻譯成 \(languageName)（語言代碼: \(languageCode)）。
        請只輸出翻譯結果，不要加上任何解釋或額外內容。
        保持翻譯的準確性和流暢性。
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
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(lastAudioActivityTime)
        
        // 條件1：檢測到語音停頓超過閾值
        if isVoiceActive && timeSinceLastActivity > voicePauseThreshold {
            print("🔍 檢測到語音停頓，提交音訊片段")
            commitAudioBufferIfNeeded()
            isVoiceActive = false
        }
        
        // 條件2：音訊緩衝區過大（避免過長片段）
        else if audioBufferSize > maxAudioBufferSize {
            print("📦 音訊緩衝區已滿，強制提交")
            commitAudioBufferIfNeeded()
        }
        
        // 條件3：安全網 - 最長不超過設定的時間提交一次
        else if timeSinceLastActivity > maxAudioSubmissionInterval {
            print("⏰ 安全網觸發（\(maxAudioSubmissionInterval)秒），提交音訊片段")
            commitAudioBufferIfNeeded()
        }
    }
    
    /// 有條件地提交音訊緩衝區
    private func commitAudioBufferIfNeeded() {
        guard audioBufferSize > 0 else { return }
        
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
        
        let commitEvent: [String: Any] = [
            "type": "input_audio_buffer.commit"
        ]
        sendEvent(commitEvent)

        // 請求產生回應
        let responseEvent: [String: Any] = [
            "type": "response.create",
            "response": [
                "modalities": ["text"]
            ]
        ]
        sendEvent(responseEvent)
    }

    // MARK: - 私有方法 - Audio

    /// 設定音訊錄製回調
    private func setupAudioRecorderCallbacks() {
        audioRecorder.onAudioDataAvailable = { [weak self] data in
            self?.sendAudioData(data)
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
    private func sendAudioData(_ data: Data) {
        // 簡單的語音活動檢測（基於音訊數據大小）
        if data.count > 100 { // 假設有音訊活動的最小閾值
            isVoiceActive = true
            lastAudioActivityTime = Date()
            audioBufferSize += 1
        }

        let base64Audio = AudioProcessor.convertToBase64PCM16(audioData: data)

        let audioEvent: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]

        sendEvent(audioEvent)
    }
}
