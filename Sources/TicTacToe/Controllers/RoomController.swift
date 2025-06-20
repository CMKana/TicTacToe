import Vapor
import LeafKit
import Fluent

struct CreateForm: Content {
    let playerO: String?
}

struct RoomController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("create", use: createForm)
        routes.post("create", use: createRoom)
        
        routes.get("rooms", use: listRooms)
        routes.get("rooms", ":id", use: listRoom)
        
        routes.post("rooms", ":roomID", "delete", use: adminDeleteRoom)
        
        routes.webSocket("ws", "rooms", ":id", onUpgrade: wsGameRoom)
    }
    
    // MARK: - CREATE
    func createForm(req: Request) async throws -> View {
        guard let currentUser = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        let users = try await User.query(on: req.db).all().filter { $0.id != currentUser.id }
        
        return try await req.view.render("create", CreateContext(title: "Create Room",
                                                                 currentUser: currentUser,
                                                                 users: users))
    }
    
    func createRoom(req: Request) async throws -> Response {
        guard let user = req.auth.get(User.self) else {
            return req.redirect(to: "/login")
        }
        
        let form = try req.content.decode(CreateForm.self)
        
        var invitedPlayer: UUID? {
            return if let playerO = form.playerO, !playerO.isEmpty {
                UUID(uuidString: playerO)
            } else {
                nil
            }
        }
        
        let room = Room(
            playerXID: user.id!,
            playerOID: invitedPlayer
        )
        
        try await room.save(on: req.db)
        return req.redirect(to: "/rooms/\(room.id!)")
    }
    
    // MARK: - LIST
    func listRooms(req: Request) async throws -> View {
        let currentUser = req.auth.get(User.self)
        
        let rooms = try await Room.query(on: req.db)
            .with(\.$playerX)
            .with(\.$playerO)
            .all()
        
        return try await req.view.render("rooms",
                                         RoomsContext(title: "All Rooms",
                                                      currentUser: currentUser,
                                                      rooms: rooms))
    }
    
    func listRoom(req: Request) async throws -> View {
        guard let currentUser = req.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        guard
            let roomID = req.parameters.get("id", as: UUID.self),
            let room = try await Room.query(on: req.db)
                .with(\.$playerX)
                .with(\.$playerO)
                .filter(\.$id == roomID)
                .all()
                .first
        else {
            throw Abort(.notFound)
        }
        
        if room.playerO != nil { // Блок лишних
            if currentUser.id != room.playerX.id && currentUser.id != room.playerO!.id {
                throw Abort(.imATeapot)
            }
        } else { // Зафиксить новых
            if currentUser.id != room.playerX.id {
                room.$playerO.id = currentUser.id
                try await room.save(on: req.db)
            }
        }
        
        let currentTurn = try await User.find(room.currentPlayerID, on: req.db)
        
        return try await req.view.render("room",
                                         RoomContext(title: "Room by: \(room.playerX.username)",
                                                     currentUser: currentUser,
                                                     room: room,
                                                     currentTurn: currentTurn!))
    }
    
    //MARK: - ADMIN DELETE
    func adminDeleteRoom(req: Request) async throws -> Response {
        guard let admin = req.auth.get(User.self),
              admin.isAdmin
        else {
            throw Abort(.forbidden, reason: "Not admin")
        }
        
        guard let roomID = req.parameters.get("roomID", as: UUID.self) else {
            throw Abort(.notFound, reason: "No id found in db")
        }
        
        guard let room = try await Room.find(roomID, on: req.db) else {
            throw Abort(.conflict, reason: "No room found but id was found")
        }
        
        try await room.delete(on: req.db)
        return req.redirect(to: "/rooms")
    }
    
    // MARK: - CONTEXT
    struct BaseContext: Encodable {
        let title: String
        let currentUser: User?
    }
    
    struct CreateContext: Encodable {
        let title: String
        let currentUser: User?
        
        let users: [User]
    }
    
    struct RoomsContext: Encodable {
        let title: String
        let currentUser: User?
        
        let rooms: [Room]
    }
    
    struct CellData: Encodable {
        let index: Int
        let value: String
    }
    
    struct RoomContext: Encodable {
        let title: String
        let currentUser: User?
        let room: Room
        let cells: [CellData]
        let currentTurn: User
        
        init(title: String, currentUser: User?, room: Room, currentTurn: User) {
            self.title = title
            self.currentUser = currentUser
            self.room = room
            
            self.cells = Array(room.board.enumerated()).map { idx, ch in
                CellData(index: idx, value: String(ch))
            }
            
            self.currentTurn = currentTurn
        }
    }
    
    // MARK: - WEB SOCKET
    func wsGameRoom(req: Request, ws: WebSocket) async {
        guard let roomID = req.parameters.get("id", as: UUID.self) else {
            try? await ws.close()
            return
        }
        
        await GameSocketManager.shared.join(roomID: roomID, socket: ws)
        
        ws.onText { ws, text async in
            // Данные комнаты
            guard let move = try? JSONDecoder().decode(MoveMessage.self, from: Data(text.utf8)),
                  let room = try? await Room.find(roomID, on: req.db)
            else {
                return
            }
            
            if room.isFinished {
                return
            }
            
            // Данные о ходе игроков
            guard let currentUser = req.auth.get(User.self),
                  currentUser.id == room.currentPlayerID
            else {
                return
            }
            
            let boardArray = Array(room.board)
            
            if move.index >= 0,
               move.index < 9,
               boardArray[move.index] == " " {
                
                var newBoard = boardArray
                
                let symbol = (currentUser.id == room.$playerX.id) ? "X" : "O"
                newBoard[move.index] = Character(symbol)
                room.board = String(newBoard)
                
                // Смена сторон
                if let playerOID = room.$playerO.id, playerOID != currentUser.id {
                    room.currentPlayerID = playerOID
                } else {
                    room.currentPlayerID = room.$playerX.id
                }
                
                do {
                    try await room.save(on: req.db)
                } catch {
                    print("Failed to save room: \(error)")
                    return
                }
                
                let ws: String? = checkWinner(room.board)
                
                if let winnerSymbol = checkWinner(room.board) {
                    room.isFinished = true
                    try? await room.save(on: req.db)
                    try? await room.delete(on: req.db)
                    
                    let winnerID = (winnerSymbol == "X") ? room.$playerX.id : room.$playerO.id
                    let loserID  = (winnerSymbol == "X") ? room.$playerO.id : room.$playerX.id

                    if let winner = try? await User.find(winnerID, on: req.db) {
                        winner.wins += 1
                        try? await winner.save(on: req.db)
                    }

                    if let loser = try? await User.find(loserID, on: req.db) {
                        loser.losses += 1
                        try? await loser.save(on: req.db)
                    }
                } else if !room.board.contains(" ") {
                    room.isFinished = true
                    try? await room.save(on: req.db)
                    try? await room.delete(on: req.db)
                }
                
                guard
                    let currentTurnUser = try? await User.find(room.currentPlayerID, on: req.db)
                else {
                    return
                }
                
                let playerO: PublicUser?
                if let po = try? await room.$playerO.get(on: req.db) {
                    playerO = PublicUser(id: po.id!, username: po.username)
                } else {
                    playerO = nil
                }
                
                let message = BoardMessage(
                    board: room.board,
                    currentTurn: PublicUser(id: currentTurnUser.id!, username: currentTurnUser.username),
                    playerO: playerO,
                    winner: ws
                )
                
                let updated: Data
                do {
                    updated = try JSONEncoder().encode(message)
                } catch {
                    print("Failed to encode board message: \(error)")
                    return
                }
                await GameSocketManager.shared.broadcast(to: roomID, message: String(data: updated, encoding: .utf8)!)
            }
        }
        
        ws.onClose.whenComplete { _ in
            Task {
                await GameSocketManager.shared.leave(roomID: roomID, socket: ws)
            }
        }
    }
}

