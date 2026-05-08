import SwiftUI
import UIKit

struct InstallSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            Text(NSLocalizedString("onboarding.install.title", comment: "Install sheet title"))
                .font(.title2.weight(.semibold))
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 20) {
                stepRow(number: "1", textKey: "onboarding.install.step.1")
                stepRow(number: "2", textKey: "onboarding.install.step.2")
                stepRow(number: "3", textKey: "onboarding.install.step.3")
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryCTAButton(titleKey: "onboarding.install.cta") {
                if let url = URL(string: "App-prefs:root=General&path=Keyboard/KEYBOARDS") {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Button(action: { isPresented = false }) {
                Text(NSLocalizedString("onboarding.install.dismiss", comment: "Dismiss sheet"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    private func stepRow(number: String, textKey: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.title3.weight(.bold))
                .foregroundColor(.cypriotOlive)
                .frame(width: 26, alignment: .center)
            Text(NSLocalizedString(textKey, comment: "Install step"))
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
