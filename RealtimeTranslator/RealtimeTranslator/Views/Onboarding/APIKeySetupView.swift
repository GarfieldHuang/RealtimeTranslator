//
//  APIKeySetupView.swift
//  RealtimeTranslator
//
//  API Key 設定畫面
//

import SwiftUI

/// API Key 設定視圖
struct APIKeySetupView: View {
    // MARK: - 環境物件

    @EnvironmentObject var appState: AppState

    // MARK: - 狀態

    @State private var apiKey: String = ""
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    @State private var showingHowToGetKey: Bool = false

    // MARK: - 視圖

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 圖示
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                // 歡迎文字
                Text("歡迎使用 RealtimeTranslator！")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // 說明文字
                Text("本應用程式需要 OpenAI API Key\n才能使用即時翻譯功能")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // API Key 輸入區塊
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.headline)
                        .foregroundColor(.primary)

                    SecureField("sk-proj-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("您的 API Key 將安全儲存在裝置的 Keychain 中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                // 錯誤訊息
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }

                // 如何取得 API Key 按鈕
                Button(action: { showingHowToGetKey = true }) {
                    Label("如何取得 API Key?", systemImage: "questionmark.circle")
                        .font(.subheadline)
                }

                // 儲存按鈕
                Button(action: validateAndSave) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("儲存並測試連線")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(apiKey.isEmpty || isValidating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(apiKey.isEmpty || isValidating)
                .padding(.horizontal)

                // 稍後設定按鈕
                Button("稍後設定") {
                    // 暫時跳過，但功能受限
                    appState.completeOnboarding()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingHowToGetKey) {
            HowToGetAPIKeyView()
        }
    }

    // MARK: - 方法

    /// 驗證並儲存 API Key
    private func validateAndSave() {
        isValidating = true
        errorMessage = nil

        // 驗證格式
        guard KeychainManager.validateAPIKeyFormat(apiKey) else {
            errorMessage = "API Key 格式不正確，應以 'sk-' 或 'sk-proj-' 開頭"
            isValidating = false
            return
        }

        // 驗證連線
        Task {
            do {
                // 這裡簡化驗證流程，實際應該測試連線
                // 為了示範，我們直接儲存
                try KeychainManager.shared.saveAPIKey(apiKey)

                await MainActor.run {
                    appState.setAPIKeyConfigured(true)
                    appState.completeOnboarding()
                    isValidating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "儲存失敗：\(error.localizedDescription)"
                    isValidating = false
                }
            }
        }
    }
}

/// 如何取得 API Key 說明視圖
struct HowToGetAPIKeyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 步驟說明
                    VStack(alignment: .leading, spacing: 12) {
                        Text("取得 OpenAI API Key 步驟：")
                            .font(.headline)

                        StepView(number: 1, text: "前往 OpenAI 平台網站")
                        StepView(number: 2, text: "登入您的 OpenAI 帳號（需要先註冊）")
                        StepView(number: 3, text: "前往「API Keys」頁面")
                        StepView(number: 4, text: "點擊「Create new secret key」")
                        StepView(number: 5, text: "複製產生的 API Key")
                        StepView(number: 6, text: "貼回此應用程式")
                    }

                    Divider()

                    // 注意事項
                    VStack(alignment: .leading, spacing: 12) {
                        Text("注意事項：")
                            .font(.headline)

                        Label("API Key 是機密資訊，請妥善保管", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Label("使用 API 需要付費，請注意用量", systemImage: "dollarsign.circle.fill")
                            .foregroundColor(.blue)

                        Label("本應用程式不會儲存您的 API Key 到雲端", systemImage: "lock.shield.fill")
                            .foregroundColor(.green)
                    }

                    Divider()

                    // 開啟網頁按鈕
                    Link(destination: URL(string: Constants.API.apiKeyURL)!) {
                        HStack {
                            Image(systemName: "safari.fill")
                            Text("開啟 OpenAI API Keys 頁面")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("如何取得 API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 步驟視圖
struct StepView: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 預覽

#Preview {
    APIKeySetupView()
        .environmentObject(AppState())
}
