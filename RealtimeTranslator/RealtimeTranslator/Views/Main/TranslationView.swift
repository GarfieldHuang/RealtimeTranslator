//
//  TranslationView.swift
//  RealtimeTranslator
//
//  翻譯顯示視圖
//

import SwiftUI

/// 翻譯顯示視圖
struct TranslationView: View {
    let text: String
    let language: LanguageOption

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 標題
            HStack {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("翻譯（\(language.name)）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // 文字顯示區
            ScrollView {
                Text(text.isEmpty ? "翻譯結果將顯示在此..." : text)
                    .font(.body)
                    .foregroundColor(text.isEmpty ? .gray : .black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.95, opacity: 1.0))
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
        TranslationView(text: "你好，你好嗎？", language: .defaultLanguage)
        TranslationView(text: "", language: .defaultLanguage)
    }
}
