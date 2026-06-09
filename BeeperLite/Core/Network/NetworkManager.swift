import Foundation

enum NetworkError: Error {
    case invalidURL
    case matrixError(MatrixErrorResponse)
    case httpError(Int)
    case decodingError(Error)
    case unknown
}

actor NetworkManager {
    static let shared = NetworkManager()
    
    // Serveur Matrix de Beeper
    private let baseURL = "https://matrix.beeper.com/_matrix/client/v3"
    
    // Le décodeur est configuré pour être le plus tolérant possible
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Handle dates using standard Matrix format (milliseconds)
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
    
    private init() {}
    
    /// Effectue une requête POST vers un endpoint Matrix
    private func post<T: Codable, U: Codable>(endpoint: String, body: T) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            do {
                return try decoder.decode(U.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("NetworkManager [POST] Error response (\(httpResponse.statusCode)): \(errorString)")
            }
            // Tentative de décodage de l'erreur Matrix standard
            if let matrixError = try? decoder.decode(MatrixErrorResponse.self, from: data) {
                throw NetworkError.matrixError(matrixError)
            } else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        }
    }
    
    // MARK: - Generic GET
    
    private func get<U: Codable>(endpoint: String, token: String) async throws -> U {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if endpoint.contains("/sync") {
            if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = docsURL.appendingPathComponent("beeper_sync.json")
                if let jsonString = String(data: data, encoding: .utf8) {
                    try? jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
                    print("DEBUG: Sync response saved to \(fileURL.path)")
                }
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            do {
                return try decoder.decode(U.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("NetworkManager [GET] Error response (\(httpResponse.statusCode)): \(errorString)")
            }
            if let matrixError = try? decoder.decode(MatrixErrorResponse.self, from: data) {
                throw NetworkError.matrixError(matrixError)
            } else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        }
    }
    
    // MARK: - Authentication
    
    /// Authentifie l'utilisateur via mot de passe classique
    func login(username: String, password: String) async throws -> MatrixLoginResponse {
        let identifier = LoginIdentifier(type: "m.id.user", user: username)
        let loginRequest = MatrixLoginRequest(
            type: "m.login.password",
            identifier: identifier,
            password: password,
            initialDeviceDisplayName: "BeeperLite iOS"
        )
        
        // Endpoint Matrix de login
        let response: MatrixLoginResponse = try await post(endpoint: "/login", body: loginRequest)
        
        return response
    }
    
    // MARK: - Sync
    
    func sync(token: String, since: String? = nil) async throws -> MatrixSyncResponse {
        // Long polling timeout 30s
        var endpoint = "/sync?timeout=30000"
        if let since = since {
            endpoint += "&since=\(since)"
        }
        
        return try await get(endpoint: endpoint, token: token)
    }
    
    /// Envoie un message textuel à une room Matrix donnée
    func sendMessage(token: String, roomId: String, text: String) async throws -> String {
        // ID de transaction unique pour éviter les doublons
        let txnId = UUID().uuidString
        let content = MatrixMessageContent(msgtype: "m.text", body: text)
        
        // En Matrix, l'envoi de message se fait via PUT avec un transaction ID
        guard let url = URL(string: baseURL + "/rooms/\(URLEncoder.encode(roomId))/send/m.room.message/\(txnId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(content)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            struct SendResponse: Codable {
                let eventId: String
                enum CodingKeys: String, CodingKey {
                    case eventId = "event_id"
                }
            }
            let res = try decoder.decode(SendResponse.self, from: data)
            return res.eventId
        } else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("NetworkManager [sendMessage] Error response (\(httpResponse.statusCode)): \(errorString)")
            }
            if let matrixError = try? decoder.decode(MatrixErrorResponse.self, from: data) {
                throw NetworkError.matrixError(matrixError)
            } else {
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        }
    }
}

struct MatrixMessageContent: Codable {
    let msgtype: String
    let body: String
}

// Helper simple pour encoder l'URL en cas d'identifiant contenant des caractères spéciaux
private struct URLEncoder {
    static func encode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? string
    }
}

