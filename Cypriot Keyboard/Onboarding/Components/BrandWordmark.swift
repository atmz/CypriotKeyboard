import SwiftUI

struct BrandWordmark: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("🇨🇾")
                .font(.system(size: 48))
            Text(NSLocalizedString("onboarding.brand.title", comment: "App brand"))
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(NSLocalizedString("onboarding.brand.tagline", comment: "App tagline"))
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
