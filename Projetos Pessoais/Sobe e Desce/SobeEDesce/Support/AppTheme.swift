import SwiftUI
import UIKit

enum AppTheme {
    static let burgundy = adaptiveColor(
        light: UIColor(red: 0.45, green: 0.08, blue: 0.13, alpha: 1),
        dark: UIColor(red: 0.76, green: 0.18, blue: 0.26, alpha: 1)
    )
    static let deepBurgundy = adaptiveColor(
        light: UIColor(red: 0.24, green: 0.035, blue: 0.065, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.68, blue: 0.72, alpha: 1)
    )
    static let felt = adaptiveColor(
        light: UIColor(red: 0.08, green: 0.28, blue: 0.21, alpha: 1),
        dark: UIColor(red: 0.34, green: 0.78, blue: 0.64, alpha: 1)
    )
    static let cream = adaptiveColor(
        light: UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
    )
    static let pressedButton = Color(red: 0.24, green: 0.035, blue: 0.065)

    static var background: some View {
        LinearGradient(
            colors: [cream, Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct GameCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            }
    }
}

struct PrimaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                configuration.isPressed ? AppTheme.pressedButton : AppTheme.burgundy,
                in: RoundedRectangle(cornerRadius: 15)
            )
            .contentShape(RoundedRectangle(cornerRadius: 15))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func gameScreenBackground() -> some View {
        background { AppTheme.background }
    }
}