// MARK: - WEB SOCKET
actor GameSocketManager {
    static let shared = GameSocketManager()
    private var rooms: [UUID: [WebSocket]] = [:]

    func join(roomID: UUID, socket: WebSocket) {
        rooms[roomID, default: []].append(socket)
    }

    func leave(roomID: UUID, socket: WebSocket) {
        rooms[roomID]?.removeAll(where: { $0 === socket })
    }

    func broadcast(to roomID: UUID, message: String) {
        for socket in rooms[roomID] ?? [] where !socket.isClosed {
            socket.send(message)
        }
    }
}

struct MoveMessage: Codable {
    let index: Int
}

struct BoardMessage: Codable {
    let board: String
    let currentTurn: PublicUser
    let playerO: PublicUser?
    let winner: String?
}

struct PublicUser: Codable {
    let id: UUID
    let username: String
}

// MARK: - CHECK WINNER
func checkWinner(_ board: String) -> String? {
    let wins = [
        [0,1,2], [3,4,5], [6,7,8],
        [0,3,6], [1,4,7], [2,5,8],
        [0,4,8], [2,4,6]
    ]
    
    for line in wins {
        let chars = line.map { board[board.index(board.startIndex, offsetBy: $0)] }
        if chars[0] != " " && chars[0] == chars[1] && chars[1] == chars[2] {
            return String(chars[0])
        }
    }
    
    return nil
}
