# RealtimeTranslator

> 基於 OpenAI Realtime API 的即時語音翻譯 iOS 應用程式

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📱 專案簡介

RealtimeTranslator 是一款 iOS 原生應用程式，利用 OpenAI 的 Realtime API (GPT-4o) 提供即時語音轉錄與翻譯功能。支援 16 種語言之間的即時互譯，並具備智能語音檢測功能以優化 API 使用成本。

### 主要功能

- ✅ **即時翻譯模式**：持續監聽並即時翻譯語音
- ✅ **錄音翻譯模式**：錄製完整語音後進行翻譯
- ✅ **智能語音檢測 (VAD)**：AI 驅動的人聲識別，節省 60-80% API 成本
- ✅ **多語言支援**：16 種語言（中文、英文、日文、韓文、西班牙文等）
- ✅ **歷史記錄**：自動儲存翻譯記錄，支援匯出
- ✅ **Token 統計**：即時追蹤 API 使用量
- ✅ **可調參數**：語音檢測靈敏度、停頓時間等可自訂

---

## 🏗️ 技術架構

### 開發環境

- **IDE**: Xcode 15.0+
- **程式語言**: Swift 5.9
- **最低支援版本**: iOS 17.0
- **架構模式**: MVVM (Model-View-ViewModel)
- **UI 框架**: SwiftUI

### 核心技術棧

#### Apple Frameworks

| Framework | 用途 | 版本 |
|-----------|------|------|
| **SwiftUI** | UI 介面建構 | iOS 17.0+ |
| **Combine** | 響應式編程、狀態管理 | iOS 17.0+ |
| **AVFoundation** | 音訊錄製與處理 | iOS 17.0+ |
| **Speech** | 智能語音活動檢測 (VAD) | iOS 17.0+ |
| **Foundation** | 基礎資料處理 | iOS 17.0+ |
| **Security** | Keychain 存儲 API Key | iOS 17.0+ |

#### 第三方服務

| 服務 | 用途 | 版本 |
|------|------|------|
| **OpenAI Realtime API** | 語音轉錄與翻譯 | gpt-realtime (穩定版) / gpt-4o-realtime-preview (可選) |

#### 網路通訊

- **WebSocket**: URLSessionWebSocketTask (原生實作)
- **協定**: WSS (WebSocket Secure)
- **音訊格式**: PCM16 (16-bit Linear PCM, 24kHz, Mono)

---

## 📦 專案結構

```
RealtimeTranslator/
├── App/                                    # 應用程式入口
│   ├── RealtimeTranslatorApp.swift       # App 主入口
│   └── ContentView.swift                  # 根視圖
│
├── Models/                                 # 資料模型
│   ├── AppState.swift                     # 應用程式狀態
│   ├── ConnectionState.swift             # 連線狀態枚舉
│   ├── LanguageOption.swift              # 語言選項
│   ├── TokenUsage.swift                  # Token 使用統計
│   └── TranscriptionItem.swift           # 翻譯記錄項目
│
├── Views/                                  # UI 視圖
│   ├── Main/
│   │   ├── MainView.swift                # 主畫面
│   │   ├── RecordButton.swift            # 錄音按鈕
│   │   └── LiveTranslationButton.swift   # 即時翻譯按鈕
│   ├── Onboarding/
│   │   └── OnboardingView.swift          # 引導頁面
│   └── Settings/
│       ├── SettingsView.swift            # 設定頁面
│       ├── HistoryView.swift             # 歷史記錄
│       └── AboutView.swift               # 關於頁面
│
├── Services/                               # 核心服務
│   ├── RealtimeAPIService.swift          # API 服務核心
│   ├── WebSocketManager.swift            # WebSocket 管理
│   ├── AudioRecorder.swift               # 音訊錄製
│   ├── AudioProcessor.swift              # 音訊處理
│   ├── VoiceActivityDetector.swift       # 智能語音檢測 (NEW!)
│   └── KeychainManager.swift             # Keychain 管理
│
├── Utilities/                              # 工具類
│   ├── Constants.swift                    # 常數定義
│   └── RealtimeAPIError.swift            # 錯誤定義
│
└── Resources/                              # 資源文件
    ├── Info.plist                         # 應用程式配置
    └── Assets.xcassets/                   # 圖片資源
```

---

## 🎯 核心元件說明

### 1. RealtimeAPIService

**職責**: WebSocket 連線、音訊傳輸、翻譯邏輯控制

**關鍵功能**:
- WebSocket 連線管理 (OpenAI Realtime API)
- 音訊資料即時傳輸 (Base64 PCM16 編碼)
- 翻譯回應解析 (JSON 格式)
- 語音活動檢測整合 (Smart VAD)
- 歷史記錄自動儲存

**依賴**:
- `WebSocketManager`: WebSocket 底層通訊
- `AudioRecorder`: 音訊錄製
- `VoiceActivityDetector`: 智能 VAD

### 2. VoiceActivityDetector (v1.3.0 新增)

**職責**: 使用 iOS Speech Framework 進行人聲檢測

