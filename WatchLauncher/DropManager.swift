import SwiftUI
import WatchConnectivity
import Combine
import AVFoundation

var audioPlayer: AVAudioPlayer?

func playNotificationSound() {
    if UserDefaults.standard.bool(forKey: "playDropSound") {
        if let url = Bundle.main.url(forResource: "drop", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
            } catch {
                print("Error playing sound: \(error)")
            }
        }
    }
}

class DropManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = DropManager()
    
    @Published var onMessageReceive: ((String) -> Void)? = nil
    @Published var logs: [DropLog] = []
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func send(_ message: String) {
#if os(iOS)
        guard WCSession.default.isPaired || WCSession.default.isWatchAppInstalled else {
            print("WCSession not ready")
            return
        }
#endif
        var occuredError: Error?
        let messageDict = ["message": message]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message:", error.localizedDescription)
                occuredError = error
            }
            logDrop(message, received: false, session: WCSession.default, userInfoUsed: false, error: occuredError)
        } else {
            // fallback: send as background transfer
            WCSession.default.transferUserInfo(messageDict)
            logDrop(message, received: false, session: WCSession.default, userInfoUsed: true, error: nil)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }
    
#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
#endif
    
    // Receiving messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let msg = message["message"] as? String {
            DispatchQueue.main.async {
                self.logDrop(msg, received: true, session: session, userInfoUsed: false, error: nil)
                self.onMessageReceive?(msg)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let msg = userInfo["message"] as? String {
            DispatchQueue.main.async {
                self.logDrop(msg, received: true, session: session, userInfoUsed: true, error: nil)
                self.onMessageReceive?(msg)
            }
        }
    }
    
    func logDrop(_ dropContent: String, received: Bool, session: WCSession, userInfoUsed: Bool, error: Error?) {
        logs.append(.init(received: received, content: dropContent, wasReachable: session.isReachable, activationState: session.activationState, usedUserInfoInsteadOfSendMessage: userInfoUsed))
    }
}

struct DropLog: Identifiable {
    var id = UUID()
    var received: Bool
    var content: String
    var date = Date()
    var wasReachable: Bool?
    var activationState: WCSessionActivationState?
    var usedUserInfoInsteadOfSendMessage: Bool
    var error: Error?
}

extension WCSessionActivationState {
    var text: String {
        switch self {case .notActivated:
                "Not Activated"
            case .inactive:
                "Inactive"
            case .activated:
                "Activated"
            @unknown default:
                "Unknown"
        }
    }
}
