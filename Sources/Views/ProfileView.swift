import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: RiotAuthManager
    @State private var mmr: MMRResponse?
    @State private var updates: [CompetitiveUpdatesResponse.Entry] = []
    @State private var currentTier: ValorantStaticData.Tier?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            GlassBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VALOSHOP")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.text3)
                        if let session = auth.session {
                            Text("\(session.gameName)#\(session.tagLine)")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(Theme.text)
                        }
                    }
                    .padding(.top, 8)

                    GlassCard {
                        HStack(spacing: 16) {
                            if let icon = currentTier?.largeIcon, let url = URL(string: icon) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    ProgressView().tint(.white)
                                }
                                .frame(width: 64, height: 64)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(text: "Rang actuel")
                                if let update = mmr?.LatestCompetitiveUpdate {
                                    Text(currentTier?.tierName ?? "—")
                                        .font(.title2.bold())
                                        .foregroundStyle(Theme.text)
                                    Text("\(update.RankedRatingAfterUpdate) RR")
                                        .foregroundStyle(Theme.text2)
                                } else if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Aucune partie compétitive récente").foregroundStyle(Theme.text2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionLabel(text: "Matchs récents").padding(.top, 4)
                    ForEach(updates, id: \.MatchID) { entry in
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.MapID?.components(separatedBy: "/").last ?? "Match")
                                        .foregroundStyle(Theme.text)
                                        .font(.subheadline.bold())
                                    if entry.TierAfterUpdate != entry.TierBeforeUpdate {
                                        Text("Rang changé")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Text(rrLabel(entry.RankedRatingEarned))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(entry.RankedRatingEarned >= 0 ? .green : .red)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
                .padding()
            }
        }
        .task { await load() }
    }

    private func rrLabel(_ delta: Int) -> String {
        delta >= 0 ? "+\(delta) RR" : "\(delta) RR"
    }

    private func load() async {
        guard let session = auth.session else { return }
        let api = RiotAPIClient(session: session)
        do {
            try await ValorantStaticData.shared.loadTiersIfNeeded()
            async let mmrTask = api.fetchMMR()
            async let updatesTask = api.fetchCompetitiveUpdates()
            mmr = try await mmrTask
            updates = try await updatesTask
            if let tierNumber = mmr?.LatestCompetitiveUpdate?.TierAfterUpdate {
                currentTier = await ValorantStaticData.shared.tier(tierNumber)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
