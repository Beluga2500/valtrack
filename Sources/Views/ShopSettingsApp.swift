import SwiftUI

// MARK: - Boutique

struct ShopView: View {
    @EnvironmentObject var auth: RiotAuthManager
    @State private var offers: [ValorantStaticData.Skin] = []
    @State private var prices: [String: Int] = [:] // uuid -> prix VP
    @State private var selectedSkin: ValorantStaticData.Skin?
    @State private var errorMessage: String?
    @State private var isLoading = true

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            GlassBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VALOSHOP")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.text3)
                        Text("Boutique du jour")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if isLoading {
                        ProgressView().tint(.white)
                    } else if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(offers) { skin in
                                Button { selectedSkin = skin } label: {
                                    VStack(spacing: 8) {
                                        if let icon = skin.displayIcon, let url = URL(string: icon) {
                                            AsyncImage(url: url) { image in
                                                image.resizable().scaledToFit()
                                            } placeholder: {
                                                ProgressView().tint(.white)
                                            }
                                            .frame(height: 70)
                                        }
                                        Text(skin.displayName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Theme.text)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                        if let price = prices[skin.uuid] {
                                            HStack(spacing: 3) {
                                                Text("\(price)")
                                                Text("VP").foregroundStyle(Theme.text3)
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.text)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusM).stroke(Theme.stroke, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(item: $selectedSkin) { skin in
            SkinDetailView(skin: skin) // pas d'équipement depuis la boutique (skin pas forcément possédé)
        }
        .task { await load() }
    }

    private func load() async {
        guard let session = auth.session else { return }
        do {
            try await ValorantStaticData.shared.loadSkinsIfNeeded()
            let storefront = try await RiotAPIClient(session: session).fetchStorefront()

            for levelID in storefront.SkinsPanelLayout.SingleItemOffers {
                if let skin = await ValorantStaticData.shared.skin(forLevelID: levelID) {
                    offers.append(skin)
                }
            }
            // Associe les prix (VP = 85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741) via les offres détaillées si dispo
            if let storeOffers = storefront.SkinsPanelLayout.SingleItemStoreOffers {
                for offer in storeOffers {
                    guard let itemID = offer.Rewards?.first?.ItemID,
                          let skin = await ValorantStaticData.shared.skin(forLevelID: itemID),
                          let vp = offer.Cost?["85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741"] else { continue }
                    prices[skin.uuid] = vp
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Réglages

struct SettingsView: View {
    @EnvironmentObject var auth: RiotAuthManager
    @AppStorage("appLanguage") private var appLanguage: String = "fr"

    var body: some View {
        ZStack {
            GlassBackground()
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VALOSHOP")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.text3)
                    Text("Réglages")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                if let session = auth.session {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel(text: "Connecté en tant que")
                            Text("\(session.gameName)#\(session.tagLine)").foregroundStyle(Theme.text).font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Langue")
                        Picker("Langue", selection: $appLanguage) {
                            Text("Français").tag("fr")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.segmented)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(role: .destructive) {
                    auth.logout()
                } label: {
                    Text("Se déconnecter / changer de compte")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.radiusM))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM).stroke(Color.red.opacity(0.4), lineWidth: 1))
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - App entry point

@main
struct ValoShopApp: App {
    @StateObject private var auth = RiotAuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.session != nil {
                    RootTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(auth)
        }
    }
}
