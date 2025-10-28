//
//  VLMViewModel.swift
//  ios_vlm
//
//  Created by Eric Buehler on 10/11/25.
//

import Foundation
import SwiftUI
import Combine
import MLXVLM
import MLXLMCommon
import UIKit

enum ChatViewStatus: Equatable {
    case loading(String)
    case ready(String)
    case needsImage(String)
    case error(String)

    var message: String {
        switch self {
        case let .loading(message),
             let .ready(message),
             let .needsImage(message),
             let .error(message):
            return message
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

@MainActor
class VLMViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var isModelReady: Bool = false
    @Published private(set) var status: ChatViewStatus = .loading(AppCopy.loadingModel)
    @Published private(set) var hasStarted: Bool = false
    @Published private(set) var attachedImage: UIImage?

    private var session: ChatSession?
    private var currentRequestTask: Task<Void, Never>?

    init() {
        Task { await loadVLM() }
    }

    func setAttachedImage(_ image: UIImage?) {
        attachedImage = image
        guard isModelReady else { return }

        if image != nil {
            status = .needsImage(AppCopy.imageAttachedAwaitingMessage)
        } else if hasStarted {
            status = .ready(AppCopy.imageClearedKeepChatting)
        } else {
            status = .ready(AppCopy.modelReadyToChat)
        }
    }

    func startConversation(prompt: String) {
        runConversation(prompt: prompt, isFollowUp: false)
    }

    func sendFollowUp(prompt: String) {
        guard hasStarted else {
            startConversation(prompt: prompt)
            return
        }
        runConversation(prompt: prompt, isFollowUp: true)
    }

    func cancelCurrentRequest() {
        guard let task = currentRequestTask else { return }
        task.cancel()
        status = .ready(AppCopy.generationCancelled)
    }

    private func runConversation(prompt: String, isFollowUp: Bool) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard currentRequestTask == nil else { return }
        guard session != nil else {
            status = .error(AppCopy.modelSessionNotReady)
            return
        }
        guard isModelReady else {
            status = .loading(AppCopy.modelStillLoading)
            return
        }

        isLoading = true
        status = .loading(AppCopy.generatingResponse)

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performConversation(prompt: trimmed, isFollowUp: isFollowUp)
        }

        currentRequestTask = task
    }

    private func loadVLM() async {
        do {
            let model = try await loadModel(id: "mlx-community/gemma-3-4b-it-4bit")
            session = ChatSession(model)
            isModelReady = true
            status = .ready(AppCopy.modelReadyToChat)
        } catch {
            print("Model load error: \(error.localizedDescription)")
            let message = AppCopy.modelLoadFailed
            status = .error(message)
            appendSystemMessage(message)
        }
    }

    private func makeMLXImage(from image: UIImage) -> UserInput.Image? {
        if let ciImage = image.ciImage {
            return .ciImage(ciImage)
        }
        if let cgImage = image.cgImage {
            return .ciImage(CIImage(cgImage: cgImage))
        }
        if let ciImage = CIImage(image: image) {
            return .ciImage(ciImage)
        }
        return nil
    }

    private func performConversation(prompt: String, isFollowUp: Bool) async {
        var placeholderID: UUID?

        defer {
            isLoading = false
            currentRequestTask = nil
        }

        var uiImageForMessage: UIImage?
        var mlxImage: UserInput.Image?

        if let image = attachedImage {
            guard let converted = makeMLXImage(from: image) else {
                appendSystemMessage(AppCopy.imageConversionFailed)
                attachedImage = nil
                status = .error(AppCopy.imageFailedToLoad)
                return
            }
            uiImageForMessage = image
            mlxImage = converted
            withAnimation(.easeInOut(duration: 0.2)) {
                attachedImage = nil
            }
        }

        appendUserMessage(prompt, image: uiImageForMessage)
        placeholderID = appendAssistantMessage("", isStreaming: true)

        do {
            guard let session else {
                status = .error(AppCopy.modelSessionUnavailable)
                return
            }

            let answer: String
            if let mlxImage {
                answer = try await session.respond(to: prompt, image: mlxImage)
            } else {
                answer = try await session.respond(to: prompt)
            }

            try Task.checkCancellation()

            status = .loading(AppCopy.streamingResponse)
            if let placeholderID {
                try await streamAnswer(answer, to: placeholderID)
            }

            hasStarted = true
            status = .ready(AppCopy.readyForNextMessage(isFollowUp: isFollowUp))
        } catch is CancellationError {
            if let placeholderID {
                updateMessage(id: placeholderID) { message in
                    message.text = AppCopy.generationCancelled
                    message.isStreaming = false
                }
            }
            status = .ready(AppCopy.generationCancelled)
        } catch {
            print("Conversation error: \(error.localizedDescription)")
            if let placeholderID {
                updateMessage(id: placeholderID) { message in
                    message.text = AppCopy.streamedError
                    message.isStreaming = false
                }
            }
            status = .error(AppCopy.sendToTryAgain)
        }
    }

    private func streamAnswer(_ answer: String, to messageID: UUID) async throws {
        var partial = ""
        for character in answer {
            try Task.checkCancellation()
            partial.append(character)
            updateMessage(id: messageID) { $0.text = partial }
            let delay: UInt64 = character.isWhitespace ? 40_000_000 : 18_000_000
            try await Task.sleep(nanoseconds: delay)
        }
        updateMessage(id: messageID) { message in
            message.text = partial
            message.isStreaming = false
        }
    }

    private func appendUserMessage(_ text: String, image: UIImage? = nil) {
        messages.append(ChatMessage(role: .user, text: text, image: image))
    }

    @discardableResult
    private func appendAssistantMessage(_ text: String, isStreaming: Bool) -> UUID {
        let message = ChatMessage(role: .assistant, text: text, image: nil, isStreaming: isStreaming)
        messages.append(message)
        return message.id
    }

    private func appendSystemMessage(_ text: String) {
        messages.append(ChatMessage(role: .system, text: text, image: nil))
    }

    private func updateMessage(id: UUID, mutate: (inout ChatMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        mutate(&messages[index])
    }
}
