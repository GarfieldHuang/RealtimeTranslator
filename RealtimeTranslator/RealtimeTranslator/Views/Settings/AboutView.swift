//
//  AboutView.swift
//  RealtimeTranslator
//
//  關於頁面
//

import SwiftUI

/// 關於視圖
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App 圖示
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 40)

                    // App 名稱
                    Text("RealtimeTranslator")
                        .font(.title)
                        .fontWeight(.bold)

                    // 版本資訊
                    Text("版本 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.horizontal)

                    // 描述
                    VStack(spacing: 16) {
                        Text("即時語音翻譯應用程式")
                            .font(.headline)

                        Text("基於 OpenAI Realtime API，提供高品質的即時語音轉錄與翻譯服務。")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // 功能特色
                    VStack(alignment: .leading, spacing: 12) {
                        Text("主要功能")
                            .font(.headline)
                            .padding(.horizontal)

                        FeatureRow(icon: "mic.fill", title: "即時語音轉錄", description: "低延遲的語音識別")
                        FeatureRow(icon: "globe", title: "多語言翻譯", description: "支援 6 種以上語言")
                        FeatureRow(icon: "lock.shield.fill", title: "安全儲存", description: "API Key 加密保護")
                        FeatureRow(icon: "chart.bar.fill", title: "使用統計", description: "即時追蹤 Token 使用")
                    }

                    Divider()
                        .padding(.horizontal)

                    // 技術資訊
                    VStack(spacing: 12) {
                        Text("技術資訊")
                            .font(.headline)

                        VStack(spacing: 8) {
                            InfoRow(label: "開發框架", value: "SwiftUI")
                            InfoRow(label: "API 服務", value: "OpenAI Realtime API")
                            InfoRow(label: "音訊處理", value: "AVFoundation")
                            InfoRow(label: "最低版本", value: "iOS 16.0+")
                        }
                    }

                    Divider()
                        .padding(.horizontal)

                    // 連結
                    VStack(spacing: 12) {
                        Link(destination: URL(string: Constants.API.documentationURL)!) {
                            Label("OpenAI API 文件", systemImage: "book.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    // 版權資訊
                    Text("© 2024 RealtimeTranslator\nPowered by OpenAI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("關於")
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

/// 功能列表項目
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
}

/// 資訊列表項目
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
}

// MARK: - 預覽

#Preview {
    AboutView()
}
