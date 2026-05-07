import SwiftUI

struct DemoLoopView: View {
    enum Size { case large, small }
    let size: Size

    @State private var typedCount: Int = 0
    @State private var showSuggestions: Bool = false
    @State private var replaced: Bool = false
    @State private var phraseIndex: Int = 0

    private struct DemoPhrase {
        let typed: String
        let replacement: String
    }

    private let phrases: [DemoPhrase] = [
        .init(typed: "Lefkosia",           replacement: "Λευκωσία"),
        .init(typed: "je",                 replacement: "τζαι"),
        .init(typed: "pe je stous allous", replacement: "πε τζαι στους άλλους"),
    ]

    private var currentPhrase: DemoPhrase {
        phrases[phraseIndex % phrases.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                suggestionPill(text: typedShown.isEmpty ? " " : typedShown,
                               isHighlighted: false,
                               isFaded: showSuggestions)
                if showSuggestions {
                    suggestionPill(text: currentPhrase.replacement,
                                   isHighlighted: true,
                                   isFaded: false)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: barHeight)
            .background(Color(.systemGray6))

            Divider()

            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(typedShown.isEmpty ? " " : typedShown)
                        .font(.system(size: 19))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    cursor.opacity(replaced ? 0 : 1)
                    Spacer(minLength: 0)
                }
                .opacity(replaced ? 0 : 1)

                HStack(spacing: 0) {
                    Text("\(currentPhrase.replacement) ")
                        .font(.system(size: 19))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 0)
                }
                .opacity(replaced ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .frame(height: fieldHeight)
            .background(Color.white)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .onAppear { startLoop() }
    }

    private var typedShown: String {
        String(currentPhrase.typed.prefix(typedCount))
    }

    private var cardWidth: CGFloat {
        size == .large ? 320 : 280
    }

    private var cardHeight: CGFloat {
        size == .large ? 240 : 180
    }

    private var barHeight: CGFloat { 38 }

    private var fieldHeight: CGFloat {
        cardHeight - barHeight - 1
    }

    private var cursor: some View {
        Rectangle()
            .fill(Color.cypriotCopper.opacity(0.7))
            .frame(width: 2, height: 22)
    }

    private func suggestionPill(text: String, isHighlighted: Bool, isFaded: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
            .foregroundColor(isHighlighted ? .white : .primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isHighlighted ? Color.cypriotCopper : Color(.systemBackground))
            .cornerRadius(6)
            .opacity(isFaded ? 0.4 : 1)
    }

    private func startLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                let phrase = currentPhrase

                typedCount = 0
                showSuggestions = false
                replaced = false
                try? await Task.sleep(nanoseconds: 600_000_000)

                let perChar: UInt64 = phrase.typed.count > 8 ? 60_000_000 : 90_000_000
                for i in 1...phrase.typed.count {
                    try? await Task.sleep(nanoseconds: perChar)
                    typedCount = i
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.easeIn(duration: 0.2)) { showSuggestions = true }

                try? await Task.sleep(nanoseconds: 900_000_000)

                withAnimation(.easeInOut(duration: 0.2)) { replaced = true }

                try? await Task.sleep(nanoseconds: 1_800_000_000)

                withAnimation(.easeOut(duration: 0.4)) {
                    showSuggestions = false
                }
                try? await Task.sleep(nanoseconds: 500_000_000)

                phraseIndex += 1
            }
        }
    }
}
