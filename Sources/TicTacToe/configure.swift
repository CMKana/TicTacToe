import NIOSSL
import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor
import LeafKit

public func configure(_ app: Application) async throws {
    // 📁 Public folder access
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // 🧸 Local network
    app.http.server.configuration.hostname = "0.0.0.0"
    
    // 👥 Sessions
    app.middleware.use(app.sessions.middleware)
    app.sessions.use(.memory)
    app.middleware.use(User.sessionAuthenticator())
    
    // 🍃 Leaf
    app.views.use(.leaf)
    
    // 🗄️ Fluent
    let sqliteConfiguration = SQLiteConfiguration(storage: .file(path: "db.sqlite"), enableForeignKeys: true)
    app.databases.use(.sqlite(sqliteConfiguration), as: .sqlite)
    app.migrations.add(CreateUser())
    app.migrations.add(CreateRoom())
    try await app.autoMigrate()
    
    // 🌐 Networking
    try routes(app)
}
