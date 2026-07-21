import SwiftUI

struct LockerView: View {
    @EnvironmentObject var auth: RiotAuthManager
    @State private var loadout: PlayerLoadout?
    @State private var gunSkins: [Int: ValorantStaticData.Skin] = [:] // index dans loadout.Guns -> skin résolu
    @State private var ownedSkins: [ValorantStaticData.Skin] = []
    @State private var pickerForGunIndex: Int?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var activeCategory: WeaponCategory = .all

    private enum WeaponCategory: String, CaseIterable, Identifiable {
        case all, rifle, smg, sidearm, sniper
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "Tout"
            case .rifle: return "Fusils"
            case .smg: return "SMG"
            case .sidearm: return "Pistolets"
            case .sniper: return "Sniper"
            }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    categoryChips
                        .padding(.bottom, 16)

                    if let loadout {
                        let entries = Array(loadout.Guns.enumerated())
                            .filter { activeCategory == .all || weaponCategory($0.element.ID) == activeCategory }

                        VStack(spacing: 12) {
                            ForEach(entries, id: \.offset) { idx, gun in
                                gunCard(idx: idx, gun: gun)
                            }
                        }
                    } else if errorMessage == nil {
                        ProgressView().tint(.white).padding(.top, 40)
                    }

                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Application en cours…").foregroundStyle(Theme.text2)
                        }
                        .padding(.top, 12)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote).padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .task { await load() }
        .sheet(item: Binding(
            get: { pickerForGunIndex.map { GunPickerTarget(index: $0) } },
            set: { pickerForGunIndex = $0?.index }
        )) { target in
            SkinPickerSheet(
                weaponName: loadout.map { weaponName($0.Guns[target.index].ID) } ?? "Arme",
                skins: ownedSkins,
                equippedSkinID: gunSkins[target.index]?.uuid
            ) { levelID, chromaID in
                Task { await equip(gunIndex: target.index, skinLevelID: levelID, chromaID: chromaID) }
            }
        }
    }

    // MARK: - Sous-vues

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("VALOSHOP")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.text3)
            Text("Locker")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            if let session = auth.session {
                Text("\(session.gameName)#\(session.tagLine) · \(ownedSkins.count) skins possédés")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WeaponCategory.allCases) { cat in
                    Button { activeCategory = cat } label: {
                        FilterChip(title: cat.label, isActive: activeCategory == cat)
                    }
                }
            }
        }
    }

    private func gunCard(idx: Int, gun: PlayerLoadout.GunLoadout) -> some View {
        let skin = gunSkins[idx]
        return Button {
            pickerForGunIndex = idx
        } label: {
            HStack(spacing: 0) {
                // Zone "art" de l'arme : à défaut d'icône réelle chargée, un monogramme.
                ZStack {
                    Theme.surface3
                    if let icon = skin?.displayIcon, let url = URL(string: icon) {
                        AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: {
                            ProgressView().tint(.white)
                        }
                        .padding(10)
                    } else {
                        Text(monogram(weaponName(gun.ID)))
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Theme.text3)
                    }
                }
                .frame(width: 130, height: 132)

                VStack(alignment: .leading, spacing: 6) {
                    Text(weaponName(gun.ID).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.text3)
                    Text(skin?.displayName ?? "Skin par défaut")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        PillButton(title: "Changer")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusL).stroke(Theme.stroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL))
        }
        .buttonStyle(.plain)
    }

    private struct GunPickerTarget: Identifiable { let index: Int; var id: Int { index } }

    // MARK: - Data

    private func load() async {
        guard let session = auth.session else { return }
        let api = RiotAPIClient(session: session)
        do {
            try await ValorantStaticData.shared.loadSkinsIfNeeded()
            let fetchedLoadout = try await api.fetchLoadout()
            loadout = fetchedLoadout
            for (idx, gun) in fetchedLoadout.Guns.enumerated() {
                if let bySkinLevel = await ValorantStaticData.shared.skin(forLevelID: gun.SkinLevelID) {
                    gunSkins[idx] = bySkinLevel
                } else if let chromaID = gun.ChromaID {
                    gunSkins[idx] = await ValorantStaticData.shared.skin(forChromaID: chromaID)
                }
            }
            // Bug corrigé : l'entitlement Riot renvoie l'UUID de base du "Skin",
            // pas un "SkinLevel". Il faut donc résoudre via skin(forSkinID:) —
            // avant, ce lookup se faisait avec skin(forLevelID:) et ne matchait
            // jamais rien, donc le sélecteur de skins restait toujours vide.
            let ownedIDs = try await api.fetchOwnedSkinIDs()
            var owned: [ValorantStaticData.Skin] = []
            for id in ownedIDs {
                if let skin = await ValorantStaticData.shared.skin(forSkinID: id) {
                    owned.append(skin)
                }
            }
            ownedSkins = Array(Set(owned)).sorted { $0.displayName < $1.displayName }
        } catch let DecodingError.keyNotFound(key, context) {
            errorMessage = "Champ manquant dans la réponse Riot: '\(key.stringValue)' (\(context.codingPath.map(\.stringValue).joined(separator: ".")))"
        } catch let DecodingError.typeMismatch(_, context) {
            errorMessage = "Format inattendu à: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        } catch let DecodingError.valueNotFound(_, context) {
            errorMessage = "Valeur manquante à: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func equip(gunIndex: Int, skinLevelID: String, chromaID: String) async {
        guard var loadout, let session = auth.session else { return }
        isSaving = true
        defer { isSaving = false }
        let skin = await ValorantStaticData.shared.skin(forLevelID: skinLevelID)
        loadout.Guns[gunIndex].SkinLevelID = skinLevelID
        loadout.Guns[gunIndex].SkinID = skin?.uuid ?? loadout.Guns[gunIndex].SkinID
        loadout.Guns[gunIndex].ChromaID = chromaID
        do {
            let updated = try await RiotAPIClient(session: session).setLoadout(loadout)
            self.loadout = updated
            gunSkins[gunIndex] = skin
        } catch {
            errorMessage = "Échec de l'équipement: \(error.localizedDescription)"
        }
    }

    private func weaponName(_ id: String) -> String {
        let known: [String: String] = [
            "9c82e19d-4575-0200-1a81-3eacf00cf872": "Vandal",
            "ee8e8d15-496b-07ac-e5f6-8fae5d4c7b1a": "Phantom",
            "44d4e95c-4157-0037-816b-13271bb018d3": "Classic",
            "29a0cfab-485b-f5d5-779a-b59f85e204a8": "Sheriff",
            "1baa85b4-4c70-1284-64bb-6481dfc3bb4e": "Ghost"
        ]
        return known[id] ?? "Arme"
    }

    private func weaponCategory(_ id: String) -> WeaponCategory {
        let categories: [String: WeaponCategory] = [
            "9c82e19d-4575-0200-1a81-3eacf00cf872": .rifle,   // Vandal
            "ee8e8d15-496b-07ac-e5f6-8fae5d4c7b1a": .rifle,   // Phantom
            "44d4e95c-4157-0037-816b-13271bb018d3": .sidearm, // Classic
            "29a0cfab-485b-f5d5-779a-b59f85e204a8": .sidearm, // Sheriff
            "1baa85b4-4c70-1284-64bb-6481dfc3bb4e": .sidearm  // Ghost
        ]
        return categories[id] ?? .rifle
    }

    private func monogram(_ name: String) -> String {
        String(name.prefix(2)).uppercased()
    }
}

