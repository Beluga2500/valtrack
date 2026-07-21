import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }

            ShopView()
                .tabItem { Label("Boutique", systemImage: "bag.fill") }

            LockerView()
                .tabItem { Label("Locker", systemImage: "door.left.hand.closed") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .tint(Theme.text) // monochrome noir/blanc, façon maquette (plus d'accent rouge)
        .toolbarBackground(.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

// Le fond et les cartes communs vivent désormais dans Theme.swift
// (AppBackground / GlassBackground, Card / GlassCard).
