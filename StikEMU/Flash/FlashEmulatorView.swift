//
//  FlashEmulatorView.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import SwiftUI
import WebKit
import Combine
import GameController

struct JoystickView: View {
    // Callbacks for movement and release
    var onMove: (_ angle: Double, _ magnitude: Double) -> Void
    var onRelease: () -> Void
    
    // Joystick properties
    private let joystickRadius: CGFloat = 80  // Increased radius for larger joystick
    private let knobRadius: CGFloat = 40      // Proportional knob size
    
    @State private var knobPosition: CGPoint = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isControllerConnected: Bool = false
    
    var body: some View {
        ZStack {
            if !isControllerConnected {
                // Joystick Base
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: joystickRadius * 2, height: joystickRadius * 2)
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Joystick Knob
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(1.0)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: knobRadius * 2, height: knobRadius * 2)
                    .shadow(color: Color.black.opacity(0.6), radius: 5, x: 0, y: 3)
                    .offset(x: knobPosition.x + dragOffset.width, y: knobPosition.y + dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let location = value.location
                                let deltaX = location.x - joystickRadius
                                let deltaY = location.y - joystickRadius
                                let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
                                let maxDistance = joystickRadius - knobRadius
                                
                                if distance > maxDistance {
                                    let angle = atan2(deltaY, deltaX)
                                    let clampedX = cos(angle) * maxDistance
                                    let clampedY = sin(angle) * maxDistance
                                    knobPosition = CGPoint(x: clampedX, y: clampedY)
                                } else {
                                    knobPosition = CGPoint(x: deltaX, y: deltaY)
                                }
                                
                                let angleInDegrees = atan2(-knobPosition.y, knobPosition.x) * 180 / .pi
                                let magnitude = min(distance / maxDistance, 1.0)
                                
                                onMove(angleInDegrees, Double(magnitude))
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    knobPosition = .zero
                                }
                                onRelease()
                            }
                    )
                    .animation(.easeOut(duration: 0.2), value: knobPosition)
            }
        }
        .frame(width: joystickRadius * 2, height: joystickRadius * 2)
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

struct FlashEmulatorView: View {
    @StateObject private var flashServer = FlashEmulatorServer()
    @State private var webView = WKWebView()
    @State private var lastSentDirection: Set<String> = []
    @Binding var selectedFile: URL?
    
    @State private var pressedKeys: Set<String> = []
    @State private var inputTimer: Timer?
    @State private var controller: GCController?
    @State private var showingSettings = false
    @State private var keyBindings: [String: String] = [
        "up": "ArrowUp",
        "down": "ArrowDown",
        "left": "ArrowLeft",
        "right": "ArrowRight",
        "space": "Space"
    ]
    
    @State private var showControls = true // New state to toggle UI controls visibility
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Game content
                    WebView(url: URL(string: "http://localhost:\(flashServer.port)")!, webView: $webView)
                        .frame(width: geometry.size.width, height: verticalSizeClass == .regular ? geometry.size.height * 0.7 : geometry.size.height * 0.9)
                        .onChange(of: selectedFile) { newFile in
                            if let file = newFile {
                                loadFile(fileURL: file)
                            }
                        }
                    
