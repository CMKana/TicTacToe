import Fluent
import Foundation.NSDate
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class Room: Model, @unchecked Sendable, ModelSessionAuthenticatable {
    static let schema = "rooms"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "playerX")
    var playerX: UUID?
    
    @Field(key: "playerO")
    var playerO: UUID?
    
    @Field(key: "board")
    var board: String

    @Field(key: "isFinished")
    var isFinished: Bool
    
    @Field(key: "winner")
    var winner: UUID?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, playerX: UUID?, playerO: UUID? = nil, board: String = "         ", isFinished: Bool = false, winner: UUID? = nil) {
        self.id = id
        self.playerX = playerX
        self.playerO = playerO
        self.board = board
        self.isFinished = isFinished
        self.winner = winner
    }
}
