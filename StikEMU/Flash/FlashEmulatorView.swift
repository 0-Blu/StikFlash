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
    @State private var showingHomeViewSheet = false
    @State private var keyBindings: [String: String] = [
        "space": "Space",
        "buttonB": "KeyB",
        "buttonX": "KeyX",
        "buttonY": "KeyY"
    ]
    
    @State private var thumbstickMapping = "Arrow Keys"
    @State private var useDirectionPad = false
    @State private var showControls = true
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        ZStack {
            // WebView covering the entire screen
            WebView(url: URL(string: "http://localhost:\(flashServer.port)")!, webView: $webView)
                .edgesIgnoringSafeArea(.all)
                .onChange(of: selectedFile) { newFile in
                    if let file = newFile {
                        loadFile(fileURL: file)
                    }
                }
            
            // Overlay controls and settings
            VStack {
                Spacer()

                if verticalSizeClass == .regular && showControls {
                    VStack(spacing: 20) {
                        SpaceBarButton(onPress: {
                            pressSpaceBar()
                        }, onRelease: {
                            releaseSpaceBar()
                        }, spaceKeyBind: keyBindings["space"] ?? "Space")
                        .frame(width: 120, height: 60)
                        .background(Color(.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color(.systemBlue).opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 16)

                        // Additional controls can be added here
                    }
                    .padding(.bottom, 40)
                }

                Spacer()
            }

            // Settings and HomeView sheet
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        showingSettings.toggle()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                            .padding()
                    }
                    .sheet(isPresented: $showingSettings) {
                        SettingsView(
                            keyBindings: $keyBindings,
                            showControls: $showControls,
                            useDirectionPad: $useDirectionPad,
                            thumbstickMapping: $thumbstickMapping,
                            isPresented: $showingSettings
                        )
                        .background(Color(.systemGroupedBackground))
                    }

                    Button(action: {
                        showingHomeViewSheet.toggle()
                    }) {
                        Image(systemName: "house.circle")
                            .foregroundColor(.blue)
                            .font(.title2)
                            .padding()
                    }
                    .sheet(isPresented: $showingHomeViewSheet) {
                        HomeView(selectedFile: $selectedFile, isPresented: $showingHomeViewSheet)
                            .presentationDetents([.medium, .large])
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(12)
                    }
                }

                Spacer()
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
    }

    // MARK: - Virtual Controller Setup
    private func setupVirtualController() {
        let virtualConfig = GCVirtualController.Configuration()
        
        if useDirectionPad {
            virtualConfig.elements = [GCInputDirectionPad, GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY]
        } else {
            virtualConfig.elements = [GCInputLeftThumbstick, GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY]
        }
        
        virtualController = GCVirtualController(configuration: virtualConfig)
        virtualController?.connect()
        
        virtualController?.controller?.extendedGamepad?.valueChangedHandler = { gamepad, element in
            handleGamepadInput(gamepad)
        }
    }
    
    /// Loads the selected file into the server and reloads the WebView.
    private func loadFile(fileURL: URL) {
        print("FlashEmulatorView: Loading file \(fileURL.path)")
        flashServer.loadFile(fileURL: fileURL) // Correctly accessing the method
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("FlashEmulatorView: Reloading WebView after loading file")
            webView.reload()
        }
    }

    private func disconnectVirtualController() {
        virtualController?.disconnect()
        virtualController = nil
    }

    // MARK: - Handle Gamepad Input
    private func handleGamepadInput(_ gamepad: GCExtendedGamepad) {
        if useDirectionPad {
            handleDirectionPad(gamepad.dpad)
        } else {
            handleThumbstick(gamepad.leftThumbstick)
        }

        if gamepad.buttonA.isPressed {
            pressSpaceBar()
        } else {
            releaseSpaceBar()
        }

        if gamepad.buttonB.isPressed {
            pressButtonB()
        } else {
            releaseButtonB()
        }

        if gamepad.buttonX.isPressed {
            pressButtonX()
        } else {
            releaseButtonX()
        }

        if gamepad.buttonY.isPressed {
            pressButtonY()
        } else {
            releaseButtonY()
        }
    }

    private func handleThumbstick(_ thumbstick: GCControllerDirectionPad) {
        if thumbstickMapping == "Arrow Keys" {
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
        handleThumbstick(dpad)
    }

    // MARK: - Button Handlers
    private func pressSpaceBar() {
        guard let key = keyBindings["space"] else { return }
        sendKeyPress(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func releaseSpaceBar() {
        guard let key = keyBindings["space"] else { return }
        sendKeyUp(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func pressButtonB() {
        guard let key = keyBindings["buttonB"] else { return }
        sendKeyPress(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func releaseButtonB() {
        guard let key = keyBindings["buttonB"] else { return }
        sendKeyUp(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func pressButtonX() {
        guard let key = keyBindings["buttonX"] else { return }
        sendKeyPress(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func releaseButtonX() {
        guard let key = keyBindings["buttonX"] else { return }
        sendKeyUp(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func pressButtonY() {
        guard let key = keyBindings["buttonY"] else { return }
        sendKeyPress(key: key, keyCode: keyCode(for: key), code: key)
    }

    private func releaseButtonY() {
        guard let key = keyBindings["buttonY"] else { return }
        sendKeyUp(key: key, keyCode: keyCode(for: key), code: key)
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
        
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("Error injecting keydown event: \(error)")
            } else {
                print("Injected keydown event for key: \(key)")
            }
        }
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
        
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                print("Error injecting keyup event: \(error)")
            } else {
                print("Injected keyup event for key: \(key)")
            }
        }
    }

    // MARK: - KeyCode Mapping Function
    private func keyCode(for key: String) -> Int {
        switch key {
        case "Space":
            return 32
        case "KeyB":
            return 66
        case "KeyX":
            return 88
        case "KeyY":
            return 89
        case "ArrowUp":
            return 38
        case "ArrowDown":
            return 40
        case "ArrowLeft":
            return 37
        case "ArrowRight":
            return 39
        case "w":
            return 87
        case "a":
            return 65
        case "s":
            return 83
        case "d":
            return 68
        default:
            return 0
        }
    }
}

// MARK: - Compact SettingsView for Remapping Controls and Switching Input Modes
struct SettingsView: View {
    @Binding var keyBindings: [String: String]
    @Binding var showControls: Bool
    @Binding var useDirectionPad: Bool
    @Binding var thumbstickMapping: String
    @Binding var isPresented: Bool

    let keyOptions = ["Space", "KeyA", "KeyB", "KeyX", "KeyY", "KeyW", "KeyS", "KeyD", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
            }
            .padding(.top, 16)
            .padding(.horizontal)
            
            Toggle("Show UI Controls", isOn: $showControls)
                .padding(.horizontal)

            Toggle("Use Direction Pad", isOn: $useDirectionPad)
                .padding(.horizontal)

            Picker("Thumbstick Mapping", selection: $thumbstickMapping) {
                Text("Arrow Keys").tag("Arrow Keys")
                Text("WASD").tag("WASD")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            ForEach(["space", "buttonB", "buttonX", "buttonY"], id: \.self) { key in
                HStack {
                    Text("\(key.capitalized):")
                    Spacer()
                    Picker(selection: binding(for: key), label: Text(keyBindings[key] ?? "")) {
                        ForEach(keyOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
        .padding()
        .preferredColorScheme(.dark) // This forces dark mode
    }

    private func binding(for key: String) -> Binding<String> {
        Binding<String>(
            get: { keyBindings[key] ?? "" },
            set: { newValue in keyBindings[key] = newValue }
        )
    }
}
