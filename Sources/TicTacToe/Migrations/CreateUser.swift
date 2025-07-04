import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .id()
            .field("username", .string, .required)
            .field("passwordHash", .string, .required)
            .field("isAdmin", .bool, .required, .sql(.default("false")))
            .field("wins", .int8, .sql(.default(0)))
            .field("losses", .int8, .sql(.default(0)))
            .unique(on: "username")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
    }
}
