import Foundation
import ServiceManagement

struct LaunchAtLoginManager {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var statusLabel: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Disabled"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notFound:
            return "App must be installed before login item can be enabled"
        @unknown default:
            return "Unknown"
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard SMAppService.mainApp.status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status != .notRegistered else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
