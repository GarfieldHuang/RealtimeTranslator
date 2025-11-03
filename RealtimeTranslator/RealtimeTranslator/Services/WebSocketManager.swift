//
//  WebSocketManager.swift
//  RealtimeTranslator
//
//  WebSocket 連線管理
//

import Foundation

/// WebSocket 管理類別
class WebSocketManager: NSObject {
    // MARK: - 屬性

    /// WebSocket 任務
    private var webSocketTask: URLSessionWebSocketTask?

    /// URL Session
    private var urlSession: URLSession?

    /// Keepalive 計時器
    private var keepaliveTimer: Timer?

    /// 重連計時器
    private var reconnectTimer: Timer?

    /// 重連次數
    private var reconnectAttempts = 0

    /// 最大重連次數
    private let maxReconnectAttempts = 5

    /// 是否正在重連
    private var isReconnecting = false

    // MARK: - 回調

    /// 訊息接收回調
    var onMessageReceived: ((Data) -> Void)?

    /// 連線狀態變更回調
    var onConnectionStateChanged: ((ConnectionState) -> Void)?

    /// 文字訊息接收回調（用於調試）
    var onTextMessageReceived: ((String) -> Void)?

    // MARK: - 初始化

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }

    // MARK: - 公開方法

    /// 連線到 WebSocket
    /// - Parameters:
    ///   - url: WebSocket URL
    ///   - headers: HTTP 標頭
    func connect(url: URL, headers: [String: String]) {
        // 更新狀態
        onConnectionStateChanged?(.connecting)

        // 建立請求
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 建立 WebSocket 任務
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        // 開始接收訊息
        receiveMessage()

        // 啟動 keepalive
        startKeepalive()
    }

    /// 中斷連線
    func disconnect() {
        stopKeepalive()
        stopReconnectTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        onConnectionStateChanged?(.disconnected)
    }

    /// 發送訊息
    /// - Parameter message: JSON Data
    func send(message: Data) {
        let messageString = String(data: message, encoding: .utf8) ?? ""
        let webSocketMessage = URLSessionWebSocketTask.Message.string(messageString)

        webSocketTask?.send(webSocketMessage) { [weak self] error in
            if let error = error {
                print("❌ WebSocket 發送錯誤: \(error.localizedDescription)")
                self?.handleError(error)
            }
        }
    }

    /// 發送 Ping 保持連線
    func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("❌ Ping 失敗: \(error.localizedDescription)")
                self?.handleError(error)
            }
        }
    }

    // MARK: - 私有方法

    /// 接收訊息
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    // 處理文字訊息
                    if let data = text.data(using: .utf8) {
                        self?.onMessageReceived?(data)
                    }
                    self?.onTextMessageReceived?(text)

                case .data(let data):
                    // 處理二進位訊息
                    self?.onMessageReceived?(data)

                @unknown default:
                    print("⚠️ 未知的訊息類型")
                }

                // 繼續接收下一則訊息
                self?.receiveMessage()

            case .failure(let error):
                print("❌ WebSocket 接收錯誤: \(error.localizedDescription)")
                self?.handleError(error)
            }
        }
    }

    /// 啟動 Keepalive 機制
    func startKeepalive() {
        stopKeepalive()

        // 每 4 秒發送一次 ping
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    /// 停止 Keepalive
    private func stopKeepalive() {
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
    }

    /// 處理錯誤
    private func handleError(_ error: Error) {
        let errorMessage = error.localizedDescription
        onConnectionStateChanged?(.error(errorMessage))

        // 嘗試重連
        attemptReconnect()
    }

    /// 嘗試重連
    private func attemptReconnect() {
        guard !isReconnecting else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            onConnectionStateChanged?(.error("重連失敗次數過多，請手動重新連線"))
            return
        }

        isReconnecting = true
        reconnectAttempts += 1

        // 計算重連延遲（指數退避）
        let delay = pow(2.0, Double(reconnectAttempts))

        print("⏱️ \(delay) 秒後嘗試第 \(reconnectAttempts) 次重連...")

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.isReconnecting = false
            // 注意：這裡需要儲存原始的 URL 和 headers 才能重連
            // 實際重連邏輯應該在 RealtimeAPIService 中處理
        }
    }

    /// 停止重連計時器
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        isReconnecting = false
    }

    /// 重置重連計數
    func resetReconnectAttempts() {
        reconnectAttempts = 0
        isReconnecting = false
    }

    // MARK: - 清理

    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    /// WebSocket 連線成功
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket 連線成功")
        onConnectionStateChanged?(.connected)
        resetReconnectAttempts()
    }

    /// WebSocket 連線關閉
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "未知原因"
        print("⚠️ WebSocket 連線已關閉，代碼: \(closeCode.rawValue)，原因: \(reasonString)")

        onConnectionStateChanged?(.disconnected)

        // 非正常關閉時嘗試重連
        if closeCode != .goingAway {
            attemptReconnect()
        }
    }
}

// MARK: - URLSessionDelegate

extension WebSocketManager: URLSessionDelegate {
    /// 處理認證挑戰（TLS）
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 允許自簽憑證（僅用於開發環境）
        // 正式環境應該實作憑證釘扎
        completionHandler(.performDefaultHandling, nil)
    }
}
