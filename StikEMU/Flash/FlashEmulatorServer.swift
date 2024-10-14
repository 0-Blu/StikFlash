//
//  FlashEmulatorServer.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import Foundation
import Swifter
import UniformTypeIdentifiers

// Define GameData struct
struct GameData: Codable {
    var playerScore: Int
    var level: Int
}

class FlashEmulatorServer: ObservableObject {
    let server = HttpServer()
    private var currentFile: URL? = nil
    @Published private var savedGameData: GameData? = nil
    var port: UInt16 = 8080
    
    // Key for UserDefaults
    private let lastSelectedFileKey = "LastSelectedGameFileURL"
    
    init() {
        // Randomize the port before setting up routes
        randomizePort()
        
        // Attempt to load the last selected game file
        if let lastFileURL = retrieveLastSelectedFileURL() {
            self.loadFile(fileURL: lastFileURL)
            print("Loaded last selected game file: \(lastFileURL)")
        } else {
            // Initialize with default game data if no previous selection exists
            self.savedGameData = GameData(playerScore: 0, level: 1)
            print("Initialized with default game data: \(self.savedGameData!)")
        }
        
        setupRoutes()
        addLocalhostMiddleware()
    }

    deinit {
        stop()
    }

    func start() {
        do {
            try server.start(port, forceIPv4: true)
            print("Server has started on localhost (port = \(port))")
        } catch {
            print("Server start error: \(error)")
        }
    }

    func stop() {
        server.stop()
        print("Server has been stopped.")
    }

    func loadFile(fileURL: URL) {
        currentFile = fileURL
        setupFileRoutes()
        saveLastSelectedFileURL(fileURL)
    }
    
    // MARK: - Persistence Methods
    
    private func saveLastSelectedFileURL(_ fileURL: URL) {
        UserDefaults.standard.set(fileURL.path, forKey: lastSelectedFileKey)
        print("Saved last selected game file URL: \(fileURL.path)")
    }
    