**技術細節**:
- 基於 `SFSpeechRecognizer` 實作
- 即時辨識語音開始/結束事件
- 支援 16 種語言的 Locale 配置
- 可調參數：靜默閾值、最短語音長度

**優勢**:
- AI 驅動，準確區分人聲與噪音
- 節省 60-80% API 請求成本
- 支援短句檢測（如「測試」兩字）

### 3. WebSocketManager

**職責**: WebSocket 連線的底層封裝

**功能**:
- 自動重連機制（最多 5 次）
- Keepalive 心跳檢測（每 4 秒）
- 連線狀態監聽
- 訊息收發管理

### 4. AudioRecorder

**職責**: 麥克風音訊錄製與處理

**技術規格**:
- 採樣率: 24kHz
- 聲道: Mono (單聲道)
- 格式: 16-bit Linear PCM
- Buffer 大小: 1024 frames
- 即時音量監測 (用於舊版 VAD)

### 5. KeychainManager

**職責**: 安全儲存 OpenAI API Key

**安全措施**:
- 使用 iOS Keychain 加密存儲
- 支援讀取、儲存、刪除操作
- 錯誤處理機制

---

## 🔧 使用的解決方案 (Solutions)

### 1. 智能語音檢測 (Smart VAD)

**問題**: 原本每 4 秒固定送出 API 請求，造成成本過高

**解決方案**:
- **主方案**: Speech Framework 驅動的 AI 語音檢測
  - 即時識別語音開始/結束
  - 只在真正說話時送出請求
  - 成本節省 60-80%

- **備用方案**: 音量閾值檢測
  - 基於 AVFoundation 的音量監測
  - 當 Speech Framework 不可用時自動切換

### 2. 響應式狀態管理

**方案**: Combine + @Published
- 使用 `@Published` 屬性包裝器
- 自動觸發 UI 更新
- 減少手動狀態同步

### 3. 安全的 API Key 存儲

**方案**: iOS Keychain
- 不將 API Key 寫入 UserDefaults
- 利用系統加密機制
- 防止逆向工程竊取

### 4. 即時音訊串流

**方案**: WebSocket + Base64 編碼
- 每 0.1 秒傳送音訊片段
- 降低延遲感
- 支援中斷恢復

### 5. 歷史記錄持久化

**方案**: UserDefaults + Codable
- 使用 `Codable` 協定序列化
- 自動儲存（最多 100 筆）
- 支援匯出為文字檔

---

## 📋 外部依賴項 (Dependencies)

### ✅ 無第三方套件！

本專案**完全使用 Apple 原生 Framework**，沒有依賴任何第三方套件管理工具（CocoaPods、SPM、Carthage）。

**優勢**:
- ✅ 無版本衝突問題
- ✅ 編譯速度快
- ✅ 專案體積小
- ✅ 安全性高
- ✅ 長期維護性佳

---

## 🔑 必要設定

### 1. 取得 OpenAI API Key