/// Feuille de sélection d'un skin possédé, réutilise SkinDetailView pour le choix
/// des améliorations/variantes avec équipement direct.
private struct SkinPickerSheet: View {
    let weaponName: String
    let skins: [ValorantStaticData.Skin]
    let equippedSkinID: String?
    let onEquip: (_ levelID: String, _ chromaID: String) -> Void
    @State private var selected: ValorantStaticData.Skin?
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    if skins.isEmpty {
                        VStack(spacing: 8) {
                            Text("Aucun skin possédé pour l'instant")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("Les skins achetés ou débloqués apparaîtront ici.")
                                .font(.footnote)
                                .foregroundStyle(Theme.text2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        .padding(.horizontal, 30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(skins) { skin in
                                Button { selected = skin } label: {
                                    skinTile(skin)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Skins — \(weaponName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $selected) { skin in
                SkinDetailView(skin: skin, onEquip: onEquip)
            }
        }
    }

    private func skinTile(_ skin: ValorantStaticData.Skin) -> some View {
        let isEquipped = skin.uuid == equippedSkinID
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Theme.surface3
                if let icon = skin.displayIcon, let url = URL(string: icon) {
                    AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView().tint(.white) }
                        .padding(10)
                }
                if isEquipped {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.black)
                        .padding(6)
                        .background(Theme.text, in: Circle())
                        .padding(8)
                }
            }
            .frame(height: 88)

            Text(skin.displayName)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

            if skin.chromas.count > 1 {
                Text("\(skin.chromas.count) variantes")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.text3)
                    .padding(.horizontal, 12)
                    .padding(.top, 3)
                    .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.radiusM))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusM)
                .stroke(isEquipped ? Theme.text : Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM))
    }
}
