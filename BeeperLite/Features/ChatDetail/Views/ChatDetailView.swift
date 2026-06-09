import SwiftUI
import CoreData



struct ChatDetailView: View {
    @ObservedObject var chat: Chat
    let currentUsername: String
    
    @State private var messageText = ""
    @State private var isSending = false
    
    init(chat: Chat, currentUsername: String) {
        self.chat = chat
        self.currentUsername = currentUsername
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Liste des messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(chat.sortedMessages.enumerated()), id: \.element.id) { index, message in
                            MessageBubbleView(
                                message: message,
                                isMe: message.senderId == currentUsername,
                                isGrouped: isGroupedWithPrevious(at: index)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    scrollToLastMessage(proxy: proxy, animated: false)
                }
                .onChange(of: chat.sortedMessages.count) { _ in
                    scrollToLastMessage(proxy: proxy, animated: true)
                }
            }
            
            Divider()
            
            // Zone de saisie (Look épuré Beeper)
            HStack(spacing: 12) {
                TextField("Message", text: $messageText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .disableAutocorrection(false)
                    .autocapitalization(.none)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle(chat.title ?? "Discussion")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper Methods
    
    private func isGroupedWithPrevious(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let current = chat.sortedMessages[index]
        let previous = chat.sortedMessages[index - 1]
        
        // Même expéditeur
        guard current.senderId == previous.senderId else { return false }
        
        // Intervalle de temps inférieur à 5 minutes (300 secondes)
        guard let currentTs = current.timestamp, let previousTs = previous.timestamp else { return false }
        return currentTs.timeIntervalSince(previousTs) < 300
    }
    
    private func scrollToLastMessage(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = chat.sortedMessages.last, let id = lastMessage.id else { return }
        
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
    
    private func sendMessage() {
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        
        messageText = ""
        isSending = true
        
        Task {
            let context = DataStore.shared.context
            
            // 1. Enregistrement local immédiat (Local Echo)
            let tempId = "local_\(UUID().uuidString)"
            let message = Message(context: context)
            message.id = tempId
            message.text = textToSend
            message.senderId = currentUsername
            message.timestamp = Date()
            message.chat = chat
            
            DataStore.shared.saveContext()
            
            do {
                guard let token = try SecureStore.shared.getToken(for: currentUsername) else {
                    print("ChatDetailView: Aucun token trouvé pour \(currentUsername)")
                    isSending = false
                    return
                }
                
                guard let roomId = chat.id else {
                    print("ChatDetailView: ID de chat manquant")
                    isSending = false
                    return
                }
                
                // Envoi à l'API Matrix
                let eventId = try await NetworkManager.shared.sendMessage(token: token, roomId: roomId, text: textToSend)
                
                // 2. Remplacer l'ID temporaire par le vrai eventId retourné par le serveur
                await MainActor.run {
                    message.id = eventId
                    DataStore.shared.saveContext()
                }
            } catch {
                print("ChatDetailView: Erreur lors de l'envoi du message: \(error)")
                // Note: En production, on pourrait ajouter un état d'erreur visuel sur la bulle
            }
            
            isSending = false
        }
    }
}

// MARK: - Message Bubble Component

struct MessageBubbleView: View {
    let message: Message
    let isMe: Bool
    let isGrouped: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Affichage de l'avatar à gauche pour les autres (si non groupé)
            if !isMe {
                if !isGrouped {
                    Circle()
                        .fill(avatarColor(for: message.senderId ?? ""))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(message.senderId?.dropFirst().prefix(1) ?? "?").uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                } else {
                    // Espace réservé pour l'alignement
                    Spacer()
                        .frame(width: 32, height: 32)
                }
            }
            
            if isMe {
                Spacer()
            }
            
            // Bulle du message
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                // Nom de l'expéditeur si non groupé et que ce n'est pas moi
                if !isMe && !isGrouped {
                    Text(cleanSenderId(message.senderId ?? ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .padding(.bottom, 2)
                }
                
                Text(message.text ?? "")
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isMe ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(isMe ? .white : .primary)
                    .clipShape(BubbleShape(isMe: isMe, isGrouped: isGrouped))
            }
            
            if !isMe {
                Spacer()
            }
        }
        .padding(.top, isGrouped ? 2 : 8)
    }
    
    // MARK: - UI Helpers
    
    private func avatarColor(for senderId: String) -> Color {
        let hash = abs(senderId.hashValue)
        let colors: [Color] = [.blue, .purple, .pink, .orange, .red, .green, .indigo, .teal]
        return colors[hash % colors.count]
    }
    
    private func cleanSenderId(_ senderId: String) -> String {
        // Enlève le @ et le nom de domaine :beeper.com
        var clean = senderId
        if clean.hasPrefix("@") {
            clean.removeFirst()
        }
        if let colonIndex = clean.firstIndex(of: ":") {
            clean = String(clean[..<colonIndex])
        }
        return clean
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isMe: Bool
    let isGrouped: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: cornersToRound(),
            cornerRadii: CGSize(width: 16, height: 16)
        )
        return Path(path.cgPath)
    }
    
    private func cornersToRound() -> UIRectCorner {
        if isMe {
            if isGrouped {
                return [.topLeft, .bottomLeft, .topRight, .bottomRight]
            } else {
                // Bulle finale (en bas) ou isolée : coin pointu en bas à droite
                return [.topLeft, .bottomLeft, .topRight]
            }
        } else {
            if isGrouped {
                return [.topLeft, .bottomLeft, .topRight, .bottomRight]
            } else {
                // Coin pointu en bas à gauche
                return [.topLeft, .topRight, .bottomRight]
            }
        }
    }
}
