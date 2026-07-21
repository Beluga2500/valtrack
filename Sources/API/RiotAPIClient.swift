import Foundation

// Header requis par Riot : plateforme, encodé en base64 (valeur générique "PC" -
// c'est ce qu'utilise le client officiel, indépendant de l'OS qui appelle l'API)
private let clientPlatformHeader: String = {
    let json = """
    {"platformType":"PC","platformOS":"Windows","platformOSVersion":"10.0.19042.1.256.64bit","platformChipset":"Unknown"}
    """
    return Data(json.utf8).base64EncodedString()
}()

/// Cache la version du client Valorant courante (obligatoire dans X-Riot-ClientVersion,
/// sinon Riot répond 400 INVALID_HEADERS). Récupérée depuis valorant-api.com (source
/// publique tierce, mise à jour à chaque patch).
actor ClientVersionProvider {
    static let shared = ClientVersionProvider()
    private var cached: String?

    func get() async throws -> String {
        if let cached { return cached }
        let url = URL(string: "https://valorant-api.com/v1/version")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Resp: Decodable {
            struct D: Decodable { let riotClientVersion: String }
            let data: D
        }
        let version = try JSONDecoder().decode(Resp.self, from: data).data.riotClientVersion
        cached = version
        return version
    }
}

struct RiotAPIClient {
    let session: RiotSession

    private func request(_ path: String, host: String = "pd", method: String = "GET", body: Data? = nil) async throws -> Data {
        let url = URL(string: "https://\(host).\(session.shard).a.pvp.net\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(session.entitlementToken, forHTTPHeaderField: "X-Riot-Entitlements-JWT")
        req.setValue(clientPlatformHeader, forHTTPHeaderField: "X-Riot-ClientPlatform")
        req.setValue(try await ClientVersionProvider.shared.get(), forHTTPHeaderField: "X-Riot-ClientVersion")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { req.httpBody = body }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "RiotAPI", code: http.statusCode,
                           userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"])
        }
        return data
    }

    // MARK: - Profil / Rang

    func fetchMMR() async throws -> MMRResponse {
        let data = try await request("/mmr/v1/players/\(session.puuid)")
        return try JSONDecoder().decode(MMRResponse.self, from: data)
    }

    /// Historique compétitif AVEC le RR gagné/perdu match par match (contrairement
    /// à /match-history/v1/history qui ne donne que la liste brute des matchs).
    func fetchCompetitiveUpdates(count: Int = 15) async throws -> [CompetitiveUpdatesResponse.Entry] {
        let data = try await request("/mmr/v1/players/\(session.puuid)/competitiveupdates?queue=competitive&startIndex=0&endIndex=\(count)")
        return try JSONDecoder().decode(CompetitiveUpdatesResponse.self, from: data).Matches
    }

    // MARK: - Boutique

    func fetchStorefront() async throws -> Storefront {
        let data = try await request("/store/v3/storefront/\(session.puuid)", method: "POST", body: "{}".data(using: .utf8))
        return try JSONDecoder().decode(Storefront.self, from: data)
    }

    // MARK: - Locker

    func fetchLoadout() async throws -> PlayerLoadout {
        let data = try await request("/personalization/v2/players/\(session.puuid)/playerloadout")
        return try JSONDecoder().decode(PlayerLoadout.self, from: data)
    }

    func setLoadout(_ loadout: PlayerLoadout) async throws -> PlayerLoadout {
        let body = try JSONEncoder().encode(loadout)
        let data = try await request("/personalization/v2/players/\(session.puuid)/playerloadout", method: "PUT", body: body)
        return try JSONDecoder().decode(PlayerLoadout.self, from: data)
    }

    // MARK: - Inventaire possédé (skins débloqués, pour le sélecteur du Locker)

    func fetchOwnedSkinIDs() async throws -> [String] {
        // ItemTypeID des skins d'armes : e7c63390-eda7-46e0-bb7a-a6abdacd2433
        // ⚠️ Cet endpoint renvoie les UUID de base des "Skin" possédés, PAS des
        // "SkinLevel". Côté données statiques, il faut donc résoudre ces IDs
        // avec ValorantStaticData.skin(forSkinID:), pas skin(forLevelID:).
        let data = try await request("/store/v1/entitlements/\(session.puuid)/e7c63390-eda7-46e0-bb7a-a6abdacd2433")
        let resp = try JSONDecoder().decode(OwnedItemsResponse.self, from: data)
        return resp.EntitlementsByTypes?.first?.Entitlements.map(\.ItemID) ?? []
    }
}
