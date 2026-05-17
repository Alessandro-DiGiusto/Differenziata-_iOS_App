//
//  Acireale_DifferenziataApp.swift
//  Acireale Differenziata
//
//  Created by Alessandro Di Giusto on 24/04/2026.
//

import SwiftUI

@main
struct Acireale_DifferenziataApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var notificationManager = WasteNotificationManager.shared
    @StateObject private var wasteProfileStore = WasteProfileStore.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(notificationManager)
                .environmentObject(wasteProfileStore)
        }
    }
}
