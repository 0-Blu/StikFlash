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

struct FlashEmulatorView: View {
    @StateObject private var flashServer = FlashEmulatorServer()
    @State private var webView = WKWebView()
    @Binding var selectedFile: URL?
    
    @State private var controller: GCController?
    @State private var virtualController: GCVirtualController?
    @State private var showingSettings = false
    @State private var showingHomeViewPopover = false
    @State private var keyBindings: [String: String] = [
        "space": "Space",
        "buttonB": "KeyB",
        "buttonX": "KeyX",
        "buttonY": "KeyY"
    ]
    
    @State private var thumbstickMapping = "Arrow Keys"  // Default is Arrow Keys
    @State private var useDirectionPad = false  // Toggle between Thumbstick and D-pad
    @State private var showControls = true
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Game content
                    WebView(url: URL(string: "http://localhost:\(flashServer.port)")!, webView: $webView)
                        .frame(width: geometry.size.width, height: verticalSizeClass == .regular ? geometry.size.height * 0.7 : geometry.size.height)
                        .onChange(of: selectedFile) { newFile in
                            if let file = newFile {
                                loadFile(fileURL: file)
                            }
                        }
                    
                    if verticalSizeClass == .regular && showControls {
                        Spacer()
                        // UI Controls shown when showControls is true
                        VStack(spacing: 20) {
                            SpaceBarButton(onPress: {
                                pressSpaceBar()
                            }, onRelease: {
                                releaseSpaceBar()
                            }, spaceKeyBind: keyBindings["space"] ?? "Space")
                            .frame(width: 120, height: 60)
                            
                            // You can add other UI controls here
                        }
                        .padding(.bottom, 40)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
            }
            .onAppear {
                flashServer.start()
                if showControls {
                    setupVirtualController()
                }
            }
            .onChange(of: showControls) { newValue in
                if newValue {
                    setupVirtualController()
                } else {
                    disconnectVirtualController()
                }
            }
            .onChange(of: useDirectionPad) { _ in
                disconnectVirtualController()
                setupVirtualController()
            }
            .onDisappear {
                flashServer.stop()
                releaseSpaceBar()
                disconnectVirtualController()
            }
            .navigationBarItems(
                trailing: HStack {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .sheet(isPresented: $showingSettings) {
                        SettingsView(keyBindings: $keyBindings, showControls: $showControls, useDirectionPad: $useDirectionPad, thumbstickMapping: $thumbstickMapping)
                    }

                    Button(action: {
                        showingHomeViewPopover = true
                    }) {
                        Image(systemName: "plus.circle")
                    }
                    .popover(isPresented: $showingHomeViewPopover) {
                        HomeView(selectedFile: $selectedFile, isPresented: $showingHomeViewPopover)
                            .frame(width: 300, height: 400)
                    }
                }
            )
            .navigationBarHidden(verticalSizeClass == .compact)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Virtual Controller Setup
    private func setupVirtualController() {
        let virtualConfig = GCVirtualController.Configuration()
        
        // Add either Thumbstick or D-pad based on the user selection
        if useDirectionPad {
            virtualConfig.elements = [GCInputDirectionPad, GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY]
        } else {
            virtualConfig.elements = [GCInputLeftThumbstick, GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY]
        }
        
        virtualController = GCVirtualController(configuration: virtualConfig)
        virtualController?.connect()
        
        virtualController?.controller?.extendedGamepad?.valueChangedHandler = { [self] gamepad, element in
            handleGamepadInput(gamepad)
        }
    }
    
    private func loadFile(fileURL: URL) {
        flashServer.loadFile(fileURL: fileURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.reload()
        }
    }

    private func disconnectVirtualController() {
        virtualController?.disconnect()
        virtualController = nil
    }

    // MARK: - Handle Gamepad Input
    private func handleGamepadInput(_ gamepad: GCExtendedGamepad) {
        // Handle Thumbstick or D-pad Input
        if useDirectionPad {
            handleDirectionPad(gamepad.dpad)
        } else {
            handleThumbstick(gamepad.leftThumbstick)
        }

        // Handle Button A (space)
        if gamepad.buttonA.isPressed {
            pressSpaceBar()
        } else {
            releaseSpaceBar()
        }

        // Handle Button B
        if gamepad.buttonB.isPressed {
            pressButtonB()
        } else {
            releaseButtonB()
        }

        // Handle Button X
        if gamepad.buttonX.isPressed {
            pressButtonX()
        } else {
            releaseButtonX()
        }

        // Handle Button Y
        if gamepad.buttonY.isPressed {
            pressButtonY()
        } else {
            releaseButtonY()
        }
    }

