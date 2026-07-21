import Foundation

struct MMRResponse: Decodable {
    let LatestCompetitiveUpdate: CompetitiveUpdate?

    struct CompetitiveUpdate: Decodable {
        let TierAfterUpdate: Int
        let RankedRatingAfterUpdate: Int
        let MapID: String?
    }
}

/// RR gagné/perdu match par match — endpoint distinct de /mmr/v1/players/{puuid}.
struct CompetitiveUpdatesResponse: Decodable {
    let Matches: [Entry]
    struct Entry: Decodable {
        let MatchID: String
        let MapID: String?
        let TierBeforeUpdate: Int
        let TierAfterUpdate: Int
        let RankedRatingBeforeUpdate: Int
        let RankedRatingAfterUpdate: Int
        let RankedRatingEarned: Int
        let MatchStartTime: Int64?
    }
}

// MARK: - Loadout (tolérant : Riot ajoute/retire des champs sans prévenir)

struct PlayerLoadout: Codable {
    var Subject: String
    var Version: Int
    var Guns: [GunLoadout]
    var Sprays: [SprayLoadout]?
    var Identity: Identity?

    struct GunLoadout: Codable {
        var ID: String
        var SkinID: String
        var SkinLevelID: String
        var ChromaID: String?
        var Attachments: [JSONAny]?
        var CharmInstanceID: String?
        var CharmID: String?
        var CharmLevelID: String?
    }
    struct SprayLoadout: Codable {
        var EquipSlotID: String?
        var SprayID: String?
        var SprayLevelID: String?
    }
    struct Identity: Codable {
        var PlayerCardID: String?
        var PlayerTitleID: String?
        var AccountLevel: Int?
        var PreferredLevelBorderID: String?
        var HideAccountLevel: Bool?
    }
}

/// Absorbe n'importe quel JSON sans planter le decode (utilisé pour les champs
/// dont on ne connaît/contrôle pas la forme exacte, ex: Attachments).
struct JSONAny: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        if (try? container.decode(Bool.self)) != nil { return }
        if (try? container.decode(Double.self)) != nil { return }
        if (try? container.decode(String.self)) != nil { return }
        if (try? container.decode([JSONAny].self)) != nil { return }
        if (try? container.decode([String: JSONAny].self)) != nil { return }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

// MARK: - Boutique

struct Storefront: Decodable {
    let SkinsPanelLayout: SkinsPanelLayout

    struct SkinsPanelLayout: Decodable {
        let SingleItemOffers: [String]
        let SingleItemStoreOffers: [StoreOffer]?
    }
    struct StoreOffer: Decodable {
        let OfferID: String
        let Cost: [String: Int]?
        let Rewards: [Reward]?
        struct Reward: Decodable { let ItemTypeID: String; let ItemID: String; let Quantity: Int }
    }
}

// MARK: - Inventaire possédé

struct OwnedItemsResponse: Decodable {
    let EntitlementsByTypes: [EntitlementGroup]?
    struct EntitlementGroup: Decodable {
        let ItemTypeID: String
        let Entitlements: [Entitlement]
        struct Entitlement: Decodable { let ItemID: String }
    }
}

