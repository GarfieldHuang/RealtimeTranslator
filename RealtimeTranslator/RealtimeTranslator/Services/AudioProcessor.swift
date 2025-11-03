//
//  AudioProcessor.swift
//  RealtimeTranslator
//
//  音訊處理工具
//

import Foundation
import AVFoundation

/// 音訊處理工具類別
class AudioProcessor {
    // MARK: - Base64 編碼

    /// 將音訊資料轉換為 Base64 編碼的 PCM16 格式
    /// - Parameter audioData: 原始音訊資料（PCM16）
    /// - Returns: Base64 編碼字串
    static func convertToBase64PCM16(audioData: Data) -> String {
        return audioData.base64EncodedString()
    }

    /// 將 Base64 字串解碼為音訊資料
    /// - Parameter base64String: Base64 編碼字串
    /// - Returns: 音訊資料
    static func decodeBase64ToAudioData(_ base64String: String) -> Data? {
        return Data(base64Encoded: base64String)
    }

    // MARK: - 音訊格式轉換

    /// 重新取樣音訊（調整採樣率）
    /// - Parameters:
    ///   - buffer: 原始音訊 buffer
    ///   - targetSampleRate: 目標採樣率
    /// - Returns: 重新取樣後的 buffer
    static func resampleAudio(
        from buffer: AVAudioPCMBuffer,
        targetSampleRate: Double
    ) -> AVAudioPCMBuffer? {
        let inputFormat = buffer.format
        let outputSampleRate = targetSampleRate

        // 如果採樣率已經相同，直接返回
        if inputFormat.sampleRate == outputSampleRate {
            return buffer
        }

        // 建立目標格式
        guard let outputFormat = AVAudioFormat(
            commonFormat: inputFormat.commonFormat,
            sampleRate: outputSampleRate,
            channels: inputFormat.channelCount,
            interleaved: inputFormat.isInterleaved
        ) else {
            return nil
        }

        // 建立轉換器
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }

        // 計算輸出 frame 數量
        let ratio = outputSampleRate / inputFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        // 建立輸出 buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCount
        ) else {
            return nil
        }

        // 執行轉換
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ 音訊重新取樣錯誤: \(error.localizedDescription)")
            return nil
        }

        outputBuffer.frameLength = outputFrameCount
        return outputBuffer
    }

    // MARK: - 音訊資料處理

    /// 將 AVAudioPCMBuffer 轉換為 Data
    /// - Parameter buffer: 音訊 buffer
    /// - Returns: 音訊資料
    static func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        let format = buffer.format

        if format.commonFormat == .pcmFormatInt16 {
            // Int16 格式
            guard let channelData = buffer.int16ChannelData else { return nil }
            let channelDataPointer = channelData[0]
            let channelDataArray = Array(UnsafeBufferPointer(
                start: channelDataPointer,
                count: Int(buffer.frameLength)
            ))
            return Data(bytes: channelDataArray, count: channelDataArray.count * MemoryLayout<Int16>.size)

        } else if format.commonFormat == .pcmFormatFloat32 {
            // Float32 格式
            guard let channelData = buffer.floatChannelData else { return nil }
            let channelDataPointer = channelData[0]
            let channelDataArray = Array(UnsafeBufferPointer(
                start: channelDataPointer,
                count: Int(buffer.frameLength)
            ))
            return Data(bytes: channelDataArray, count: channelDataArray.count * MemoryLayout<Float>.size)
        }

        return nil
    }

    /// 將 Float32 音訊資料轉換為 Int16
    /// - Parameter floatData: Float32 音訊資料
    /// - Returns: Int16 音訊資料
    static func convertFloat32ToInt16(_ floatData: Data) -> Data {
        let floatArray = floatData.withUnsafeBytes { pointer -> [Float] in
            Array(pointer.bindMemory(to: Float.self))
        }

        let int16Array: [Int16] = floatArray.map { sample in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        return Data(bytes: int16Array, count: int16Array.count * MemoryLayout<Int16>.size)
    }

    /// 將 Int16 音訊資料轉換為 Float32
    /// - Parameter int16Data: Int16 音訊資料
    /// - Returns: Float32 音訊資料
    static func convertInt16ToFloat32(_ int16Data: Data) -> Data {
        let int16Array = int16Data.withUnsafeBytes { pointer -> [Int16] in
            Array(pointer.bindMemory(to: Int16.self))
        }

        let floatArray: [Float] = int16Array.map { sample in
            Float(sample) / Float(Int16.max)
        }

        return Data(bytes: floatArray, count: floatArray.count * MemoryLayout<Float>.size)
    }

    // MARK: - 音訊分析

    /// 計算音訊音量（RMS）
    /// - Parameter buffer: 音訊 buffer
    /// - Returns: 音量值（0.0 ~ 1.0）
    static func calculateVolume(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let channelDataPointer = channelData[0]
        let channelDataArray = Array(UnsafeBufferPointer(
            start: channelDataPointer,
            count: Int(buffer.frameLength)
        ))

        // 計算 RMS（均方根）
        let sumOfSquares = channelDataArray.reduce(0.0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(channelDataArray.count))

        return min(1.0, rms)
    }

    /// 檢測是否有語音活動（簡單的能量閾值檢測）
    /// - Parameters:
    ///   - buffer: 音訊 buffer
    ///   - threshold: 閾值（0.0 ~ 1.0），預設 0.01
    /// - Returns: 是否偵測到語音
    static func detectVoiceActivity(_ buffer: AVAudioPCMBuffer, threshold: Float = 0.01) -> Bool {
        let volume = calculateVolume(buffer)
        return volume > threshold
    }

    // MARK: - 工具方法

    /// 格式化音訊資料大小
    /// - Parameter bytes: 位元組數
    /// - Returns: 格式化字串
    static func formatDataSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }

    /// 計算音訊時長
    /// - Parameters:
    ///   - dataSize: 資料大小（bytes）
    ///   - sampleRate: 採樣率
    ///   - channels: 聲道數
    ///   - bitDepth: 位元深度
    /// - Returns: 時長（秒）
    static func calculateDuration(
        dataSize: Int,
        sampleRate: Double,
        channels: Int,
        bitDepth: Int
    ) -> Double {
        let bytesPerSample = bitDepth / 8
        let totalSamples = dataSize / (bytesPerSample * channels)
        return Double(totalSamples) / sampleRate
    }
}
