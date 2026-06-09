import SwiftUI
import CoreData

struct ChatListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // On demande à CoreData de nous donner tous les chats
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.id, ascending: true)],
        animation: .default)
    private var chats: FetchedResults<Chat>
    
    let username: String // Passé depuis le ContentView
    
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""
    
    @ObservedObject private var syncManager = SyncManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = syncManager.syncError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
            }
            
            List {
                ForEach(chats) { chat in
                    NavigationLink(destination: ChatDetailView(chat: chat, currentUsername: username)) {
                        ChatRowView(chat: chat)
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("Discussions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Déconnexion") {
                    logout()
                }
                .foregroundColor(.red)
            }
        }
        .onAppear {
            // Lancement de la synchronisation en arrière-plan lorsqu'on arrive sur cette vue
            SyncManager.shared.startSyncing(username: username)
        }
    }
    
    private func logout() {
        // Stopper la synchro
        // SyncManager.shared.stopSyncing() // (Optionnel si implémenté)
        
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
        
        // Rediriger vers l'écran de login
        self.loggedInUsername = ""
    }
}

struct ChatRowView: View {
    @ObservedObject var chat: Chat
    
    var body: some View {
        let chatTitle = chat.title ?? "Chat Inconnu"
        
        HStack(spacing: 16) {
            // Avatar avec Badge ZStack (le "Beeper Look")
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(colorFor(title: chatTitle))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(chatTitle.prefix(1)).uppercased())
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    )
                
                // Petit badge (Placeholder pour l'icône WhatsApp/iMessage)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "bubble.left.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.white)
                    )
                    .offset(x: 2, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chatTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(chat.lastMessageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                if let lastDate = chat.lastMessageDate {
                    Text(formatDate(lastDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if chat.unreadCount > 0 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(chat.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                } else {
                    // Placeholder pour l'alignement
                    Spacer().frame(height: 24)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Génère une couleur déterministe basée sur le nom
    private func colorFor(title: String) -> Color {
        let hash = abs(title.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    // Formate la date ("Hier", "14:32", etc.)
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Hier"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - CoreData Extensions

extension Chat {
    var sortedMessages: [Message] {
        let set = messages as? Set<Message> ?? []
        return set.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    var lastMessageText: String {
        return sortedMessages.last?.text ?? "Aucun message"
    }
    
    var lastMessageDate: Date? {
        return sortedMessages.last?.timestamp
    }
}

