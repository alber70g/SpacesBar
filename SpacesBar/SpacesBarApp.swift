//
//  SpacesBarApp.swift
//  SpacesBar
//
//  Created by Albert Groothedde on 22/04/2026.
//

import SwiftUI

@main
struct SpacesBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
