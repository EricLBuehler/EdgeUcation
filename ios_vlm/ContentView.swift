//
//  ContentView.swift
//  ios_vlm
//
//  Created by Eric Buehler on 10/11/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var vm = VLMViewModel()

    @State private var pickerItem: PhotosPickerItem?
    @State private var messageText: String = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                VStack(spacing: 16) {
                    messagesList(proxy: proxy)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .simultaneousGesture(TapGesture().onEnded {
                            isComposerFocused = false
                        })
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(uiColor: .systemBackground))
                .safeAreaInset(edge: .bottom) {
                    composerBar
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(.thinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: -4)
                }
                .onChange(of: vm.messages.count) {
                    guard let lastID = vm.messages.last?.id else { return }
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
                .onChange(of: vm.messages.last?.text) {
                    guard let lastMessage = vm.messages.last,
                          lastMessage.isStreaming else { return }
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

        }
        .task(id: pickerItem) {
            guard let newItem = pickerItem else { return }
            do {
                let data = try await newItem.loadTransferable(type: Data.self)
                guard let data, let uiImg = UIImage(data: data) else { return }
                await MainActor.run {
                    vm.setAttachedImage(uiImg)
                }
            } catch {
                print("Photos picker error: \(error.localizedDescription)")
            }
            await MainActor.run { pickerItem = nil }
        }
    }

    @ViewBuilder
    private func messagesList(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                StatusBanner(status: vm.status)

                if let image = vm.attachedImage {
                    AttachmentPreviewView(image: image) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.setAttachedImage(nil)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                ForEach(vm.messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                }
            }
            .padding()
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: vm.attachedImage == nil ? "photo.on.rectangle" : "photo.fill.on.rectangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppCopy.attachImageLabel)
            .disabled(vm.attachedImage != nil)
            .opacity(vm.attachedImage == nil ? 1 : 0.4)

            TextField(AppCopy.composerPlaceholder, text: $messageText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
                .focused($isComposerFocused)
                .frame(maxWidth: .infinity)

            Button(action: sendMessage) {
                Group {
                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(AppCopy.sendButtonTitle)
                            .fontWeight(.semibold)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sendDisabled)

            Button(AppCopy.cancelButtonTitle) {
                vm.cancelCurrentRequest()
            }
            .buttonStyle(.bordered)
            .disabled(vm.isLoading == false)
            .accessibilityLabel(AppCopy.cancelResponseLabel)
        }
        .frame(maxWidth: .infinity)
    }

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sendDisabled: Bool {
        if vm.isLoading { return true }
        if trimmedMessage.isEmpty { return true }
        return vm.isModelReady == false
    }

    private func sendMessage() {
        let text = trimmedMessage
        guard text.isEmpty == false else { return }

        if vm.hasStarted {
            vm.sendFollowUp(prompt: text)
        } else {
            vm.startConversation(prompt: text)
        }

        messageText = ""
        isComposerFocused = false
    }
}

private struct StatusBanner: View {
    let status: ChatViewStatus

    var body: some View {
        Text(status.message)
            .font(.callout)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("statusLabel")
    }

    private var foregroundColor: Color {
        switch status {
        case .loading:
            return .secondary
        case .ready:
            return .secondary
        case .needsImage:
            return .accentColor
        case .error:
            return .red
        }
    }
}

private struct AttachmentPreviewView: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .font(.system(size: 20, weight: .bold))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }

            Text(AppCopy.attachmentPreviewCaption)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            VStack(alignment: .trailing, spacing: 6) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                MarkdownText(message.text)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                let bubble = MarkdownText(message.text.isEmpty ? AppCopy.streamingPlaceholder : message.text)
                    .padding(12)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                bubble

                if message.isStreaming {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .system:
            Text(message.text)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct MarkdownText: View {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
        } else {
            Text(content)
        }
    }
}
