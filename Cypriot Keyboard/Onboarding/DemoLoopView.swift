import SwiftUI

struct DemoLoopView: View {
    enum Size { case large, small }
    let size: Size

    @State private var typedCount: Int = 0
    @State private var showSuggestions: Bool = false
    @State private var replaced: Bool = false

    private let target = "Lefkosia"
    private let replacement = "Λευκωσία"

    var body: some View {
        VStack(spacing: 0) {
            // Suggestion bar
            HStack(spacing: 6) {
                suggestionPill(text: typedShown, isHighlighted: false, isFaded: showSuggestions)
                if showSuggestions {
                    suggestionPill(text: replacement, isHighlighted: true, isFaded: false)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(.systemGray6))

            Divider()

            // Fake text field
            HStack {
                Text(replaced ? "\(replacement) " : typedShown)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                if !replaced {
                    cursor
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(Color.white)
        }
        .frame(maxWidth: 320, maxHeight: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onAppear { startLoop() }
    }

    private var typedShown: String {
        String(target.prefix(typedCount))
    }

    private var cardHeight: CGFloat {
        size == .large ? 220 : 160
    }

    private var cursor: some View {
        Rectangle()
            .fill(Color.cypriotCopper.opacity(0.7))
            .frame(width: 2, height: 18)
    }

    private func suggestionPill(text: String, isHighlighted: Bool, isFaded: Bool) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
            .foregroundColor(isHighlighted ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isHighlighted ? Color.cypriotCopper : Color(.systemBackground))
            .cornerRadius(6)
            .opacity(isFaded ? 0.4 : 1)
    }

    private func startLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                // Reset
                typedCount = 0
                showSuggestions = false
                replaced = false
                try? await Task.sleep(nanoseconds: 600_000_000)

                // Type each letter
                for i in 1...target.count {
                    try? await Task.sleep(nanoseconds: 90_000_000)
                    typedCount = i
                }

                // Suggestion bar appears
                try? await Task.sleep(nanoseconds: 200_000_000)
                withAnimation(.easeIn(duration: 0.2)) { showSuggestions = true }

                // Pause showing both
                try? await Task.sleep(nanoseconds: 900_000_000)

                // Auto-replacement
                withAnimation(.easeInOut(duration: 0.2)) { replaced = true }

                // Hold replaced state
                try? await Task.sleep(nanoseconds: 1_800_000_000)

                // Fade out
                withAnimation(.easeOut(duration: 0.4)) {
                    showSuggestions = false
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}
