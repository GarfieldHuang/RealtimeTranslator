//
//  RecordButton.swift
//  RealtimeTranslator
//
//  錄音按鈕元件
//

import SwiftUI
import Foundation

/// 錄音按鈕視圖
struct RecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 麥克風圖示
                Image(systemName: isRecording ? "mic.fill" : "mic.slash.fill")
                    .font(.title2)

                // 按鈕文字
                Text(isRecording ? "停止錄音" : "開始錄音")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(isPulsing && isRecording ? 1.05 : 1.0)
            .animation(
                isRecording ?
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    .default,
                value: isPulsing
            )
        }
        .disabled(!isEnabled)
        .onAppear {
            isPulsing = isRecording
        }
        .onChange(of: isRecording) { _, newIsRecording in
            isPulsing = newIsRecording
        }
    }

    /// 背景顏色
    private var backgroundColor: Color {
        if !isEnabled {
            return .gray
        } else if isRecording {
            return Constants.UI.recordingColor
        } else {
            return .blue
        }
    }
}

// MARK: - 預覽

#Preview {
    VStack(spacing: 20) {
        RecordButton(isRecording: false, isEnabled: true) {
            print("開始錄音")
        }
        .padding()

        RecordButton(isRecording: true, isEnabled: true) {
            print("停止錄音")
        }
        .padding()

        RecordButton(isRecording: false, isEnabled: false) {
            print("無法錄音")
        }
        .padding()
    }
}
