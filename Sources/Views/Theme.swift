import SwiftUI

/// Design tokens repris de la maquette de refonte (fond noir, cartes sombres,
/// texte blanc à 3 niveaux d'opacité, boutons pilule blancs). Remplace l'ancien
/// look "glass" rouge/translucide par un style monochrome plus proche de l'app native.
enum Theme {
    static let bg = Color.black
    static let surface = Color(red: 0.051, green: 0.051, blue: 0.051)     // #0d0d0d
    static let surface2 = Color(red: 0.086, green: 0.086, blue: 0.086)    // #161616
    static let surface3 = Color(red: 0.122, green: 0.122, blue: 0.122)    // #1f1f1f

    static let stroke = Color.white.opacity(0.09)
    static let strokeStrong = Color.white.opacity(0.18)

    static let text = Color.white
    static let text2 = Color.white.opacity(0.56)
    static let text3 = Color.white.opacity(0.32)

    static let radiusL: CGFloat = 26
    static let radiusM: CGFloat = 18
    static let radiusS: CGFloat = 12
}

/// Fond plein écran noir (remplace l'ancien dégradé "glass" noir/rouge).
struct AppBackground: View {
    var body: some View {
        Theme.bg.ignoresSafeArea()
    }
}

/// Ancien nom conservé pour compatibilité, redirige vers le nouveau fond.
typealias GlassBackground = AppBackground

/// Carte sombre avec liseré discret, façon `.gun-card` / `.skin-tile` de la maquette.
struct Card<Content: View>: View {
    var radius: CGFloat = Theme.radiusM
    var fill: Color = Theme.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

/// Ancien nom conservé pour compatibilité (mêmes sites d'appel dans les vues existantes).
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        Card(radius: Theme.radiusM, content: { content })
    }
}

/// Bouton pilule blanc/texte noir, façon `.btn-change` de la maquette.
struct PillButton: View {
    var title: String
    var systemImage: String? = "chevron.right"

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
        }
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.text, in: Capsule())
        .foregroundStyle(.black)
    }
}

/// Chip de filtre par catégorie, façon `.chip` de la maquette.
struct FilterChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isActive ? Theme.text : Theme.surface2, in: Capsule())
            .foregroundStyle(isActive ? .black : Theme.text2)
            .overlay(
                Capsule().stroke(isActive ? .clear : Theme.stroke, lineWidth: 1)
            )
    }
}

/// Étiquette de section en petites majuscules, façon `.section-label` / `.gun-name`.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.text3)
    }
}
