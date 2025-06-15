import Vapor
import LeafKit
import Fluent

struct RoomController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("rooms", use: listRooms)
        routes.post("rooms", use: createRoom)
        routes.get("rooms", ":id", use: viewRoom)
    }
    
    func listRooms(req: Request) async throws -> View {
        let currentUser = req.auth.get(User.self)
        let rooms = try await Room.query(on: req.db).all()
        return try await req.view.render("rooms", RoomsContext(title: "All Rooms",
                                                               currentUser: currentUser,
                                                               rooms: rooms))
    }
    
    func createRoom(req: Request) async throws -> Response {
        guard let currentUser = req.auth.get(User.self) else {
            return req.redirect(to: "/login")
        }
        
        let room = Room(playerX: currentUser.id)
        try await room.save(on: req.db)
        return req.redirect(to: "/rooms\(room.id!)")
    }
    
    func viewRoom(req: Request) async throws -> View {
        guard
            let id = req.parameters.get("id", as: UUID.self),
            let room = try await Room.find(id, on: req.db)
        else {
            throw Abort(.notFound)
        }
        
        let currentUser = req.auth.get(User.self)
        return try await req.view.render("room", RoomContext(title: "Room",
                                                             currentUser: currentUser,
                                                             room: room))
    }
    
}

struct RoomsContext: Encodable {
    let title: String
    let currentUser: User?
    let rooms: [Room]
}

struct RoomContext: Encodable {
    let title: String
    let currentUser: User?
    let room: Room
}
