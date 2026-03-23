import Foundation
import UIKit
import SwiftUI
import FamilyControls
import Flutter

@available(iOS 16.0, *)
class ActivityPickerCoordinator: NSObject {
    private var pendingResult: FlutterResult?
    private var hostingController: UIHostingController<ActivityPickerView>?

    func showPicker(from viewController: UIViewController, result: @escaping FlutterResult) {
        // Prevent multiple concurrent pickers
        if pendingResult != nil {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Activity picker is already being shown.",
                details: nil
            ))
            return
        }

        pendingResult = result

        let pickerView = ActivityPickerView(
            onDone: { [weak self] selection in
                self?.onPickerDone(selection: selection, presenter: viewController)
            },
            onCancel: { [weak self] in
                self?.onPickerCancelled(presenter: viewController)
            }
        )

        let hosting = UIHostingController(rootView: pickerView)
        hosting.modalPresentationStyle = .fullScreen
        hostingController = hosting

        viewController.present(hosting, animated: true, completion: nil)
    }

    private func onPickerDone(selection: FamilyActivitySelection, presenter: UIViewController) {
        // Apply the selection to the shield
        if #available(iOS 15.0, *) {
            if let shieldManager = AppBlockerPlugin.shared?.shieldManager as? ShieldManager {
                shieldManager.blockWithSelection(selection: selection)
            }
        }

        // Build result data with selection info
        var apps: [[String: Any]] = []

        var appIndex = 0
        for _ in selection.applicationTokens {
            apps.append([
                "packageName": "app_token_\(appIndex)",
                "appName": "Selected App \(appIndex)",
                "isSystemApp": false,
            ])
            appIndex += 1
        }

        var catIndex = 0
        for _ in selection.categoryTokens {
            apps.append([
                "packageName": "cat_token_\(catIndex)",
                "appName": "Selected Category \(catIndex)",
                "isSystemApp": false,
            ])
            catIndex += 1
        }

        presenter.dismiss(animated: true) { [weak self] in
            self?.pendingResult?(apps)
            self?.pendingResult = nil
            self?.hostingController = nil
        }
    }

    private func onPickerCancelled(presenter: UIViewController) {
        presenter.dismiss(animated: true) { [weak self] in
            self?.pendingResult?([] as [Any])
            self?.pendingResult = nil
            self?.hostingController = nil
        }
    }
}
