import Foundation
import WebKit
import Combine

// Client ID utilisé par le client officiel Riot -> évite les checks anti-bot
// stricts appliqués aux clients "web" tiers.
private let riotClientID = "riot-client"
private let authorizeURL = "https://auth.riotgames.com/authorize" +
    "?redirect_uri=http://localhost/redirect" +
    "&client_id=\(riotClientID)" +
    "&response_type=token%20id_token" +
    "&nonce=1" +
    "&scope=openid%20account"

final class RiotAuthManager: NSObject, ObservableObject {
    @Published var session: RiotSession?
    @Published var isAuthenticating = false
    @Published var authError: String?

    override init() {
        super.init()
        session = SessionManager.load()
    }

    var loginRequest: URLRequest {
        URLRequest(url: URL(string: authorizeURL)!)
    }

    /// Appelé par LoginWebView dès qu'une redirection contient les tokens dans le fragment.
    func handleRedirect(url: URL) {
        guard let fragment = url.fragment else { return }
        let params = Dictionary(uniqueKeysWithValues: fragment.split(separator: "&").map { pair -> (String, String) in
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return (kv[0], kv.count > 1 ? kv[1].removingPercentEncoding ?? kv[1] : "")
        })
        guard let accessToken = params["access_token"], let idToken = params["id_token"] else {
            authError = "Login échoué, réessaie."
            return
        }
        Task { await finishLogin(accessToken: accessToken, idToken: idToken) }
    }

    @MainActor
    private func finishLogin(accessToken: String, idToken: String) async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let entitlement = try await fetchEntitlement(accessToken: accessToken)
            let userInfo = try await fetchUserInfo(accessToken: accessToken)
            let (region, shard) = try await fetchGeo(accessToken: accessToken, idToken: idToken)

            let newSession = RiotSession(
                accessToken: accessToken,
                idToken: idToken,
                entitlementToken: entitlement,
                puuid: userInfo.sub,
                region: region,
                shard: shard,
                gameName: userInfo.acct?.gameName ?? "",
                tagLine: userInfo.acct?.tagLine ?? ""
            )
            SessionManager.save(newSession)
            self.session = newSession
        } catch {
            authError = "Erreur d'authentification: \(error.localizedDescription)"
        }
    }

    func logout() {
        SessionManager.clear()
        session = nil
        // Vide les cookies de la WKWebView pour permettre un login sur un AUTRE compte
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {}
    }

    // MARK: - Requêtes réseau brutes

    private func fetchEntitlement(accessToken: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://entitlements.auth.riotgames.com/api/token/v1")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = "{}".data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Decodable { let entitlements_token: String }
        return try JSONDecoder().decode(Resp.self, from: data).entitlements_token
    }

    struct UserInfo: Decodable {
        let sub: String
        let acct: Account?
        struct Account: Decodable {
            let game_name: String?
            let tag_line: String?
            var gameName: String? { game_name }
            var tagLine: String? { tag_line }
        }
    }

    private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
        var req = URLRequest(url: URL(string: "https://auth.riotgames.com/userinfo")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(UserInfo.self, from: data)
    }

    private func fetchGeo(accessToken: String, idToken: String) async throws -> (region: String, shard: String) {
        var req = URLRequest(url: URL(string: "https://riot-geo.pas.si.riotgames.com/pas/v1/product/valorant")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["id_token": idToken])
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Decodable {
            struct Affinities: Decodable { let live: String }
            let affinities: Affinities
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        // Le shard correspond généralement à la région live ("eu", "na", "ap", "kr", "latam", "br" -> "na"/"eu")
        return (resp.affinities.live, resp.affinities.live)
    }
}
