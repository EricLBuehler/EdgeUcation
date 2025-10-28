//
//  AppCopy.swift
//  ios_vlm
//
//  Created by ChatGPT on 10/28/25.
//

import Foundation

enum AppCopy {
    // Status messages
    static let loadingModel = "⏳✨"
    static let imageAttachedAwaitingMessage = "🖼️➡️💬"
    static let imageClearedKeepChatting = "🧹✨💬"
    static let modelReadyToChat = "🤖✅💬"
    static let generationCancelled = "⛔️🛑"
    static let modelSessionNotReady = "⚠️🤖⏸️"
    static let modelStillLoading = "🌀⏳"
    static let generatingResponse = "🛠️💬"
    static let streamingResponse = "📡💬"
    static let sendToTryAgain = "🔁📨"
    static let imageFailedToLoad = "📵🖼️"
    static let modelSessionUnavailable = "📴🤖"
    static let imageConversionFailed = "🚫🔄🖼️"

    static func readyForNextMessage(isFollowUp: Bool) -> String {
        if isFollowUp {
            return "➕💬🖼️"
        } else {
            return "💡❓🖼️"
        }
    }

    static let modelLoadFailed = "🚫🤖"

    static let streamedError = "⚠️💬"

    // UI strings
    static let attachImageLabel = "🖼️➕"
    static let composerPlaceholder = "💬✍️"
    static let sendButtonTitle = "📤"
    static let cancelButtonTitle = "⏹️"
    static let cancelResponseLabel = "⏹️🔄"
    static let attachmentPreviewCaption = "📎➡️💬"
    static let streamingPlaceholder = "⌛️"
}
