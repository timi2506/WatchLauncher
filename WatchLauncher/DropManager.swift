import SwiftUI
import WatchConnectivity
import Combine
import AVFoundation

var audioPlayer: AVAudioPlayer?

func playNotificationSound() {
    if let url = Bundle.main.url(forResource: "drop", withExtension: "mp3") {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error)")
        }
    }
}

class DropManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = DropManager()
    
    @Published var onMessageReceive: ((String) -> Void)? = nil
    
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
        
        let messageDict = ["message": message]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message:", error.localizedDescription)
            }
        } else {
            // fallback: send as background transfer
            WCSession.default.transferUserInfo(messageDict)
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
                playNotificationSound()
                self.onMessageReceive?(msg)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let msg = userInfo["message"] as? String {
            DispatchQueue.main.async {
                playNotificationSound()
                self.onMessageReceive?(msg)
            }
        }
    }
}
