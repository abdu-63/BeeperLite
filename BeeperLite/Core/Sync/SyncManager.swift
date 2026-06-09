import Foundation
import CoreData
import Combine

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var syncError: String? = nil
    private var currentBatch: String?
    
    private init() {
        // En vrai, il faudrait récupérer le dernier batch stocké dans CoreData ou UserDefaults
        currentBatch = UserDefaults.standard.string(forKey: "MatrixSyncNextBatch")
    }
    
    func startSyncing(username: String) {
        guard !isSyncing else { return }
        isSyncing = true
        
        Task {
            // Boucle infinie de long-polling (stoppée si l'app meurt ou si on se déco)
            while isSyncing {
                do {
                    // On récupère le token
                    guard let token = try? SecureStore.shared.getToken(for: username) else {
                        print("SyncManager: Aucun token trouvé.")
                        isSyncing = false
                        break
                    }
                    
                    print("SyncManager: Démarrage de la requête de sync (batch: \(currentBatch ?? "initial"))...")
                    let response = try await NetworkManager.shared.sync(token: token, since: currentBatch)
                    
                    // On met à jour le batch
                    currentBatch = response.nextBatch
                    UserDefaults.standard.set(currentBatch, forKey: "MatrixSyncNextBatch")
                    
                    // Réinitialiser l'erreur en cas de succès
                    await MainActor.run {
                        self.syncError = nil
                    }
                    
                    // Traitement de la réponse pour l'insérer dans CoreData
                    await processSyncResponse(response, username: username)
                    
                } catch {
                    print("SyncManager: Erreur de synchronisation: \(error)")
                    await MainActor.run {
                        self.syncError = "Erreur de sync: \(error.localizedDescription)"
                    }
                    // Attente de 5 secondes avant de réessayer (backoff)
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }
    
    func stopSyncing() {
        isSyncing = false
    }
    
    private func processSyncResponse(_ response: MatrixSyncResponse, username: String) async {
        guard let joinedRooms = response.rooms?.join else { return }
        
        // Exécuter l'insertion sur le thread de fond via performBackgroundTask
        await DataStore.shared.container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            for (roomId, roomData) in joinedRooms {
                // 1. Trouver ou créer le Chat
                let chatFetch: NSFetchRequest<Chat> = Chat.fetchRequest()
                chatFetch.predicate = NSPredicate(format: "id == %@", roomId)
                
                let chat: Chat
                if let existingChat = try? context.fetch(chatFetch).first {
                    chat = existingChat
                } else {
                    chat = Chat(context: context)
                    chat.id = roomId
                    chat.unreadCount = 0
                }
                
                // Collecter tous les événements d'état de "state" et "timeline"
                var stateEvents: [MatrixEvent] = []
                if let events = roomData.state?.events {
                    stateEvents.append(contentsOf: events)
                }
                if let events = roomData.timeline?.events {
                    // Les événements d'état dans la timeline ont généralement un stateKey non nul
                    stateEvents.append(contentsOf: events.filter { $0.stateKey != nil })
                }
                
                var roomName: String? = nil
                var memberNames: [String] = []
                
                for event in stateEvents {
                    if event.type == "m.room.name", let name = event.content?.name {
                        roomName = name
                    } else if event.type == "m.room.member",
                              let displayname = event.content?.displayname,
                              event.stateKey != username {
                        memberNames.append(displayname)
                    }
                }
                
                // Assigner le titre de la discussion
                if let name = roomName {
                    chat.title = name
                } else if !memberNames.isEmpty {
                    chat.title = memberNames.joined(separator: ", ")
                } else if chat.title == nil {
                    chat.title = "Discussion (\(roomId.prefix(6)))"
                }
                
                // 2. Traiter les messages de la timeline (y compris cryptés)
                if let timelineEvents = roomData.timeline?.events {
                    for event in timelineEvents {
                        // On parse les messages normaux et les messages cryptés
                        guard event.type == "m.room.message" || event.type == "m.room.encrypted" else { continue }
                        guard let eventId = event.eventId else { continue }
                        
                        var body: String
                        if event.type == "m.room.encrypted" {
                            body = "🔒 Message chiffré"
                        } else {
                            body = event.content?.body ?? ""
                            // Filtrer le fallback envoyé par Matrix pour les vieux clients
                            if body.hasPrefix("This is an encrypted chat") {
                                body = "🔒 Message chiffré"
                            }
                        }
                        
                        // Vérifier si le message existe déjà
                        let msgFetch: NSFetchRequest<Message> = Message.fetchRequest()
                        msgFetch.predicate = NSPredicate(format: "id == %@", eventId)
                        
                        if (try? context.fetch(msgFetch).first) == nil {
                            let message = Message(context: context)
                            message.id = eventId
                            message.text = body
                            message.senderId = event.sender
                            if let ts = event.originServerTs {
                                message.timestamp = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
                            } else {
                                message.timestamp = Date()
                            }
                            message.chat = chat
                        }
                    }
                }
            }
            
            // Sauvegarder le contexte
            if context.hasChanges {
                do {
                    try context.save()
                    print("SyncManager: CoreData mis à jour avec le nouveau batch.")
                } catch {
                    print("SyncManager: Erreur de sauvegarde CoreData: \(error)")
                }
            }
        }
    }
}
