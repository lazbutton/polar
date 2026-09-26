import Foundation
#if os(iOS) || os(watchOS)
import WatchConnectivity

struct WatchMoment: Codable {
    var createdAt: Date
    var emotionKey: String
    var intensity: Int
}

@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ moment: WatchMoment) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard let data = try? JSONEncoder().encode(moment) else { return }
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(["moment": data])
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            WatchBridge.store(messageData)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["moment"] as? Data else { return }
        Task { @MainActor in
            WatchBridge.store(data)
        }
    }

    @MainActor
    private static func store(_ data: Data) {
        guard let moment = try? JSONDecoder().decode(WatchMoment.self, from: data) else { return }
        let context = SharedStore.container.mainContext
        let stored = Moment(emotionKey: moment.emotionKey, intensity: moment.intensity, source: "watch")
        stored.createdAt = moment.createdAt
        context.insert(stored)
        try? context.save()
    }
}
#endif
