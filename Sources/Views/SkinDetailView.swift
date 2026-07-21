import SwiftUI

struct SkinDetailView: View {
    let skin: ValorantStaticData.Skin
    /// Si non-nil, affiche un bouton "Équiper" par variante et transmet le choix.
    var onEquip: ((_ levelID: String, _ chromaID: String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Chroma "par défaut" utilisé quand on équipe un niveau sans variante
    /// explicitement choisie. Avant, ce bouton envoyait `skin.uuid` comme
    /// chromaID (un UUID de skin, pas de chroma) — ça n'avait pas de sens
    /// côté API. On envoie maintenant le premier chroma du skin, comme le fait
    /// le client Riot officiel pour l'apparence par défaut.
    private var defaultChromaID: String { skin.chromas.first?.uuid ?? skin.uuid }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let icon = skin.displayIcon, let url = URL(string: icon) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView().tint(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(Theme.surface3, in: RoundedRectangle(cornerRadius: Theme.radiusL))
                        }

                        Text(skin.displayName)
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Theme.text)

                        if !skin.levels.isEmpty {
                            SectionLabel(text: "Améliorations")
                            ForEach(skin.levels) { level in
                                Card {
                                    HStack {
                                        if let icon = level.displayIcon, let url = URL(string: icon) {
                                            AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView().tint(.white) }
                                                .frame(width: 40, height: 40)
                                        }
                                        Text(level.displayName).foregroundStyle(Theme.text)
                                        Spacer()
                                        if let onEquip {
                                            Button {
                                                onEquip(level.uuid, defaultChromaID)
                                                dismiss()
                                            } label: {
                                                PillButton(title: "Équiper", systemImage: nil)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !skin.chromas.isEmpty {
                            SectionLabel(text: "Variantes")
                            ForEach(skin.chromas) { chroma in
                                Card {
                                    HStack {
                                        if let icon = chroma.displayIcon ?? chroma.fullRender, let url = URL(string: icon) {
                                            AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView().tint(.white) }
                                                .frame(width: 40, height: 40)
                                        }
                                        Text(chroma.displayName).foregroundStyle(Theme.text)
                                        Spacer()
                                        if let onEquip, let baseLevel = skin.levels.first {
                                            Button {
                                                onEquip(baseLevel.uuid, chroma.uuid)
                                                dismiss()
                                            } label: {
                                                PillButton(title: "Équiper", systemImage: nil)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
