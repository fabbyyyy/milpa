import Foundation
import SwiftData

@Model
final class Parcela {
    var id: UUID
    var name: String
    var crop: String
    var stage: String
    var hectares: Double
    var createdAt: Date
    @Attribute(.externalStorage) var photoData: Data?
    
    init(id: UUID = UUID(), name: String, crop: String, stage: String, hectares: Double = 1.0, createdAt: Date = Date(), photoData: Data? = nil) {
        self.id = id
        self.name = name
        self.crop = crop
        self.stage = stage
        self.hectares = hectares
        self.createdAt = createdAt
        self.photoData = photoData
    }
    
    /// Days since the parcela was created (crop age)
    var daysSinceCreation: Int {
        Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
}

@Model
final class FarmerProfile {
    var id: UUID
    var name: String
    var totalHectares: Double
    
    init(id: UUID = UUID(), name: String, totalHectares: Double) {
        self.id = id
        self.name = name
        self.totalHectares = totalHectares
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var role: String          // "user" or "assistant"
    var content: String
    var timestamp: Date
    var conversationId: UUID  // groups messages into conversations
    
    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), conversationId: UUID) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.conversationId = conversationId
    }
    
    var isUser: Bool { role == "user" }
}
