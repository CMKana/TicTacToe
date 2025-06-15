import Vapor
import LeafKit
import Fluent
import Crypto

struct RegisterForm: Content {
    let username: String
    let password: String
}

struct LoginForm: Content {
    let username: String
    let password: String
}

struct DeleteForm: Content {
    let username: String
    let password: String
}

struct AdminForm: Content {
    let username: String
    let password: String
    let adminKey: String
}

let adminKey = "678052"

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("register", use: registerForm)
        routes.post("register", use: registerUser)
        
        routes.get("login", use: loginForm)
        routes.post("login", use: loginUser)
        
        routes.get("logout", use: logoutForm)
        routes.post("logout", use: logoutUser)
        
        routes.get("delete-account", use: deleteForm)
        routes.post("delete-account", use: deleteUser)
        
        routes.get("users", use: listUsers)
        
        routes.get(":user", use: user)
        
        routes.get("admin", use: adminForm)
        routes.post("admin", use: adminUser)
        
        routes.post("users", ":userID", "delete", use: adminDeleteUser)
    }

    // MARK: - register
    func registerForm(req: Request) throws -> EventLoopFuture<View> {
        guard req.auth.get(User.self) == nil else {
            return req.eventLoop.future(error: Abort(.forbidden))
        }
        return req.view.render("register", BaseContext(title: "Register",
                                                       currentUser: nil))
    }

    func registerUser(req: Request) throws -> EventLoopFuture<Response> {
        let data = try req.content.decode(RegisterForm.self)

        return User.query(on: req.db)
            .filter(\.$username == data.username)
            .first()
            .flatMap { existing in
                guard existing == nil else {
                    return req.eventLoop.makeSucceededFuture(req.redirect(to: "/register"))
                }

                let passwordHash = SHA256.hash(data.password)
                let currentUser = User(username: data.username, passwordHash: passwordHash)

                return currentUser.save(on: req.db).map {
                    req.auth.login(currentUser)
                    return req.redirect(to: "/users")
                }
            }
    }
    
    // MARK: - login
    func loginForm(req: Request) throws -> EventLoopFuture<View> {
        guard req.auth.get(User.self) == nil else {
            return req.eventLoop.future(error: Abort(.forbidden))
        }
        return req.view.render("login", BaseContext(title: "Login",
                                                    currentUser: nil))
    }
    
    func loginUser(req: Request) async throws -> Response {
        let form = try req.content.decode(LoginForm.self)
        
        guard
            let currentUser = try await User.query(on: req.db)
                .filter(\.$username == form.username)
                .first(),
            currentUser.passwordHash == SHA256.hash(form.password)
        else {
            return req.redirect(to: "/login")
        }
        
        req.auth.login(currentUser)
        return req.redirect(to: "/users")
    }
    
    // MARK: - logout
    func logoutForm(req: Request) throws -> EventLoopFuture<View> {
        guard req.auth.get(User.self) != nil else {
            return req.eventLoop.future(error: Abort(.forbidden))
        }
        return req.view.render("logout", BaseContext(title: "Logging out",
                                                     currentUser: nil))
    }
    
    func logoutUser(req: Request) throws -> Response {
        req.auth.logout(User.self)
        return req.redirect(to: "/users")
    }
    
    // MARK: - delete
    func deleteForm(req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = req.auth.get(User.self) else {
            return req.eventLoop.future(error: Abort(.unauthorized))
        }
        return req.view.render("delete-account", BaseContext(title: "Delete Account",
                                                             currentUser: currentUser))
    }
    
    func deleteUser(req: Request) async throws -> Response {
        guard let currentUser = req.auth.get(User.self) else {
            return req.redirect(to: "/users")
        }
        
        let form = try req.content.decode(DeleteForm.self)
        guard
            currentUser.username == form.username,
            currentUser.passwordHash == SHA256.hash(form.password)
        else {
            return req.redirect(to: "/delete-account")
        }
        
        try await currentUser.delete(on: req.db)
        req.auth.logout(User.self)
        
        return req.redirect(to: "/users")
    }
    
    // MARK: - list
    func listUsers(req: Request) async throws -> View {
        let currentUser = req.auth.get(User.self)
        let users = try await User.query(on: req.db).all()
        return try await req.view.render("users",
                                         UsersContext(title: "All Users",
                                                      currentUser: currentUser,
                                                      users: users))
    }
    
    // MARK: - user
    func user(req: Request) async throws -> View {
        let currentUser = req.auth.get(User.self)
        
        guard
            let seekUsername = req.parameters.get("user", as: String.self) else {
            throw Abort(.badRequest)
        }
        
        guard
            let seekUser = try await User.query(on: req.db)
                .filter(\.$username == seekUsername)
                .first()
        else {
            throw Abort(.notFound)
        }
        
        return try await req.view.render("user",
                                         UserContext(title: "User: \(seekUser.username)",
                                                     currentUser: currentUser,
                                                     user: seekUser))
    }
    
    // MARK: - admin
    func adminForm(req: Request) throws -> EventLoopFuture<View> {
        guard let currentUser = req.auth.get(User.self) else {
            return req.eventLoop.future(error: Abort(.unauthorized))
        }
        return req.view.render("admin", BaseContext(title: "Admin",
                                                    currentUser: currentUser))
    }
    
    func adminUser(req: Request) async throws -> Response {
        guard let currentUser = req.auth.get(User.self) else {
            return req.redirect(to: "/users")
        }
        
        let form = try req.content.decode(AdminForm.self)
        guard
            currentUser.username == form.username,
            currentUser.passwordHash == SHA256.hash(form.password),
            form.adminKey == adminKey
        else {
            return req.redirect(to: "/admin")
        }
        
        currentUser.isAdmin = true
        try await currentUser.update(on: req.db)
        
        return req.redirect(to: "/users")
    }
    
    // MARK: - admin delete
    func adminDeleteUser(req: Request) async throws -> Response {
        guard let admin = req.auth.get(User.self),
              admin.isAdmin
        else {
            throw Abort(.forbidden, reason: "Not admin")
        }
        
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.notFound, reason: "No id found in db")
        }
        
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.conflict, reason: "No user found but id was found")
        }
        
        try await user.delete(on: req.db)
        return req.redirect(to: "/users")
    }
}

extension SHA256 {
    static func hash(_ string: String) -> String {
        let digest = Crypto.SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

struct UserViewData {
    let username: String
}

struct BaseContext: Encodable {
    let title: String
    let currentUser: User?
}

struct UsersContext: Encodable {
    let title: String
    let currentUser: User?
    
    let users: [User]
}

struct UserContext: Encodable {
    let title: String
    let currentUser: User?
    
    let user: User
}
