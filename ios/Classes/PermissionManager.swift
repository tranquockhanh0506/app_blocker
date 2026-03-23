import Foundation
import FamilyControls
import Flutter

@available(iOS 16.0, *)
class PermissionManager: NSObject {

    func checkPermission() -> String {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "denied"
        @unknown default:
            return "restricted"
        }
    }

    func requestPermission(result: @escaping FlutterResult) {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run {
                    result(self.checkPermission())
                }
            } catch {
                await MainActor.run {
                    let status = self.checkPermission()
                    if status == "denied" {
                        result(FlutterError(
                            code: "PERMISSION_DENIED",
                            message: "Family Controls authorization was denied: \(error.localizedDescription)",
                            details: nil
                        ))
                    } else {
                        result(status)
                    }
                }
            }
        }
    }
}
