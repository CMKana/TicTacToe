import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req -> View in
        let currentUser = req.auth.get(User.self)
        return try await req.view.render("index", BaseContext(title: "TicTacToe",
                                                              currentUser: currentUser))
    }
    
    // MARK: - User
    try app.register(collection: UserController())
    
    // MARK: - Room
    try app.register(collection: RoomController())
    
    struct BaseContext: Encodable {
        let title: String
        let currentUser: User?
    }
}
