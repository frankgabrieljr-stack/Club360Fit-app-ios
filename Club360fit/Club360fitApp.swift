//
//  Club360fitApp.swift
//  Club360fit
//
//  Created by Frank Gabriel on 3/22/26.
//

import SwiftUI
import CoreData

@main
struct Club360fitApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
