//
//  AudioRecorder.swift
//  RealtimeTranslator
//
//  音訊錄製服務
//

import Foundation
import AVFoundation

/// 音訊錄製類別
class AudioRecorder: NSObject {
    // MARK: - 屬性

    /// 音訊引擎
    private var audioEngine: AVAudioEngine?

    /// 輸入節點
    private var inputNode: AVAudioInputNode?

    /// 是否正在錄音
    private(set) var isRecording = false

    /// 目標採樣率（24kHz）
    private let targetSampleRate: Double = 24000.0

    /// 目標聲道數（單聲道）
    private let targetChannels: AVAudioChannelCount = 1

    // MARK: - 回調

    /// 音訊資料可用時的回調（包含音訊數據和音量資訊）
    var onAudioDataAvailable: ((Data, Float) -> Void)?

    /// 錄音狀態變更回調
    var onRecordingStateChanged: ((Bool) -> Void)?

    /// 錯誤回調
    var onError: ((Error) -> Void)?

    // MARK: - 初始化

    override init() {
        super.init()
    }

    // MARK: - 公開方法

    /// 請求麥克風權限
    /// - Parameter completion: 權限請求完成回調
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
        #else
        // 非 iOS 平台預設允許
        DispatchQueue.main.async {
            completion(true)
        }
        #endif
    }

    /// 開始錄音
    /// - Throws: 錄音相關錯誤
    func startRecording() throws {
        guard !isRecording else {
            print("⚠️ 已經在錄音中")
            return
        }

        // 設定音訊 Session
        try setupAudioSession()

        // 建立音訊引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法建立音訊引擎"])
        }

        inputNode = audioEngine.inputNode

        // 取得輸入格式
        let inputFormat = inputNode?.inputFormat(forBus: 0)
        guard let inputFormat = inputFormat else {
            throw NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法取得音訊格式"])
        }

        print("📊 原始音訊格式:")
        print("   採樣率: \(inputFormat.sampleRate) Hz")
        print("   聲道數: \(inputFormat.channelCount)")
        print("   位元深度: \(inputFormat.streamDescription.pointee.mBitsPerChannel)")

        // 建立目標格式（PCM16, 24kHz, Mono）
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw NSError(domain: "AudioRecorder", code: -3, userInfo: [NSLocalizedDescriptionKey: "無法建立目標音訊格式"])
        }

        // 建立格式轉換器
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "AudioRecorder", code: -4, userInfo: [NSLocalizedDescriptionKey: "無法建立音訊轉換器"])
        }

        // 安裝音訊 tap
        // 使用較小的 buffer size 以降低延遲（1024 samples ≈ 21ms @ 48kHz）
        let bufferSize: AVAudioFrameCount = 1024

        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }

            // 計算音量（使用原始 buffer）
            let volume = AudioProcessor.calculateVolume(buffer)

            // 轉換音訊格式
            if let convertedData = self.convertAudioBuffer(buffer, using: converter, targetFormat: targetFormat) {
                self.onAudioDataAvailable?(convertedData, volume)
            }
        }

        // 啟動音訊引擎
        try audioEngine.start()

        isRecording = true
        onRecordingStateChanged?(true)
        print("✅ 開始錄音")
    }

    /// 停止錄音
    func stopRecording() {
        guard isRecording else {
            print("⚠️ 目前未在錄音")
            return
        }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        isRecording = false
        onRecordingStateChanged?(false)
        print("⏹️ 停止錄音")
    }

    // MARK: - 私有方法

    /// 設定音訊 Session
    private func setupAudioSession() throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)

        print("✅ 音訊 Session 設定完成")
        #endif
    }

    /// 轉換音訊 buffer 格式
    private func convertAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) -> Data? {
        // 計算轉換後的 frame 數量
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        // 建立輸出 buffer
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity
        ) else {
            return nil
        }

        var error: NSError?

        // 執行轉換
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ 音訊轉換錯誤: \(error.localizedDescription)")
            return nil
        }

        // 轉換為 Data
        guard let channelData = convertedBuffer.int16ChannelData else {
            return nil
        }

        let channelDataPointer = channelData[0]
        let channelDataArray = Array(UnsafeBufferPointer(
            start: channelDataPointer,
            count: Int(convertedBuffer.frameLength)
        ))

        return Data(bytes: channelDataArray, count: channelDataArray.count * MemoryLayout<Int16>.size)
    }

    // MARK: - 清理

    deinit {
        stopRecording()
    }
}