    private func retrieveLastSelectedFileURL() -> URL? {
        if let path = UserDefaults.standard.string(forKey: lastSelectedFileKey) {
            let fileURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            } else {
                print("Last selected game file does not exist at path: \(path)")
                return nil
            }
        }
        return nil
    }

    private func setupRoutes() {
        server["/"] = { [weak self] request in
            guard let self = self else { return .notFound }
            if let _ = self.currentFile {
                // Serve the Flash-based HTML
                return .ok(.html(self.createFlashHTML()))
            } else {
                // Serve the simple clicker game HTML
                return .ok(.html(self.createClickerHTML()))
            }
        }
        setupGameDataRoutes()
        setupFileRoutes()
    }

    private func setupFileRoutes() {
        server["/file"] = { [weak self] request in
            guard let self = self, let fileURL = self.currentFile else {
                print("Error: File URL is nil or invalid.")
                return .notFound
            }
            do {
                let fileData = try Data(contentsOf: fileURL)
                let mimeType = self.mimeType(for: fileURL.pathExtension)
                print("Serving file: \(fileURL.lastPathComponent)")
                return .raw(200, mimeType, [:], { writer in
                    try writer.write(fileData)
                })
            } catch {
                print("Error loading file: \(error.localizedDescription)")
                return .notFound
            }
        }
    }

    private func setupGameDataRoutes() {
        // Load game data (GET request)
        server["/load"] = { [weak self] request in
            guard let self = self, let savedGameData = self.savedGameData else {
                print("Error: No game data to load.")
                return .notFound
            }
            print("Serving saved game data.")

            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(savedGameData)
                return .raw(200, "application/json", [:], { writer in
                    try writer.write(jsonData)
                })
            } catch {
                print("Error encoding game data: \(error)")
                return .internalServerError
            }
        }
    }

    private func createFlashHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body, html {
                    margin: 0;
                    padding: 0;
                    height: 100%;
                    width: 100%;
                    background-color: #000;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    overflow: hidden;
                }
                #flash-player {
                    width: 100vw;
                    height: 100vh;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    position: relative;
                    outline: none; /* Remove focus outline */
                }
                #flash-player > .ruffle-container {
                    width: 100%;
                    height: 100%;
                    transform: scale(1);
                    transform-origin: top left;
                }
            </style>
            <script src="https://unpkg.com/@ruffle-rs/ruffle"></script>
        </head>
        <body>
            <div id="flash-player" tabindex="0"></div>
            <script>
                window.addEventListener("load", () => {
                    const ruffle = window.RufflePlayer.newest();
                    const player = ruffle.createPlayer();
                    const container = document.getElementById("flash-player");
                    container.appendChild(player);
                    player.load("http://localhost:\(port)/file");

                    player.addEventListener("load", () => {
                        const fileWidth = player.stage.width;
                        const fileHeight = player.stage.height;
                        const scaleX = container.clientWidth / fileWidth;
                        const scaleY = container.clientHeight / fileHeight;
                        const scale = Math.min(scaleX, scaleY);
                        player.style.transform = `scale(${scale})`;

                        // After the game is loaded, automatically load game data
                        loadGameData().then(data => {
                            if (data) {
                                applyGameData(data);
                            }
                        });
                    });

                    container.focus();

                    document.addEventListener('keydown', function(event) {
                        console.log('Key pressed (keydown):', event.key, event.keyCode, event.code);
                    });
                    document.addEventListener('keyup', function(event) {
                        console.log('Key pressed (keyup):', event.key, event.keyCode, event.code);
                    });

                });

                function loadGameData() {
                    return fetch("http://localhost:\(port)/load")
                      .then(response => {
                          if (!response.ok) {
                              throw new Error('Network response was not ok');
                          }
                          return response.json();
                      })
                      .then(data => {
                          console.log("Loaded game data:", data);
                          return data;
                      })
                      .catch(error => {
                          console.error('Error loading game data:', error);
                          return null;
                      });
                }

                function applyGameData(data) {
                    console.log("Attempting to apply game data:", data);
                    if (player && typeof player.setGameData === 'function') {
                        try {
                            player.setGameData(data);
                            console.log("Game data applied successfully.");
                        } catch (error) {
                            console.error("Error applying game data:", error);
                        }
                    } else {
                        console.warn("Player setGameData method not found.");
                    }
                }

            </script>
        </body>
        </html>
        """
    }
    
    private func createClickerHTML() -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Flash Clicker Game</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    text-align: center;
                    margin-top: 50px;
                }
                #clickButton {
                    padding: 20px;
                    font-size: 24px;
                    background-color: #4CAF50;
                    color: white;
                    border: none;
                    cursor: pointer;
                    border-radius: 10px;
                }
                #clickButton:hover {
                    background-color: #45a049;
                }
                #score {
                    font-size: 48px;
                    margin: 20px 0;
                }
                #instructions {
                    margin-top: 20px;
                    font-size: 16px;
                }
            </style>
        </head>
        <body>
            <h1>Flash Clicker Game</h1>
            <div id="score">0</div>
            <button id="clickButton">Click Me!</button>

            <div id="instructions">
                To import or play other games, hit the "+" button and import your SWF files.
            </div>

            <script>
                // Set initial score
                let score = 0;

                // Get the score element and button element
                const scoreDisplay = document.getElementById("score");
                const clickButton = document.getElementById("clickButton");

                // Function to increment the score
                function incrementScore() {
                    score++;  // Increase score
                    scoreDisplay.textContent = score;  // Update score on the page
                }

                // Add click event to the button (mouse input)
                clickButton.addEventListener("click", incrementScore);

                // Add keyboard event listener (keyboard input)
                document.addEventListener("keydown", (event) => {
                    // List of keys that will increment the score
                    const validKeys = [
                        "Space",      // Spacebar
                        "ArrowUp",    // Arrow keys
                        "ArrowDown",
                        "ArrowLeft",
                        "ArrowRight",
                        "KeyW",       // WASD keys
                        "KeyA",
                        "KeyS",
                        "KeyD",
                        "KeyB",       // B, X, Y keys
                        "KeyX",
                        "KeyY"
                    ];

                    // Check if the pressed key is in the validKeys list
                    if (validKeys.includes(event.code)) {
                        incrementScore();
                    }
                });
            </script>
        </body>
        </html>
        """
    }

    private func mimeType(for pathExtension: String) -> String {
        if let uti = UTType(filenameExtension: pathExtension),
           let mimeType = uti.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    private func addLocalhostMiddleware() {
        server.middleware.append { request in
            if request.address != "127.0.0.1" && request.address != "::1" {
                print("Blocked request from \(request.address)")
                return .forbidden
            }
            return nil
        }
    }

    private func randomizePort() {
        port = UInt16.random(in: 8000...9000)
        print("Server will start on randomized port: \(port)")
    }
}
