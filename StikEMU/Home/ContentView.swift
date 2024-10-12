//
//  ContentView.swift
//  StikEMU
//
//  Created by Stephen on 10/12/24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedFile: URL? = nil
    
    var body: some View {
        FlashEmulatorView(selectedFile: $selectedFile) // Use the view directly
    }
}
