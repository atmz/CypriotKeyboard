import SwiftUI

struct SwitchHintBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(NSLocalizedString("onboarding.switchhint", comment: "How to use after install"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
                .multilineTextAlignment(.leading)
        }
    }
}
