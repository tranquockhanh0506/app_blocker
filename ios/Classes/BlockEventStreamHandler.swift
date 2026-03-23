import Foundation
import Flutter

class BlockEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    /// Sends a block event to the Flutter side.
    ///
    /// - Parameters:
    ///   - type: The event type string matching BlockEventType values:
    ///           "blocked", "unblocked", "attemptedAccess", "scheduleActivated", "scheduleDeactivated"
    ///   - packageName: The identifier of the affected app, if applicable.
    ///   - scheduleId: The schedule ID that triggered this event, if applicable.
    func sendEvent(type: String, packageName: String?, scheduleId: String?) {
        guard let sink = eventSink else { return }

        var event: [String: Any] = [
            "type": type,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]

        if let packageName = packageName {
            event["packageName"] = packageName
        }

        if let scheduleId = scheduleId {
            event["scheduleId"] = scheduleId
        }

        DispatchQueue.main.async {
            sink(event)
        }
    }
}
