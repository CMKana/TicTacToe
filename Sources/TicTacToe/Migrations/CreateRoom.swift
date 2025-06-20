import Fluent

struct CreateRoom: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("rooms")
            .id()
            .field("playerX", .uuid, .required, .references("users", "id"))
            .field("playerO", .uuid, .references("users", "id"))
            .field("board", .string, .required)
            .field("isFinished", .bool, .required)
            .field("currentPlayerID", .uuid, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("rooms").delete()
    }
}
