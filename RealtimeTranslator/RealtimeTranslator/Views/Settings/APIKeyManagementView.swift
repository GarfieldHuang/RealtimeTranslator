//
//  APIKeyManagementView.swift
//  RealtimeTranslator
//
//  API Key 管理頁面
//

import SwiftUI

/// API Key 管理視圖
struct APIKeyManagementView: View {
    // MARK: - 環境

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    // MARK: - 狀態

    @State private var apiKey: String = ""
    @State private var showingAPIKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var alertMessage: String?
    @State private var showingAlert: Bool = false

    // MARK: - 視圖

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("當前 API Key")) {
                    if KeychainManager.shared.hasAPIKey() {
                        HStack {
                            Text(maskedAPIKey)
                                .font(.system(.body, design: .monospaced))

                            Spacer()

                            Button(action: { showingAPIKey.toggle() }) {
                                Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                            }
                        }

                        Button(action: { showingDeleteConfirmation = true }) {
                            Label("刪除 API Key", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("尚未設定 API Key")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("設定新的 API Key")) {
                    SecureField("sk-proj-...", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))

                    Button(action: saveAPIKey) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("儲存", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(apiKey.isEmpty || isSaving)
                }

                Section {
                    Link(destination: URL(string: Constants.API.apiKeyURL)!) {
                        Label("取得 API Key", systemImage: "link")
                    }
                }
            }
            .navigationTitle("API Key 管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("確認刪除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    deleteAPIKey()
                }
            } message: {
                Text("確定要刪除 API Key 嗎？")
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - 計算屬性

    /// 遮罩後的 API Key
    private var maskedAPIKey: String {
        if showingAPIKey, let key = KeychainManager.shared.getAPIKey() {
            return key
        } else if KeychainManager.shared.hasAPIKey() {
            return "sk-••••••••••••••••••"
        } else {
            return "未設定"
        }
    }

    // MARK: - 方法

    /// 儲存 API Key
    private func saveAPIKey() {
        guard KeychainManager.validateAPIKeyFormat(apiKey) else {
            alertMessage = "API Key 格式不正確"
            showingAlert = true
            return
        }

        isSaving = true

        Task {
            do {
                try KeychainManager.shared.saveAPIKey(apiKey)

                await MainActor.run {
                    appState.setAPIKeyConfigured(true)
                    alertMessage = "API Key 儲存成功"
                    showingAlert = true
                    apiKey = ""
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "儲存失敗：\(error.localizedDescription)"
                    showingAlert = true
                    isSaving = false
                }
            }
        }
    }

    /// 刪除 API Key
    private func deleteAPIKey() {
        do {
            try KeychainManager.shared.deleteAPIKey()
            appState.setAPIKeyConfigured(false)
            alertMessage = "API Key 已刪除"
            showingAlert = true
        } catch {
            alertMessage = "刪除失敗：\(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - 預覽

#Preview {
    APIKeyManagementView()
        .environmentObject(AppState())
}
