import SwiftUI
import WebKit

struct LoginView: View {
    @EnvironmentObject var auth: RiotAuthManager

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("VALOSHOP")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Theme.text)
                    Text("Connecte-toi avec ton compte Riot Games")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.text2)
                }

                RiotWebLogin()
                    .frame(height: 480)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusL)
                            .stroke(Theme.stroke, lineWidth: 1)
                    )
                    .padding(.horizontal)

                if let error = auth.authError {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                if auth.isAuthenticating {
                    ProgressView("Connexion...").tint(.white).foregroundStyle(Theme.text2)
                }
            }
            .padding(.top, 60)
        }
    }
}

private struct RiotWebLogin: UIViewRepresentable {
    @EnvironmentObject var auth: RiotAuthManager

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(auth.loginRequest)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(auth: auth) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let auth: RiotAuthManager
        init(auth: RiotAuthManager) { self.auth = auth }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.absoluteString.hasPrefix("http://localhost/redirect") {
                auth.handleRedirect(url: url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
