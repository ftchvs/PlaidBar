import SwiftUI

// MARK: - Hover Highlight

struct HoverHighlight: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.04) : .clear)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlight())
    }
}

// MARK: - Refresh Icon (smooth spin via TimelineView)

struct RefreshIcon: View {
    let isLoading: Bool
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .rotationEffect(.degrees(rotation))
            .onChange(of: isLoading) { _, loading in
                if loading {
                    spin()
                }
            }
            .onAppear {
                if isLoading { spin() }
            }
    }

    private func spin() {
        guard isLoading else { return }
        withAnimation(.linear(duration: 0.8)) {
            rotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            spin()
        }
    }
}