                    // Conditionally show UI controls based on the toggle state
                    if verticalSizeClass == .regular && showControls {
                        Spacer() // Keep this only in portrait mode
                        
                        HStack(spacing: 50) {
                            JoystickView(onMove: { angle, magnitude in
                                handleJoystickMove(angle: angle, magnitude: magnitude)
                            }, onRelease: {
                                handleJoystickRelease()
                            })
                            .frame(width: 160, height: 160)
                            .padding()
                            
                            SpaceBarButton(onPress: {
                                pressSpaceBar()
                            }, onRelease: {
                                releaseSpaceBar()
                            }, spaceKeyBind: keyBindings["space"] ?? "Space")
                            .frame(width: 120, height: 60)
                        }
                        .padding(.bottom, 40)
                    } else {
                    }
                }
            }
            .onAppear {
                flashServer.start()
                setupControllerInput()
            }
            .onDisappear {
                flashServer.stop()
                stopInputTimer()
                releaseAllKeys()
                releaseSpaceBar()
            }
            .navigationBarItems(trailing: Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
            })
            .sheet(isPresented: $showingSettings) {
                SettingsView(keyBindings: $keyBindings, showControls: $showControls) // Pass showControls binding to settings
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - SettingsView
    struct SettingsView: View {
        @Binding var keyBindings: [String: String]
        @Binding var showControls: Bool // New binding to control UI controls visibility
        
        var body: some View {
            VStack {
                Text("Settings")
                    .font(.headline)
                    .padding()
                
                Toggle(isOn: $showControls) {
                    Text("Show UI Controls")
                }
                .padding()
                
                HStack {
                    Text("Up:")
                    TextField("ArrowUp", text: binding(for: "up"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Down:")
                    TextField("ArrowDown", text: binding(for: "down"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Left:")
                    TextField("ArrowLeft", text: binding(for: "left"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Right:")
                    TextField("ArrowRight", text: binding(for: "right"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Space:")
                    TextField("Space", text: binding(for: "space"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                
                Spacer()
            }
            .padding()
        }
        
        private func binding(for key: String) -> Binding<String> {
            Binding<String>(
                get: { keyBindings[key] ?? "" },
                set: { newValue in keyBindings[key] = newValue }
            )
        }
    }
    // MARK: - Loading Selected File
    private func loadFile(fileURL: URL) {
        // Modify the server to serve the selected file
        flashServer.loadFile(fileURL: fileURL)
        
        // Reload the WebView to load the new file
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.reload()
        }
    }

    // MARK: - Controller Input Setup
    private func setupControllerInput() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { notification in
            if let connectedController = notification.object as? GCController {
                controller = connectedController
                setupControllerHandlers(controller: connectedController)
            }
        }
        
        // In case controller was already connected before the view appeared
        if let connectedController = GCController.controllers().first {
            controller = connectedController
            setupControllerHandlers(controller: connectedController)
        }
    }

    // MARK: - Controller Handlers
    private func setupControllerHandlers(controller: GCController) {
        if let extendedGamepad = controller.extendedGamepad {
            // Map joystick input to emulator movement
            extendedGamepad.leftThumbstick.valueChangedHandler = { thumbstick, xValue, yValue in
                handleJoystickMove(angle: Double(atan2(Double(yValue), Double(xValue)) * 180 / .pi),
                                   magnitude: Double(sqrt(Double(xValue * xValue + yValue * yValue))))
            }
        
            // Map the A button to space bar actions
            extendedGamepad.buttonA.pressedChangedHandler = { button, _, pressed in
                if pressed {
                    pressSpaceBar()
                } else {
                    releaseSpaceBar()
                }
            }
        }
    }

    // MARK: - Input Handling Functions
    private func handleJoystickMove(angle: Double, magnitude: Double) {
        guard magnitude >= 0.1 else {
            handleJoystickRelease() // Ignore slight movements in the dead zone
            return
        }

        // Get the directions based on the angle
        let directions = getDirections(from: angle)

        // Update pressedKeys and ensure smooth transitions
        if directions != pressedKeys {
            stopInputTimer() // Stop the input timer if directions have changed
            pressedKeys = directions

            // Restart the input timer with new direction
            if !pressedKeys.isEmpty {
                startInputTimer()
            }
        }
    }

    private func startInputTimer() {
        stopInputTimer() // Ensure no timer overlap
        inputTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            sendPressedKeys()
        }
    }

    private func stopInputTimer() {
        inputTimer?.invalidate()
        inputTimer = nil
    }

    private func handleJoystickRelease() {
        pressedKeys.removeAll() // Clear pressed keys
        stopInputTimer() // Stop the input timer
        releaseAllKeys() // Send keyup events for all keys
    }

    private func pressSpaceBar() {
        sendKeyPress(key: keyBindings["space"]!, keyCode: keyCode(for: keyBindings["space"]!), code: keyBindings["space"]!)
    }

    private func releaseSpaceBar() {
        sendKeyUp(key: keyBindings["space"]!, keyCode: keyCode(for: keyBindings["space"]!), code: keyBindings["space"]!)
    }

    private func sendPressedKeys() {
        for key in pressedKeys {
            sendKeyPress(key: key, keyCode: keyCode(for: key), code: key)
        }
    }

    private func getDirections(from angle: Double) -> Set<String> {
        var directions: Set<String> = []

        // Normalize angle between 0 and 360
        var normalizedAngle = angle
        if normalizedAngle < 0 {
            normalizedAngle += 360
        }

        // Define angle ranges for 8 directions
        if (normalizedAngle >= 337.5 || normalizedAngle < 22.5) {
            directions.insert(keyBindings["right"]!)
        }
        if (normalizedAngle >= 22.5 && normalizedAngle < 67.5) {
            directions.insert(keyBindings["up"]!)
            directions.insert(keyBindings["right"]!)
        }
        if (normalizedAngle >= 67.5 && normalizedAngle < 112.5) {
            directions.insert(keyBindings["up"]!)
        }
        if (normalizedAngle >= 112.5 && normalizedAngle < 157.5) {
            directions.insert(keyBindings["up"]!)
            directions.insert(keyBindings["left"]!)
        }
        if (normalizedAngle >= 157.5 && normalizedAngle < 202.5) {
            directions.insert(keyBindings["left"]!)
        }
        if (normalizedAngle >= 202.5 && normalizedAngle < 247.5) {
            directions.insert(keyBindings["down"]!)
            directions.insert(keyBindings["left"]!)
        }
        if (normalizedAngle >= 247.5 && normalizedAngle < 292.5) {
            directions.insert(keyBindings["down"]!)
        }
        if (normalizedAngle >= 292.5 && normalizedAngle < 337.5) {
            directions.insert(keyBindings["down"]!)
            directions.insert(keyBindings["right"]!)
        }

        return directions
    }
    
    private func keyCode(for key: String) -> Int {
        switch key {
        case keyBindings["up"]:
            return 38
        case keyBindings["down"]:
            return 40
        case keyBindings["left"]:
            return 37
        case keyBindings["right"]:
            return 39
        case keyBindings["space"]:
            return 32
        default:
            return 0
        }
    }

    // MARK: - JavaScript Injection for Key Events
    private func sendKeyPress(key: String, keyCode: Int, code: String) {
        guard !lastSentDirection.contains(key) else { return }
        
        let jsCode = """
        (function() {
            var event = new KeyboardEvent('keydown', {
                key: '\(key)',
                keyCode: \(keyCode),
                code: '\(code)',
                which: \(keyCode),
                bubbles: true,
                cancelable: true
            });
            document.dispatchEvent(event);
        })();
        """
        
        webView.evaluateJavaScript(jsCode)
        lastSentDirection.insert(key)
    }

    private func sendKeyUp(key: String, keyCode: Int, code: String) {
        guard lastSentDirection.contains(key) else { return }
        
        let jsCode = """
        (function() {
            var event = new KeyboardEvent('keyup', {
                key: '\(key)',
                keyCode: \(keyCode),
                code: '\(code)',
                which: \(keyCode),
                bubbles: true,
                cancelable: true
            });
            document.dispatchEvent(event);
        })();
        """
        
        webView.evaluateJavaScript(jsCode)
        lastSentDirection.remove(key)
    }

    // Release all keys
    private func releaseAllKeys() {
        for key in lastSentDirection {
            sendKeyUp(key: key, keyCode: keyCode(for: key), code: key)
        }
        lastSentDirection.removeAll()
    }
}
