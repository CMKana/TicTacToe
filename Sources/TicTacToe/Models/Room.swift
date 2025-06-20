import Fluent
import Foundation.NSData
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Room: Model, @unchecked Sendable, ModelSessionAuthenticatable {
    static let schema = "rooms"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "playerX")
    var playerX: User

    @OptionalParent(key: "playerO")
    var playerO: User?

    @Field(key: "board")
    var board: String

    @Field(key: "isFinished")
    var isFinished: Bool
    
    @Field(key: "currentPlayerID")
    var currentPlayerID: UUID
    
    init() {}

    init(id: UUID? = nil, playerXID: UUID, playerOID: UUID? = nil) {
        self.id = id
        self.$playerX.id = playerXID
        self.$playerO.id = playerOID
        self.board = "         "
        self.isFinished = false
        self.currentPlayerID = playerXID
    }
}
