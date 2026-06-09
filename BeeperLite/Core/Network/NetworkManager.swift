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
            // Tentative de décodage de l'erreur Matrix standard
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
        
        // Stockage sécurisé du token de session à intégrer ici (SecureStore)
        // Task { await SecureStore.shared.save(token: response.accessToken) }
        
        return response
    }
}
