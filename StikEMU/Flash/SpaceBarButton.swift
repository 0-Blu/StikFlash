//
//  SpaceBarButton.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import SwiftUI
import GameController

struct SpaceBarButton: View {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    @State private var isPressed: Bool = false
    @State private var isControllerConnected: Bool = false
    
    // Accept key binding for the space button as a parameter
    var spaceKeyBind: String
    
    var body: some View {
        Group {
            if !isControllerConnected {
                Button(action: {
                    // No action here; handled by gestures
                }) {
                    // Use spaceKeyBind for the button's text
                    Text(spaceKeyBind)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(isPressed ? Color.blue : Color.blue.opacity(0.7))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed {
                                isPressed = true
                                onPress()
                            }
                        }
                        .onEnded { _ in
                            isPressed = false
                            onRelease()
                        }
                )
                .accessibilityLabel(spaceKeyBind)
                .accessibilityHint("Press to send \(spaceKeyBind) key")
            }
        }
        .onAppear {
            checkForController()
            NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
                checkForController()
            }
            NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { _ in
                checkForController()
            }
        }
    }
    
    // Function to check if a controller is connected
    private func checkForController() {
        if let _ = GCController.controllers().first {
            isControllerConnected = true
        } else {
            isControllerConnected = false
        }
    }
}
