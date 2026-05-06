import SwiftUI

struct PrimaryCTAButton: View {
    let titleKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(NSLocalizedString(titleKey, comment: "Primary CTA"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.cypriotCopper)
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
