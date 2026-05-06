import SwiftUI

struct PostInstallView: View {
    @State private var sample = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("🇨🇾").font(.system(size: 40))
                    Text(NSLocalizedString("onboarding.done.title", comment: "Installed title"))
                        .font(.largeTitle.weight(.bold))
                }
                .padding(.top, 24)

                DemoLoopView(size: .small)

                TextField(
                    NSLocalizedString("onboarding.done.tryit.placeholder", comment: "Try it field"),
                    text: $sample
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())

                VStack(spacing: 12) {
                    FeatureCard(
                        glyph: "✦",
                        titleKey: "onboarding.feature.greeklish.title",
                        bodyKey: "onboarding.feature.greeklish.body"
                    )
                    FeatureCard(
                        glyph: "σ̆",
                        titleKey: "onboarding.feature.cypriot.title",
                        bodyKey: "onboarding.feature.cypriot.body"
                    )
                    FeatureCard(
                        glyph: "´",
                        titleKey: "onboarding.feature.accents.title",
                        bodyKey: "onboarding.feature.accents.body"
                    )
                }

                SwitchHintBanner()

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
    }
}
