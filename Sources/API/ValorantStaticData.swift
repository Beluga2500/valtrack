import Foundation

actor ValorantStaticData {
    static let shared = ValorantStaticData()

    struct Skin: Decodable, Identifiable, Hashable {
        let uuid: String
        let displayName: String
        let displayIcon: String?
        let levels: [Level]
        let chromas: [Chroma]
        var id: String { uuid }

        struct Level: Decodable, Identifiable, Hashable {
            let uuid: String
            let displayName: String
            let displayIcon: String?
            var id: String { uuid }
        }
        struct Chroma: Decodable, Identifiable, Hashable {
            let uuid: String
            let displayName: String
            let displayIcon: String?
            let fullRender: String?
            var id: String { uuid }
        }
    }

    struct Tier: Decodable {
        let tier: Int
        let tierName: String
        let largeIcon: String?
        let smallIcon: String?
    }

    private var skinsByLevelID: [String: Skin] = [:]
    private var skinsByChromaID: [String: Skin] = [:]
    private var skinsBySkinID: [String: Skin] = [:]
    private var tiersByNumber: [Int: Tier] = [:]
    private var skinsLoaded = false
    private var tiersLoaded = false

    func loadSkinsIfNeeded() async throws {
        guard !skinsLoaded else { return }
        struct Resp: Decodable { let data: [Skin] }
        let url = URL(string: "https://valorant-api.com/v1/weapons/skins?language=fr-FR")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        for skin in resp.data {
            skinsBySkinID[skin.uuid] = skin
            for level in skin.levels { skinsByLevelID[level.uuid] = skin }
            for chroma in skin.chromas { skinsByChromaID[chroma.uuid] = skin }
        }
        skinsLoaded = true
    }

    func loadTiersIfNeeded() async throws {
        guard !tiersLoaded else { return }
        struct Resp: Decodable {
            struct Table: Decodable { let tiers: [Tier] }
            let data: [Table]
        }
        let url = URL(string: "https://valorant-api.com/v1/competitivetiers")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        if let latest = resp.data.last {
            for t in latest.tiers { tiersByNumber[t.tier] = t }
        }
        tiersLoaded = true
    }

    func skin(forLevelID id: String) -> Skin? { skinsByLevelID[id] }
    func skin(forChromaID id: String) -> Skin? { skinsByChromaID[id] }
    /// L'entitlement Riot pour les skins possédés renvoie l'UUID de base du skin
    /// (le "Skin", pas un "SkinLevel"). C'est un identifiant différent : il faut
    /// chercher dans skinsBySkinID, pas dans skinsByLevelID, sinon aucun skin
    /// possédé n'est jamais retrouvé (c'était le bug du sélecteur du Locker).
    func skin(forSkinID id: String) -> Skin? { skinsBySkinID[id] }
    func tier(_ number: Int) -> Tier? { tiersByNumber[number] }
}
