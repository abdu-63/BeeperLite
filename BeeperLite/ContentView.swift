//
//  ContentView.swift
//  BeeperLite
//
//  Created by Abdu on 09/06/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""

    var body: some View {
        if loggedInUsername.isEmpty {
            LoginView()
        } else {
            NavigationView {
                ChatListView(username: loggedInUsername)
                    .environment(\.managedObjectContext, DataStore.shared.context)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

#Preview {
    ContentView()
}