1. 前往 [OpenAI Platform](https://platform.openai.com/api-keys)
2. 建立新的 API Key
3. 確保帳戶有 Realtime API 使用權限

### 2. Info.plist 權限設定

本專案需要以下權限：

```xml
<!-- 麥克風權限 (必要) -->
<key>NSMicrophoneUsageDescription</key>
<string>需要麥克風權限以進行語音輸入與即時翻譯</string>

<!-- 語音識別權限 (智能 VAD 使用) -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>需要語音識別權限以智能檢測說話的開始和結束，提升翻譯準確度並降低成本</string>

<!-- 網路連線說明 -->
<key>NSLocalNetworkUsageDescription</key>
<string>需要網路連線以使用 OpenAI 即時翻譯服務</string>
```

---

## 🚀 安裝與執行

### 前置需求

- macOS 14.0+
- Xcode 15.0+
- iOS 17.0+ 實體裝置或模擬器
- OpenAI API Key

### 步驟

1. **Clone 專案**
   ```bash
   git clone https://github.com/GarfieldHuang/RealtimeTranslator.git
   cd RealtimeTranslator
   ```

2. **開啟 Xcode 專案**
   ```bash
   open RealtimeTranslator/RealtimeTranslator.xcodeproj
   ```

3. **選擇目標裝置**
   - 實體裝置: 需要開發者帳號簽署
   - 模擬器: 可直接執行（但無法測試麥克風功能）

4. **建置並執行**
   - 快捷鍵: `⌘R`
   - 或點擊 Xcode 左上角的播放按鈕

5. **初次設定**
   - 輸入 OpenAI API Key
   - 授予麥克風權限
   - 授予語音識別權限（智能 VAD 使用）

---

## 💡 使用說明

### 錄音翻譯模式

1. 選擇輸入語言（或使用「自動偵測」）
2. 選擇目標翻譯語言
3. 長按「錄音」按鈕
4. 說話完畢後放開按鈕
5. 等待翻譯結果顯示

### 即時翻譯模式

1. 選擇輸入語言和目標語言
2. 點擊「即時翻譯」按鈕開始
3. 持續說話，系統會即時翻譯
4. 再次點擊按鈕結束翻譯
5. 內容自動儲存至歷史記錄

### 智能 VAD 設定

在「設定」中調整各項參數：

#### API 模型選擇

- **gpt-realtime (穩定版)**: 最新穩定版，價格便宜 20%（預設）
- **gpt-4o-realtime-preview (2024-12-17)**: Preview 版本
- **gpt-4o-realtime-preview (2024-10-01)**: ⚠️ 即將棄用

#### 智能語音檢測

- **啟用智能 VAD**: 開啟 AI 語音檢測（推薦）
- **停頓檢測時間**: 停頓多久後送出（預設 1.0 秒）
- **最短語音長度**: 過濾雜音門檻（預設 0.05 秒）

---

## 📊 版本歷史

### v1.3.3 (2025-01-05) - 智能 VAD 幻覺回應修復

**修復**:
- 🐛 修正智能 VAD 誤觸發導致提交空音訊片段，產生幻覺回應的問題
- 🐛 新增音訊數據量檢查，只有累積足夠的音訊數據才會提交（至少 10 個片段 ≈ 0.3 秒）
- 🐛 修正智能 VAD 模式下 `audioBufferSize` 未正確累積的問題

**技術改進**:
- 在 `handleSpeechEnded()` 中添加音訊數據量驗證
- 優化 `sendAudioData()` 方法，在語音片段中正確累積音訊數據
- 防止 VAD 誤觸發時提交無效音訊給 API

### v1.3.2 (2025-01-05) - 音訊緩衝區清空修復

**修復**:
- 🐛 修正音訊緩衝區未清空導致重複處理舊音訊的問題
- 🐛 解決說完一句話後，API 會回應不相關內容的 bug
- 🚀 在每次提交音訊後立即發送 `input_audio_buffer.clear` 事件

**技術改進**:
- 優化 `commitAudioBuffer()` 方法，確保每次都是全新的翻譯請求

### v1.3.1 (2025-01-04) - API 模型選擇功能

**新功能**:
- ✨ **新增 API 模型選擇功能**
  - 支援 `gpt-realtime` 穩定版（預設，價格便宜 20%）
  - 支援 preview 版本（2024-12-17、2024-10-01）
  - 在設定頁面可切換模型
- ✨ 新增 `RealtimeModel` 枚舉類型管理模型選項

**優化**:
- 🚀 預設使用穩定版模型（無 preview 無日期）
- 🚀 移除硬編碼的模型名稱，改用動態選擇

### v1.3.0 (2025-01-04) - 智能語音檢測與成本優化

**新功能**:
- ✨ 新增智能 VAD（Speech Framework）
- ✨ AI 驅動的人聲檢測，節省 60-80% API 成本
- ✨ 支援短句檢測（如「測試」兩字）
- ✨ 可調參數：靜默閾值、最短語音長度

**優化**:
- 🚀 移除固定 4 秒安全網機制
- 🚀 智能 VAD 模式下只在真正說話時送出請求
- 🚀 備用方案：舊版音量檢測 VAD

**權限**:
- 🔐 新增語音識別權限請求

### v1.2.1 (2025-01-03) - UI 修復

**修復**:
- 🐛 修正輸入語言變更時，原文語言標籤未更新的問題

### v1.2.0 (2025-01-02) - 即時翻譯優化

**新功能**:
- ✨ 智能音訊提交機制
- ✨ 可調參數：停頓閾值、緩衝區大小、提交間隔
- ✨ VAD 靈敏度調整

**優化**:
- 🚀 改善即時翻譯的響應速度
- 🚀 優化音訊緩衝區管理

### v1.1.0 (2025-10-31) - 輸入語言選擇

**新功能**:
- ✨ 新增輸入語言選擇功能
- ✨ 支援 16 種語言輸入

### v1.0.0 (2025-10-30) - 初始版本

**核心功能**:
- ✨ 錄音翻譯模式
- ✨ 即時翻譯模式
- ✨ 歷史記錄管理
- ✨ Token 使用統計

---

## 🤝 貢獻指南

歡迎提交 Issue 或 Pull Request！

### 開發流程

1. Fork 專案
2. 建立功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交變更 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 開啟 Pull Request

---

## 📄 授權條款

本專案採用 MIT 授權條款。詳見 [LICENSE](LICENSE) 文件。

---

## 📮 聯絡方式

- **作者**: Garfield Huang
- **GitHub**: [@GarfieldHuang](https://github.com/GarfieldHuang)
- **專案連結**: [RealtimeTranslator](https://github.com/GarfieldHuang/RealtimeTranslator)

---

## 🙏 致謝

- [OpenAI](https://openai.com) - 提供 Realtime API
- Apple - SwiftUI 與各項原生 Framework
- iOS 開發社群

---

## ⚠️ 注意事項

1. **API 成本**: Realtime API 按使用量計費，建議啟用智能 VAD 以降低成本
2. **網路需求**: 需要穩定的網路連線
3. **隱私保護**: API Key 儲存於本機 Keychain，不會上傳
4. **實體裝置測試**: 麥克風功能需在實體裝置上測試
5. **語音識別權限**: 智能 VAD 需要用戶授予語音識別權限

---

**⭐ 如果這個專案對你有幫助，請給個星星！**
