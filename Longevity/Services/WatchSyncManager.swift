import Foundation
import WatchConnectivity

// MARK: - Sync Message Types

enum SyncMessageType: String, Codable {
    case readinessScore
    case glucoseReading
    case hrvUpdate
    case experimentReminder
    case supplementReminder
    case zone2Alert
    case fullSync
    case requestSync
}

struct SyncMessage: Codable {
    let type: SyncMessageType
    let timestamp: Date
    let payload: Data
    
    init<T: Codable>(type: SyncMessageType, payload: T) throws {
        self.type = type
        self.timestamp = Date()
        self.payload = try JSONEncoder().encode(payload)
    }
    
    func decode<T: Codable>(_ type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: payload)
    }
}

// MARK: - Payload Types

struct ReadinessPayload: Codable {
    let score: Int
    let factors: [String: Int] // factor name -> contribution
    let timestamp: Date
}

struct GlucosePayload: Codable {
    let value: Double
    let trend: String // up, down, stable
    let timestamp: Date
}

struct Zone2Payload: Codable {
    let currentHR: Double
    let zone2Min: Double
    let zone2Max: Double
    let isInZone: Bool
    let duration: TimeInterval // seconds in Zone 2
}

struct SupplementReminderPayload: Codable {
    let supplementId: UUID
    let supplementName: String
    let dosage: String
    let scheduledTime: Date
}

struct ExperimentReminderPayload: Codable {
    let experimentId: UUID
    let experimentName: String
    let metricsToLog: [String]
    let phase: String
}

// MARK: - Watch Sync Manager (iPhone Side)

class WatchSyncManager: NSObject, ObservableObject {
    static let shared = WatchSyncManager()
    
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var lastSyncTime: Date?
    @Published var pendingMessages: [SyncMessage] = []
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        #if !os(watchOS)
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        #endif
    }
    
    // MARK: - Send Methods
    
    func sendReadinessScore(_ score: Int, factors: [String: Int]) {
        let payload = ReadinessPayload(score: score, factors: factors, timestamp: Date())
        sendMessage(type: .readinessScore, payload: payload)
    }
    
    func sendGlucoseReading(_ value: Double, trend: String) {
        let payload = GlucosePayload(value: value, trend: trend, timestamp: Date())
        sendMessage(type: .glucoseReading, payload: payload)
    }
    
    func sendZone2Update(currentHR: Double, zone2Min: Double, zone2Max: Double, duration: TimeInterval) {
        let isInZone = currentHR >= zone2Min && currentHR <= zone2Max
        let payload = Zone2Payload(
            currentHR: currentHR,
            zone2Min: zone2Min,
            zone2Max: zone2Max,
            isInZone: isInZone,
            duration: duration
        )
        sendMessage(type: .zone2Alert, payload: payload)
    }
    
    func sendSupplementReminder(id: UUID, name: String, dosage: String, time: Date) {
        let payload = SupplementReminderPayload(
            supplementId: id,
            supplementName: name,
            dosage: dosage,
            scheduledTime: time
        )
        sendMessage(type: .supplementReminder, payload: payload)
    }
    
    func sendExperimentReminder(id: UUID, name: String, metrics: [String], phase: String) {
        let payload = ExperimentReminderPayload(
            experimentId: id,
            experimentName: name,
            metricsToLog: metrics,
            phase: phase
        )
        sendMessage(type: .experimentReminder, payload: payload)
    }
    
    func requestFullSync() {
        guard let session = session, session.isReachable else {
            // Queue for later
            return
        }
        
        do {
            let message = try SyncMessage(type: .requestSync, payload: Date())
            let data = try JSONEncoder().encode(message)
            session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        } catch {
            print("Failed to request sync: \(error)")
        }
    }
    
    // MARK: - Private Send
    
    private func sendMessage<T: Codable>(type: SyncMessageType, payload: T) {
        guard let session = session else { return }
        
        do {
            let message = try SyncMessage(type: type, payload: payload)
            let data = try JSONEncoder().encode(message)
            
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil) { error in
                    print("Send error: \(error)")
                }
            } else {
                // Use application context for non-urgent updates
                try session.updateApplicationContext(["latestMessage": data])
            }
        } catch {
            print("Failed to send message: \(error)")
        }
    }
    
    // MARK: - Complication Updates
    
    func updateComplication(score: Int) {
        #if !os(watchOS)
        guard let session = session, session.isComplicationEnabled else { return }
        
        let transferData = ["readinessScore": score]
        
        if session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(transferData)
        }
        #endif
    }
}

// MARK: - WCSession Delegate

extension WatchSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            #if !os(watchOS)
            self.isPaired = session.isPaired
            #endif
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    #if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle inactive
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        handleReceivedData(messageData)
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        handleReceivedData(messageData)
        
        // Send acknowledgement
        if let response = "OK".data(using: .utf8) {
            replyHandler(response)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let data = applicationContext["latestMessage"] as? Data {
            handleReceivedData(data)
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(SyncMessage.self, from: data)
            
            DispatchQueue.main.async {
                self.lastSyncTime = Date()
                self.processMessage(message)
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func processMessage(_ message: SyncMessage) {
        switch message.type {
        case .readinessScore:
            // Watch received new score - update complications
            if let payload = try? message.decode(ReadinessPayload.self) {
                NotificationCenter.default.post(
                    name: .readinessScoreUpdated,
                    object: nil,
                    userInfo: ["score": payload.score, "factors": payload.factors]
                )
            }
            
        case .glucoseReading:
            if let payload = try? message.decode(GlucosePayload.self) {
                NotificationCenter.default.post(
                    name: .glucoseReadingReceived,
                    object: nil,
                    userInfo: ["value": payload.value, "trend": payload.trend]
                )
            }
            
        case .zone2Alert:
            if let payload = try? message.decode(Zone2Payload.self) {
                NotificationCenter.default.post(
                    name: .zone2StatusUpdated,
                    object: nil,
                    userInfo: [
                        "isInZone": payload.isInZone,
                        "currentHR": payload.currentHR,
                        "duration": payload.duration
                    ]
                )
            }
            
        case .supplementReminder:
            if let payload = try? message.decode(SupplementReminderPayload.self) {
                NotificationCenter.default.post(
                    name: .supplementReminderReceived,
                    object: nil,
                    userInfo: ["name": payload.supplementName, "dosage": payload.dosage]
                )
            }
            
        case .experimentReminder:
            if let payload = try? message.decode(ExperimentReminderPayload.self) {
                NotificationCenter.default.post(
                    name: .experimentReminderReceived,
                    object: nil,
                    userInfo: ["name": payload.experimentName, "metrics": payload.metricsToLog]
                )
            }
            
        case .requestSync, .fullSync, .hrvUpdate:
            // Handle sync requests
            NotificationCenter.default.post(name: .syncRequested, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let readinessScoreUpdated = Notification.Name("readinessScoreUpdated")
    static let glucoseReadingReceived = Notification.Name("glucoseReadingReceived")
    static let zone2StatusUpdated = Notification.Name("zone2StatusUpdated")
    static let supplementReminderReceived = Notification.Name("supplementReminderReceived")
    static let experimentReminderReceived = Notification.Name("experimentReminderReceived")
    static let syncRequested = Notification.Name("syncRequested")
}
