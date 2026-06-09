import Foundation

struct MatrixSyncResponse: Codable {
    let nextBatch: String
    let rooms: MatrixSyncRooms?
    
    enum CodingKeys: String, CodingKey {
        case nextBatch = "next_batch"
        case rooms
    }
}

struct MatrixSyncRooms: Codable {
    let join: [String: MatrixJoinedRoom]?
}

struct MatrixJoinedRoom: Codable {
    let timeline: MatrixTimeline?
    let state: MatrixState?
}

struct MatrixTimeline: Codable {
    let events: [MatrixEvent]?
}

struct MatrixState: Codable {
    let events: [MatrixEvent]?
}

struct MatrixEvent: Codable {
    let type: String
    let eventId: String?
    let sender: String?
    let stateKey: String?
    let content: MatrixEventContent?
    let originServerTs: Int?
    
    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case sender
        case stateKey = "state_key"
        case content
        case originServerTs = "origin_server_ts"
    }
}

/// Contenu extrêmement tolérant pour absorber les particularités de Matrix et de Beeper
struct MatrixEventContent: Codable {
    // Standard message
    let body: String?
    let msgtype: String?
    let url: String?
    
    // Standard state events (ex: nom de la room, membre)
    let name: String?
    let displayname: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case body, msgtype, url, name, displayname
        case avatarUrl = "avatar_url"
    }
}

