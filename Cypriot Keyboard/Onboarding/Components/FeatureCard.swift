import SwiftUI

struct FeatureCard: View {
    let glyph: String
    let titleKey: String
    let bodyKey: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(glyph)
                .font(.title2.weight(.semibold))
                .foregroundColor(.cypriotOlive)
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString(titleKey, comment: "Feature card title"))
                    .font(.headline)
                Text(NSLocalizedString(bodyKey, comment: "Feature card body"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
