//
//  milpaApp.swift
//  milpa
//
//  Created by Fabian on 17/04/26.
//

import SwiftUI
import SwiftData

@main
struct milpaApp: App {
    @StateObject private var speaker = Speaker()
    @StateObject private var foundationModels = FoundationModelManager.shared
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(speaker)
                .environmentObject(foundationModels)
                .environmentObject(router)
                .tint(MilpaColor.green)
        }
        .modelContainer(for: [Parcela.self, FarmerProfile.self, ChatMessage.self])
    }
}
