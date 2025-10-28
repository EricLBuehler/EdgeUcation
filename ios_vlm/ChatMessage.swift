//
//  ChatMessage.swift
//  ios_vlm
//
//  Created by Eric Buehler on 10/12/25.
//

import Foundation
import UIKit

struct ChatMessage: Identifiable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    var text: String
    let image: UIImage?
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        image: UIImage? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.image = image
        self.isStreaming = isStreaming
    }
}
