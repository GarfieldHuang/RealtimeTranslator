//
//  TranscriptionView.swift
//  RealtimeTranslator
//
//  原文顯示視圖
//

import SwiftUI

/// 原文顯示視圖
struct TranscriptionView: View {
    let text: String
    let language: LanguageOption

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 標題
            HStack {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("原文（\(language.name)）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // 文字顯示區
            ScrollView {
                Text(text.isEmpty ? "等待語音輸入..." : text)
                    .font(.body)
                    .foregroundColor(text.isEmpty ? .gray : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.98, opacity: 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - 預覽

#Preview {
    VStack {
        TranscriptionView(text: "Hello, how are you?", language: .defaultInputLanguage)
        TranscriptionView(text: "", language: .defaultInputLanguage)
    }
}
