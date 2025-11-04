//
//  VoiceActivityDetector.swift
//  RealtimeTranslator
//
//  語音活動檢測器（使用 Speech Framework）
//

import Foundation
import Speech
import AVFoundation

/// 語音活動檢測器
/// 使用 iOS Speech Framework 進行高精度的人聲檢測
class VoiceActivityDetector {
    
    // MARK: - 回調
    
    /// 檢測到開始說話
    var onSpeechStarted: (() -> Void)?
    
    /// 檢測到停止說話
    var onSpeechEnded: (() -> Void)?
    
    /// 檢測到語音片段（即時識別結果，僅用於調試）
    var onPartialResult: ((String) -> Void)?
    
    // MARK: - 私有屬性
    
    /// 語音識別器
    private let speechRecognizer: SFSpeechRecognizer?
    
    /// 識別請求
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// 識別任務
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// 音訊引擎
    private let audioEngine = AVAudioEngine()
    
    /// 是否正在識別
    private var isRecognizing = false
    
    /// 是否檢測到語音活動
    private var isSpeechActive = false
    
    /// 最後一次檢測到語音的時間
    private var lastSpeechTime: Date?
    
    /// 無語音計時器
    private var silenceTimer: Timer?
    
    // MARK: - 可配置參數
    
    /// 靜默檢測時間（秒）- 超過此時間沒有語音則認為說話結束
    var silenceThreshold: TimeInterval = 1.0
    
        /// 最短語音長度（秒）- 小於此長度的語音片段會被忽略（避免雜音誤觸）
    var minimumSpeechDuration: TimeInterval = 0.05
    
    /// 語音開始的延遲容錯（秒）- 開始說話後容許的前置時間
    var speechStartDelay: TimeInterval = 0.2
    
    /// 語音開始時間
    private var speechStartTime: Date?
    
    // MARK: - 初始化
    
    /// 初始化
    /// - Parameter locale: 語言區域，用於優化識別準確度
    init(locale: Locale = Locale(identifier: "zh-TW")) {
        // 使用指定語言的語音識別器
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // 設定識別器為設備端識別（更快、更省電、保護隱私）
        if #available(iOS 13.0, *) {
            speechRecognizer?.supportsOnDeviceRecognition = true
        }
    }
    
    // MARK: - 公開方法
    
    /// 請求語音識別權限
    /// - Parameter completion: 完成回調，返回是否授權
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("✅ 語音識別權限已授予")
                    completion(true)
                case .denied:
                    print("❌ 語音識別權限被拒絕")
                    completion(false)
                case .restricted:
                    print("⚠️ 語音識別權限受限")
                    completion(false)
                case .notDetermined:
                    print("⚠️ 語音識別權限未確定")
                    completion(false)
                @unknown default:
                    print("⚠️ 未知的語音識別權限狀態")
                    completion(false)
                }
            }
        }
    }
    
    /// 開始檢測
    func startDetecting() throws {
        // 確保有語音識別器
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "VoiceActivityDetector", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "語音識別器不可用"])
        }
        
        // 如果正在識別，先停止
        if isRecognizing {
            stopDetecting()
        }
        
        // 準備音訊會話
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 創建識別請求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceActivityDetector", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "無法創建識別請求"])
        }
        
        // 設定為即時識別
        recognitionRequest.shouldReportPartialResults = true
        
        // 設定為設備端識別（如果支援）
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // 獲取音訊輸入節點
        let inputNode = audioEngine.inputNode
        
        // 開始識別任務
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.handleRecognitionResult(result)
            }
            
            if error != nil || result?.isFinal == true {
                self.handleRecognitionEnd()
            }
        }
        
        // 設定音訊格式和安裝 tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // 準備並啟動音訊引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecognizing = true
        isSpeechActive = false
        speechStartTime = nil
        lastSpeechTime = nil
        
        print("🎙️ VAD 開始檢測人聲")
    }
    
    /// 停止檢測
    func stopDetecting() {
        // 停止音訊引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 結束識別請求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 取消識別任務
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 取消計時器
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // 如果還在說話狀態，觸發結束回調
        if isSpeechActive {
            notifySpeechEnded()
        }
        
        isRecognizing = false
        
        print("🛑 VAD 停止檢測")
    }
    
    /// 更新語言設定
    /// - Parameter locale: 新的語言區域
    func updateLocale(_ locale: Locale) {
        // 需要重新初始化識別器
        let wasRecognizing = isRecognizing
        
        if wasRecognizing {
            stopDetecting()
        }
        
        // 注意：這裡需要重新創建 VoiceActivityDetector 實例
        // 因為 SFSpeechRecognizer 在初始化後無法更改 locale
        print("⚠️ 語言變更需要重新創建 VAD 實例")
    }
    
    // MARK: - 私有方法
    
    /// 處理識別結果
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcription = result.bestTranscription.formattedString
        
        // 如果有識別到文字，表示有語音活動
        if !transcription.isEmpty {
            lastSpeechTime = Date()
            
            // 如果之前沒有檢測到語音，現在檢測到了
            if !isSpeechActive {
                speechStartTime = Date()
                isSpeechActive = true
                
                // 延遲一點點再通知（避免誤觸發）
                DispatchQueue.main.asyncAfter(deadline: .now() + speechStartDelay) { [weak self] in
                    guard let self = self, self.isSpeechActive else { return }
                    self.notifySpeechStarted()
                }
            }
            
            // 重置靜默計時器
            resetSilenceTimer()
            
            // 可選：回傳部分識別結果（用於調試）
            #if DEBUG
            onPartialResult?(transcription)
            #endif
        }
    }
    
    /// 處理識別結束
    private func handleRecognitionEnd() {
        if isSpeechActive {
            notifySpeechEnded()
        }
    }
    
    /// 重置靜默計時器
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isSpeechActive {
                // 檢查語音長度是否符合最短要求
                if let startTime = self.speechStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    if duration >= self.minimumSpeechDuration {
                        self.notifySpeechEnded()
                    } else {
                        print("⏭️ 語音片段太短 (\(String(format: "%.2f", duration))秒)，忽略")
                        self.isSpeechActive = false
                        self.speechStartTime = nil
                    }
                } else {
                    self.notifySpeechEnded()
                }
            }
        }
    }
    
    /// 通知開始說話
    private func notifySpeechStarted() {
        print("🗣️ VAD 檢測到開始說話")
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechStarted?()
        }
    }
    
    /// 通知停止說話
    private func notifySpeechEnded() {
        print("🤐 VAD 檢測到停止說話")
        isSpeechActive = false
        speechStartTime = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechEnded?()
        }
    }
    
    // MARK: - Deinit
    
    deinit {
        stopDetecting()
    }
}
