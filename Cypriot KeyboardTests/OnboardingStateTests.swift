import XCTest
import Combine
import UIKit
@testable import Cypriot_Keyboard

final class OnboardingStateTests: XCTestCase {
    func testInitialStateReflectsCheckClosure_installed() {
        let state = OnboardingState(keyboardCheck: { true })
        XCTAssertEqual(state.installState, .installed)
    }

    func testInitialStateReflectsCheckClosure_notInstalled() {
        let state = OnboardingState(keyboardCheck: { false })
        XCTAssertEqual(state.installState, .notInstalled)
    }

    func testRefreshUpdatesStateWhenClosureFlips() {
        var current = false
        let state = OnboardingState(keyboardCheck: { current })
        XCTAssertEqual(state.installState, .notInstalled)
        current = true
        state.refresh()
        XCTAssertEqual(state.installState, .installed)
    }

    func testRefreshIsNoOpWhenStateUnchanged() {
        let state = OnboardingState(keyboardCheck: { false })
        var changes = 0
        let cancellable = state.$installState.dropFirst().sink { _ in changes += 1 }
        state.refresh()
        cancellable.cancel()
        XCTAssertEqual(changes, 0)
    }

    func testForegroundNotificationTriggersRefresh() {
        var current = false
        let state = OnboardingState(keyboardCheck: { current })
        XCTAssertEqual(state.installState, .notInstalled)
        current = true
        NotificationCenter.default.post(
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        XCTAssertEqual(state.installState, .installed)
    }
}
