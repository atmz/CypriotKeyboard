import SwiftUI
import Combine
import UIKit

enum InstallState {
    case notInstalled
    case installed
}

final class OnboardingState: ObservableObject {
    @Published private(set) var installState: InstallState

    private let keyboardCheck: () -> Bool

    init(keyboardCheck: @escaping () -> Bool = { isKeyboardExtensionEnabled() }) {
        self.keyboardCheck = keyboardCheck
        self.installState = keyboardCheck() ? .installed : .notInstalled

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleDidBecomeActive() {
        refresh()
    }

    func refresh() {
        let next: InstallState = keyboardCheck() ? .installed : .notInstalled
        guard next != installState else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            installState = next
        }
    }
}
