import SwiftUI

struct WelcomeHeroView: View {
    @State private var showSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            BrandWordmark()
            DemoLoopView(size: .large)
            Spacer()
            PrimaryCTAButton(titleKey: "onboarding.welcome.cta") {
                showSheet = true
            }
            VStack(spacing: 4) {
                Text(NSLocalizedString("onboarding.author", comment: "Author"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("onboarding.credits", comment: "Credits"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showSheet) {
            InstallSheetView(isPresented: $showSheet)
        }
    }
}
