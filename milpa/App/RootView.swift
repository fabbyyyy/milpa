//
//  RootView.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//

import SwiftUI
import Combine

enum MilpaTab: Hashable { case decide, cuida, vende, home }

final class AppRouter: ObservableObject {
    @Published var tab: MilpaTab = .home
    @Published var selectedConversationId: UUID? = nil
}

struct RootView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(MilpaTab.home)

            DecideView()
                .tabItem { Label("Decide", systemImage: "sparkles") }
                .tag(MilpaTab.decide)

            CuidaView()
                .tabItem { Label("Cuida", systemImage: "leaf") }
                .tag(MilpaTab.cuida)
        }
    }
}
