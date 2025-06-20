import Fluent
import struct Foundation.UUID

/// Property wrappers interact poorly with `Sendable` checking, causing a warning for the `@ID` property
/// It is recommended you write your model with sendability checking on and then suppress the warning
/// afterwards with `@unchecked Sendable`.
final class User: Model, @unchecked Sendable, ModelSessionAuthenticatable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "passwordHash")
    var passwordHash: String
    
    @Field(key: "isAdmin")
    var isAdmin: Bool
    
    @Field(key: "wins")
    var wins: Int
    
    @Field(key: "losses")
    var losses: Int
    
    init() { }

    init(id: UUID? = nil, username: String, passwordHash: String) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
        self.isAdmin = false
        self.wins = 0
        self.losses = 0
    }
}
