//

import Foundation
import WatchConnectivity

final class WatchObserverToken {
    let identifier: UUID
    
    weak var watchSessionConnector: WatchSessionConnector?
    
    init(identifier: UUID, watchSessionConnector: WatchSessionConnector) {
        self.identifier = identifier
        self.watchSessionConnector = watchSessionConnector
    }
    
    deinit {
        self.watchSessionConnector?.removeObserver(with: self)
    }
}

struct MessageObserver {
    let token: WatchObserverToken
    let type: String
    let executionBlock: ([String: Any]) -> Void
}

struct WatchMessageDescriptor<A: WatchMessageType> {
    let type: String
    let convert: ([String: Any]) -> A
    
    init(convert: @escaping ([String: Any]) -> A) {
        self.type = A.type
        self.convert = convert
    }
}

final class WatchSessionConnector: NSObject {
    
    enum Error: Swift.Error {
        case inactiveSession
    }
    
    let watchSession: WCSession
    
    private var pendingWatchMessage: WatchMessageType?
    private var observers: [MessageObserver]
    
    var hasActiveSession: Bool {
        switch self.watchSession.activationState {
        case .activated: return true
        case .inactive, .notActivated: return false
        @unknown default: return false
        }
    }
    
    init(watchSession: WCSession = WCSession.default) {
        self.watchSession = watchSession
        self.observers = []
        
        super.init()
        
        self.configureWatchSession()
        self.activateSession()
    }
    
    private func configureWatchSession() {
        self.watchSession.delegate = self
    }
    
    private func activateSession() {
        guard WCSession.isSupported() else {
            return
        }
        self.watchSession.activate()
    }
    
    func send(watchMessage: WatchMessageType, errorHandler: ((Swift.Error) -> Void)? = nil) throws {
        guard self.hasActiveSession else {
            self.pendingWatchMessage = watchMessage
            
            throw Error.inactiveSession
        }
        
        let payloadDict = self.payloadDict(from: watchMessage)
        self.watchSession.sendMessage(payloadDict, replyHandler: nil) { error in
            errorHandler?(error)
        }
    }
    
    func updateApplicationContext(with watchMessage: WatchMessageType) {
        try? self.watchSession.updateApplicationContext(self.payloadDict(from: watchMessage))
    }
    
    func payloadDict(from watchMessage: WatchMessageType) -> [String : Any] {
        return [WatchMessageContant.type: type(of: watchMessage).type].merging(watchMessage.toDictionary()) { current, _ in current }
    }
    
    func addObserver<A>(descriptor: WatchMessageDescriptor<A>, using block: @escaping (A) -> Void) -> WatchObserverToken {        
        let token = WatchObserverToken(identifier: UUID(), watchSessionConnector: self)
        let observer = MessageObserver(token: token, type: descriptor.type) { messageDict in
            let message = descriptor.convert(messageDict)
            block(message)
        }
        
        self.observers.append(observer)
        
        return observer.token
    }
    
    func removeObserver(with observerToken: WatchObserverToken) {
        self.observers = self.observers.filter { observer in observer.token.identifier != observerToken.identifier }
    }
    
    private func dispatchMessageToObservers(messageDictionary: [String: Any]) {
        self.observers.forEach { observer in
            guard let messageType = messageDictionary[WatchMessageContant.type] as? String else {
                assertionFailure("Received message without type")
                return
            }
            
            // Different type than expected
            guard observer.type == messageType else { return }
            
            DispatchQueue.main.async {
                observer.executionBlock(messageDictionary)
            }
        }
    }
}

extension WatchSessionConnector: WCSessionDelegate {
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    #endif
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Swift.Error?) {
        if let pendingWatchMessage = self.pendingWatchMessage {
            try? self.send(watchMessage: pendingWatchMessage)
        }
        
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.dispatchMessageToObservers(messageDictionary: message)
    }

    @available(watchOS 2.0, *)
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        self.dispatchMessageToObservers(messageDictionary: applicationContext)
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Swift.Error?) {
        
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        self.dispatchMessageToObservers(messageDictionary: userInfo)
    }
}
