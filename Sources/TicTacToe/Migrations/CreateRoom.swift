import Fluent

struct CreateRoom: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("rooms")
            .id()
            .field("playerX", .uuid)
            .field("playerO", .uuid)
            .field("board", .string, .required)
            .field("isFinished", .bool, .required)
            .field("winner", .uuid)
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("rooms").delete()
    }
}
