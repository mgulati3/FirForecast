
//
//  FitForecastApp.swift
//  FitForecast
//
//  Created by Manan Gulati on 30/03/25.
//

import SwiftUI

@main
struct FitForecastApp: App {
    // Initialize the PersistenceManager
    let persistenceManager = PersistenceManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceManager.container.viewContext)
        }
    }
}