    private func handleThumbstick(_ thumbstick: GCControllerDirectionPad) {
        // Map thumbstick to either WASD or Arrow Keys based on user selection
        if thumbstickMapping == "Arrow Keys" {
            // Map to Arrow Keys
            if thumbstick.up.isPressed {
                sendKeyPress(key: "ArrowUp", keyCode: 38, code: "ArrowUp")
            } else {
                sendKeyUp(key: "ArrowUp", keyCode: 38, code: "ArrowUp")
            }
            
            if thumbstick.down.isPressed {
                sendKeyPress(key: "ArrowDown", keyCode: 40, code: "ArrowDown")
            } else {
                sendKeyUp(key: "ArrowDown", keyCode: 40, code: "ArrowDown")
            }

            if thumbstick.left.isPressed {
                sendKeyPress(key: "ArrowLeft", keyCode: 37, code: "ArrowLeft")
            } else {
                sendKeyUp(key: "ArrowLeft", keyCode: 37, code: "ArrowLeft")
            }

            if thumbstick.right.isPressed {
                sendKeyPress(key: "ArrowRight", keyCode: 39, code: "ArrowRight")
            } else {
                sendKeyUp(key: "ArrowRight", keyCode: 39, code: "ArrowRight")
            }
        } else if thumbstickMapping == "WASD" {
            // Map to WASD keys
            if thumbstick.up.isPressed {
                sendKeyPress(key: "w", keyCode: 87, code: "KeyW")
            } else {
                sendKeyUp(key: "w", keyCode: 87, code: "KeyW")
            }
            
            if thumbstick.down.isPressed {
                sendKeyPress(key: "s", keyCode: 83, code: "KeyS")
            } else {
                sendKeyUp(key: "s", keyCode: 83, code: "KeyS")
            }

            if thumbstick.left.isPressed {
                sendKeyPress(key: "a", keyCode: 65, code: "KeyA")
            } else {
                sendKeyUp(key: "a", keyCode: 65, code: "KeyA")
            }

            if thumbstick.right.isPressed {
                sendKeyPress(key: "d", keyCode: 68, code: "KeyD")
            } else {
                sendKeyUp(key: "d", keyCode: 68, code: "KeyD")
            }
        }
    }

    private func handleDirectionPad(_ dpad: GCControllerDirectionPad) {
        // Handle D-pad input mapped to Arrow Keys
        handleThumbstick(dpad)  // Reusing the same logic as Thumbstick for Arrow Keys or WASD
    }

    // MARK: - Button Handlers
    private func pressSpaceBar() {
        sendKeyPress(key: keyBindings["space"]!, keyCode: keyCode(for: keyBindings["space"]!), code: keyBindings["space"]!)
    }

    private func releaseSpaceBar() {
        sendKeyUp(key: keyBindings["space"]!, keyCode: keyCode(for: keyBindings["space"]!), code: keyBindings["space"]!)
    }

    private func pressButtonB() {
        sendKeyPress(key: keyBindings["buttonB"]!, keyCode: keyCode(for: keyBindings["buttonB"]!), code: keyBindings["buttonB"]!)
    }

    private func releaseButtonB() {
        sendKeyUp(key: keyBindings["buttonB"]!, keyCode: keyCode(for: keyBindings["buttonB"]!), code: keyBindings["buttonB"]!)
    }

    private func pressButtonX() {
        sendKeyPress(key: keyBindings["buttonX"]!, keyCode: keyCode(for: keyBindings["buttonX"]!), code: keyBindings["buttonX"]!)
    }

    private func releaseButtonX() {
        sendKeyUp(key: keyBindings["buttonX"]!, keyCode: keyCode(for: keyBindings["buttonX"]!), code: keyBindings["buttonX"]!)
    }

    private func pressButtonY() {
        sendKeyPress(key: keyBindings["buttonY"]!, keyCode: keyCode(for: keyBindings["buttonY"]!), code: keyBindings["buttonY"]!)
    }

    private func releaseButtonY() {
        sendKeyUp(key: keyBindings["buttonY"]!, keyCode: keyCode(for: keyBindings["buttonY"]!), code: keyBindings["buttonY"]!)
    }

    // MARK: - JavaScript Injection for Key Events
    private func sendKeyPress(key: String, keyCode: Int, code: String) {
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
    }

    private func sendKeyUp(key: String, keyCode: Int, code: String) {
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
    }

    // MARK: - KeyCode Mapping Function
    private func keyCode(for key: String) -> Int {
        switch key {
        case "Space":
            return 32
        case "KeyB":
            return 66 // ASCII code for 'B'
        case "KeyX":
            return 88 // ASCII code for 'X'
        case "KeyY":
            return 89 // ASCII code for 'Y'
        case "ArrowUp":
            return 38
        case "ArrowDown":
            return 40
        case "ArrowLeft":
            return 37
        case "ArrowRight":
            return 39
        case "w":
            return 87 // ASCII code for 'W'
        case "a":
            return 65 // ASCII code for 'A'
        case "s":
            return 83 // ASCII code for 'S'
        case "d":
            return 68 // ASCII code for 'D'
        default:
            return 0
        }
    }
}

// MARK: - SettingsView for Remapping Controls and Switching Input Modes
struct SettingsView: View {
    @Binding var keyBindings: [String: String]
    @Binding var showControls: Bool
    @Binding var useDirectionPad: Bool
    @Binding var thumbstickMapping: String  // New binding for thumbstick mapping options
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.headline)
                .padding()
            
            Toggle(isOn: $showControls) {
                Text("Show UI Controls")
            }
            .padding()
            
            Toggle(isOn: $useDirectionPad) {
                Text("Use Direction Pad instead of Thumbstick")
            }
            .padding()
            
            Text("Thumbstick Remap")
            Picker("Thumbstick Mapping", selection: $thumbstickMapping) {
                Text("Arrow Keys").tag("Arrow Keys")
                Text("WASD").tag("WASD")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Group {
                HStack {
                    Text("Space:")
                    TextField("Space", text: binding(for: "space"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Button B:")
                    TextField("KeyB", text: binding(for: "buttonB"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Button X:")
                    TextField("KeyX", text: binding(for: "buttonX"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                HStack {
                    Text("Button Y:")
                    TextField("KeyY", text: binding(for: "buttonY"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
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
