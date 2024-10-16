//
//  FlashEmulatorServer.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import Foundation
import Swifter
import UniformTypeIdentifiers
import Combine

// Define GameData struct
struct GameData: Codable {
    var playerScore: Int
    var level: Int
}

class FlashEmulatorServer: ObservableObject {
    let server = HttpServer()
    private var currentFile: URL? = nil
    @Published var savedGameData: GameData? = nil {
        didSet {
            if let fileURL = currentFile {
                saveGameData(for: fileURL)
            }
        }
    }
    var port: UInt16 = 8080 // Fixed port
    private var cancellables = Set<AnyCancellable>()
    
    // File name for saving game data
    private let gameDataFileName = "GameData.json"
    
    // Computed property to get the Documents directory URL
    private var documentsDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // Computed property for the data directory
    private var dataDirectory: URL {
        let dataDir = documentsDirectory.appendingPathComponent("data")
        if !FileManager.default.fileExists(atPath: dataDir.path) {
            do {
                try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true, attributes: nil)
                print("Created data directory at \(dataDir.path)")
            } catch {
                print("Failed to create data directory: \(error)")
            }
        }
        return dataDir
    }
    
    // Computed property for the GameData file URL within the subdirectory
    private func gameDataFileURL(for fileURL: URL) -> URL {
        let subDir = subdirectory(for: fileURL)
        return subDir.appendingPathComponent(gameDataFileName)
    }
    
    init() {
        print("Initializing FlashEmulatorServer on port: \(port)")
        
        // Attempt to load the last selected file's data
        if let lastFileURL = retrieveLastSelectedFileURL() {
            loadFile(fileURL: lastFileURL)
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
    
    // MARK: - File Loading and Saving
    
    /// Loads GameData from the specified file's directory. If the file doesn't exist or fails to decode, initializes with default values.
    func loadGameData(for fileURL: URL) {
        let fileURLForData = gameDataFileURL(for: fileURL)
        print("Loading game data from: \(fileURLForData.path)")
        if FileManager.default.fileExists(atPath: fileURLForData.path) {
            do {
                let data = try Data(contentsOf: fileURLForData)
                let decoder = JSONDecoder()
                let gameData = try decoder.decode(GameData.self, from: data)
                self.savedGameData = gameData
                print("Loaded game data from \(fileURLForData.path): \(gameData)")
            } catch {
                print("Failed to load game data from file: \(error). Initializing with default values.")
                self.savedGameData = GameData(playerScore: 0, level: 1)
                saveGameData(for: fileURL) // Save default data
            }
        } else {
            // Initialize with default game data if the file doesn't exist
            self.savedGameData = GameData(playerScore: 0, level: 1)
            print("Game data file does not exist. Initialized with default game data: \(self.savedGameData!)")
            saveGameData(for: fileURL) // Create the file with default data
        }
    }
    
    /// Saves the current GameData to the specified file's directory.
    func saveGameData(for fileURL: URL) {
        guard let gameData = savedGameData else {
            print("No game data to save.")
            return
        }
        
        let fileURLForData = gameDataFileURL(for: fileURL)
        print("Saving game data to: \(fileURLForData.path)")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // For readability
            let data = try encoder.encode(gameData)
            try data.write(to: fileURLForData, options: [.atomicWrite, .completeFileProtection])
            print("Game data saved to \(fileURLForData.path): \(gameData)")
        } catch {
            print("Failed to save game data to file: \(error)")
        }
    }
    
    /// Loads a specific file into the server and reloads the WebView.
    func loadFile(fileURL: URL) {
        print("Attempting to load file: \(fileURL.path)")
        currentFile = fileURL
        setupFileRoutes()
        saveLastSelectedFileURL(fileURL)
        loadGameData(for: fileURL)
        
        // Notify observers that a new file has been loaded, if necessary
    }
    
    // MARK: - Directory Helpers
    
    /// Returns the subdirectory for the given file. Creates it if it doesn't exist.
    private func subdirectory(for fileURL: URL) -> URL {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let subDir = dataDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: subDir.path) {
            do {
                try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true, attributes: nil)
                print("Created subdirectory for \(fileName) at \(subDir.path)")
            } catch {
                print("Failed to create subdirectory for \(fileName): \(error)")
            }
        }
        return subDir
    }
    
    // MARK: - Persistence Methods (UserDefaults)
    
    private let lastSelectedFileKey = "LastSelectedGameFileURL"
    
    /// Saves the last selected file URL to UserDefaults.
    private func saveLastSelectedFileURL(_ fileURL: URL) {
        UserDefaults.standard.set(fileURL.path, forKey: lastSelectedFileKey)
        print("Saved last selected game file URL: \(fileURL.path)")
    }
    
    /// Retrieves the last selected file URL from UserDefaults.
    func retrieveLastSelectedFileURL() -> URL? {
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
    
    // MARK: - Route Setup
    
    /// Sets up all necessary routes for the server.
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
    
    /// Sets up the route for serving the selected file.
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
    
    /// Sets up routes for loading and saving game data.
    private func setupGameDataRoutes() {
        // Load game data (GET request)
        server["/load"] = { [weak self] request in
            guard let self = self, let savedGameData = self.savedGameData, let fileURL = self.currentFile else {
                print("Error: No game data or current file to load.")
                return .notFound
            }
            print("Serving saved game data for file: \(fileURL.lastPathComponent))")
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted // For readability
                let jsonData = try encoder.encode(savedGameData)
                return .raw(200, "application/json", [:], { writer in
                    try writer.write(jsonData)
                })
            } catch {
                print("Error encoding game data: \(error)")
                return .internalServerError
            }
        }
        
        // Endpoint to update game data (POST request)
        server.POST["/save"] = { [weak self] request in
            guard let self = self, let fileURL = self.currentFile else { return .internalServerError }
            do {
                let body = request.body // Direct assignment since request.body is non-optional
                
                if !body.isEmpty { // Optional: Check if the body is not empty
                    let decoder = JSONDecoder()
                    let newGameData = try decoder.decode(GameData.self, from: Data(body))
                    DispatchQueue.main.async {
                        self.savedGameData = newGameData
                    }
                    print("Received and updated game data for file \(fileURL.lastPathComponent): \(newGameData)")
                    return .ok(.text("Game data saved successfully."))
                } else {
                    print("No body in POST /save request.")
                    return .badRequest(nil)
                }
            } catch {
                print("Error decoding game data from request: \(error)")
                return .badRequest(nil)
            }
        }
    }
    
    // MARK: - HTML Generation
    
    /// Generates the HTML content for the Flash player.
    private func createFlashHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, initial-scale=1.0">
            <style>
                /* Reset default margins and paddings */
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                /* Ensure the body and html take full height */
                body, html {
                    height: 100%;
                    width: 100%;
                    background-color: #000;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    overflow: hidden;
                }
                /* Container for the Ruffle player with rounded corners */
                #flash-player {
                    width: 100%;
                    height: 100%;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    position: relative;
                    outline: none; /* Remove focus outline */
                    border-radius: 20px; /* Rounded edges */
                    overflow: hidden; /* Ensures content respects rounded edges */
                }
                /* Ensure the Ruffle player fills the container */
                #flash-player > .ruffle-container {
                    width: 100%;
                    height: 100%;
                    min-width: 100%;
                    max-width: 100%;
                    min-height: 100%;
                    max-height: 100%;
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
                    // Function to resize the player to match container's size
                    const resizePlayer = () => {
                        const containerWidth = container.clientWidth;
                        const containerHeight = container.clientHeight;
                        player.style.width = containerWidth + "px";
                        player.style.height = containerHeight + "px";
                        console.log("Resizing player with dimensions:", containerWidth, containerHeight);
                    };
                    // Initial resize
                    resizePlayer();
                    // Resize when the window size changes
                    window.addEventListener("resize", resizePlayer);
                    // Handle player load event
                    player.addEventListener("load", () => {
                        resizePlayer();
                        console.log("Player loaded, resizing...");
                        // Automatically load game data after the game is loaded
                        loadGameData().then(data => {
                            if (data) {
                                applyGameData(data);
                            }
                        });
                    });
                    container.focus();
                    // Optional: Log key events for debugging
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
                    const player = document.querySelector('.ruffle-container').shadowRoot.querySelector('canvas');
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
    
    /// Generates the HTML content for the simple clicker game.
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
                    background-color: #121212; /* Dark background */
                    color: #ffffff; /* White text for dark mode */
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
                    color: #bbbbbb; /* Lighter gray for instructions */
                }
            </style>
        </head>
        <body>
            <h1>Hit the "+" button and import your SWF files.</h1>
        </body>
        </html>
        """
    }
    
    // MARK: - Utility Methods
    
    /// Determines the MIME type based on the file extension.
    private func mimeType(for pathExtension: String) -> String {
        if let uti = UTType(filenameExtension: pathExtension),
           let mimeType = uti.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }
    
    /// Adds middleware to restrict access to localhost only.
    private func addLocalhostMiddleware() {
        server.middleware.append { request in
            // Check if the request is not from localhost
            if request.address != "127.0.0.1" && request.address != "::1" {
                print("Blocked request from \(request.address)")
                
                // Return a 403 Forbidden response
                return HttpResponse.raw(403, "Forbidden", ["Content-Type": "text/plain", "Connection": "close"]) { writer in
                    let message = "403 Forbidden: Access denied"
                    try writer.write([UInt8](message.utf8))
                }
            }
            return nil // Proceed normally for localhost requests
        }
    }
}
