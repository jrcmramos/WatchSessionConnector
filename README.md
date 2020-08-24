# Description

`WCSession` calls the session delegate methods when content is received and session state changes. The component here developed aims to help you handling different types of messages, possibly handled in different parts of the application, using the obsevation pattern, in a similat way as `NotificationCenter`.

In order to distinguish between message types (and dispatch them to the correct handler), your messages need to conform to `WatchMessageType`, defined as the following:

```Swift
protocol WatchMessageType {
    static var type: String { get } // Identifier for the message type
    func toDictionary() -> [String: Any] // Payload
}
```

# Usage

```Swift
struct ActivityStartMessagePayload: WatchMessageType {
    
    static let type: String = "activity-start"
    
    private enum Key {
        static let projectID = "projectID"
        static let startTime = "startTime"
    }
    
    let projectID: String
    let startTime: Date
    
    init(projectID: String, startTime: Date) {
        self.projectID = projectID
        self.startTime = startTime
    }
    
    init(dict: [String: Any]) {
        self.projectID = dict[Key.projectID] as! String
        self.startTime = dict[Key.startTime] as! Date
    }
    
    func toDictionary() -> [String: Any] {
        return [Key.projectID: self.projectID,
                Key.startTime: self.startTime]
    }
}

let startActivityToken = self.watchSessionConnector.addObserver(descriptor: WatchMessage.Activity.start) { [weak self] startActivityMessage in
    guard let task = self?.projectsProvider.allProjects.value.first(where: { $0.id == startActivityMessage.projectID }) else {
        return
    }
    self?.activityManager.start(project: task, withDate: Date())
}
```