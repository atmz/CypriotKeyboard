import SwiftUI

struct OnboardingShell: View {
    @StateObject private var state = OnboardingState()

    var body: some View {
        Group {
            switch state.installState {
            case .notInstalled:
                WelcomeHeroView()
            case .installed:
                PostInstallView()
            }
        }
    }
}
