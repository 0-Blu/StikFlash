//
//  ContentView.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedFile: URL? = nil
    @State private var selectedTab: Int = 1  // 0: Home, 1: Game
    
    @Environment(\.verticalSizeClass) var verticalSizeClass  // To detect orientation
    
    var body: some View {
        if verticalSizeClass == .regular {  // Show TabView only in portrait mode
            TabView(selection: $selectedTab) {
                HomeView(selectedFile: $selectedFile)
                    .tabItem {
                        Image(systemName: "books.vertical.fill")
                            .font(.title2)
                        Text("Library")
                            .font(.headline)
                    }
                    .tag(0)
                
                FlashEmulatorView(selectedFile: $selectedFile)
                    .tabItem {
                        Image(systemName: "gamecontroller.fill")
                            .font(.title2)
                        Text("Play")
                            .font(.headline)
                    }
                    .tag(1)
            }
            .accentColor(.blue)  // Customize tab accent color
            .onChange(of: selectedFile) { newFile in
                if newFile != nil {
                    // Switch to the Game tab when a file is selected
                    selectedTab = 1
                }
            }
        } else {
            // Landscape mode - do not show TabView
            FlashEmulatorView(selectedFile: $selectedFile)
        }
    }
}
