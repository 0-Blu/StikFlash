//
//  FlashEmulatorServer.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import Foundation
import Swifter
import UniformTypeIdentifiers

class FlashEmulatorServer: ObservableObject {
    let server = HttpServer()
    private var currentFile: URL? = nil
    var port: UInt16 = 8080  // Changed from 'private' to 'internal' (default)

    init() {
        setupRoutes()
        addLocalhostMiddleware()
        randomizePort()
    }

    func start() {
        do {
            // Start the server on a randomized port with IPv4
            try server.start(port, forceIPv4: true)
            print("Server has started on localhost (port = \(port))")
        } catch {
            print("Server start error: \(error)")
        }
    }

    func stop() {
        server.stop()
    }

    func loadFile(fileURL: URL) {
        currentFile = fileURL
        setupFileRoutes()
    }

    private func setupRoutes() {
        // Serve the main HTML page
        server["/"] = { [weak self] request in
            return .ok(.html(self?.createHTML() ?? ""))
        }

        // Default file route
        setupFileRoutes()
    }

    private func setupFileRoutes() {
        server["/file"] = { [weak self] request in
            guard let self = self, let fileURL = self.currentFile else {
                return .notFound
            }
            do {
                let fileData = try Data(contentsOf: fileURL)
                let mimeType = self.mimeType(for: fileURL.pathExtension)
                return .raw(200, mimeType, [:], { writer in
                    try writer.write(fileData)
                })
            } catch {
                print("Error loading file: \(error.localizedDescription)")
                return .notFound
            }
        }
    }

    private func createHTML() -> String {
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

                    // Optional: Adjust scaling based on file dimensions (if applicable)
                    player.addEventListener("load", () => {
                        const fileWidth = player.stage.width;
                        const fileHeight = player.stage.height;
                        const scaleX = container.clientWidth / fileWidth;
                        const scaleY = container.clientHeight / fileHeight;
                        const scale = Math.min(scaleX, scaleY);
                        player.style.transform = `scale(${scale})`;
                    });

                    // Focus the container to ensure it can receive key events
                    container.focus();

                    // Listen for key events
                    document.addEventListener('keydown', function(event) {
                        console.log('Key pressed (keydown):', event.key, event.keyCode, event.code);
                    });
                    document.addEventListener('keyup', function(event) {
                        console.log('Key pressed (keyup):', event.key, event.keyCode, event.code);
                    });
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
            // Only allow requests from localhost (127.0.0.1) or IPv6 localhost (::1)
            if request.address != "127.0.0.1" && request.address != "::1" {
                print("Blocked request from \(request.address)")
                return .forbidden
            }
            return nil
        }
    }

    private func randomizePort() {
        // Randomize the port to avoid predictable port scanning, restricted to UInt16 range
        port = UInt16.random(in: 8000...9000)
        print("Server will start on randomized port: \(port)")
    }
}
