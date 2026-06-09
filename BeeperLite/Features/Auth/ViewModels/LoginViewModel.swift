import Foundation
import Combine
import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""
    
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Si le login réussit, cette variable passera à true pour déclencher la navigation
    @Published var isLoggedIn = false
    
    func login() async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Veuillez remplir tous les champs."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let finalUsername = normalizeUsername(username)
        print("LoginViewModel: Tentative de connexion pour \(finalUsername)")
        
        do {
            let response = try await NetworkManager.shared.login(username: finalUsername, password: password)
            // Stocker le token d'accès Matrix dans le Keychain sécurisé
            try SecureStore.shared.save(token: response.accessToken, for: finalUsername)
            
            // Mettre à jour l'username avec sa version normalisée pour la suite
            self.username = finalUsername
            
            // Succès: on stocke le nom d'utilisateur dans AppStorage pour déclencher la navigation dans ContentView
            self.loggedInUsername = finalUsername
            isLoggedIn = true
        } catch NetworkError.matrixError(let matrixErr) {
            errorMessage = "Erreur Serveur: \(matrixErr.error) (\(matrixErr.errcode))"
        } catch {
            errorMessage = "Impossible de se connecter. Vérifiez vos identifiants."
        }
        
        isLoading = false
    }
    
    func logout() {
        // Supprimer le token du Keychain
        do {
            try SecureStore.shared.deleteToken(for: username)
        } catch {
            print("Erreur lors de la suppression du token: \(error)")
        }
        
        // Supprimer le curseur de synchronisation
        UserDefaults.standard.removeObject(forKey: "MatrixSyncNextBatch")
        
        // Effacer la base de données
        DataStore.shared.clearAllData()
        
        // Réinitialiser l'état
        self.loggedInUsername = ""
        self.isLoggedIn = false
        self.password = ""
    }
    
    private func normalizeUsername(_ input: String) -> String {
        var clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "" }
        
        // Si c'est déjà au format @localpart:domain, on le laisse tel quel
        if clean.hasPrefix("@") && clean.contains(":") {
            return clean
        }
        
        // Si l'utilisateur a entré une adresse email ou a confondu @ et :
        // ex: abdu@beeper.com -> @abdu:beeper.com
        if clean.contains("@") && !clean.hasPrefix("@") {
            let components = clean.components(separatedBy: "@")
            if components.count == 2 {
                return "@\(components[0]):\(components[1])"
            }
        }
        
        // Retirer le @ initial s'il existe pour normaliser proprement
        if clean.hasPrefix("@") {
            clean.removeFirst()
        }
        
        // Si contient un : mais pas de @ au début (ex: abdu:beeper.com)
        if clean.contains(":") {
            return "@\(clean)"
        }
        
        // Sinon, c'est le localpart seul, on ajoute @ et :beeper.com par défaut
        return "@\(clean):beeper.com"
    }
}
