//
//  HomeView.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - HomeView for Importing Files and Displaying Game List
struct HomeView: View {
    @State private var showFileImporter = false
    @State private var importedFiles: [URL] = []
    @Binding var selectedFile: URL?
    @Binding var isPresented: Bool

    // Path to save imported files
    private let saveDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImportedFiles", isDirectory: true)
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                headerView // Calling the header view
                gameListView
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                handleFileImport(result: result)
            }
            .onAppear(perform: loadImportedFiles)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .padding()
        }
        .preferredColorScheme(.dark) // This forces dark mode
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("StikFlash")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Spacer()
            Button("Import") {
                showFileImporter = true
            }
            Button("Done") {
                isPresented = false
            }
            .padding()
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
    }

    // MARK: - Game List View
    private var gameListView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns(for: UIScreen.main.bounds.size), spacing: 16) {
                ForEach(importedFiles, id: \.self) { file in
                    GameListTile(file: file, isSelected: selectedFile == file)
                        .onTapGesture {
                            withAnimation {
                                selectedFile = file
                                isPresented = false // Dismiss the sheet when a game is selected
                            }
                        }
                }
            }
            .padding(.vertical, 10)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
    }

    // MARK: - Function to dynamically adjust the number of columns based on screen size
    private func gridColumns(for size: CGSize) -> [GridItem] {
        let numberOfColumns: Int
        if size.width > 1200 {
            numberOfColumns = 8
        } else if size.width > 1000 {
            numberOfColumns = 6
        } else if size.width > 800 {
            numberOfColumns = 5
        } else if size.width > 600 {
            numberOfColumns = 4
        } else {
            numberOfColumns = 3
        }

        return Array(repeating: GridItem(.flexible(), spacing: 16), count: numberOfColumns)
    }

    // MARK: - Load Imported Files
    private func loadImportedFiles() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: saveDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            importedFiles = files
        } catch {
            print("Error loading imported files: \(error.localizedDescription)")
        }
    }

    // MARK: - File Import Handling Logic
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true, attributes: nil)
                    let destinationURL = saveDirectory.appendingPathComponent(url.lastPathComponent)

                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        print("File already exists at destination: \(destinationURL.path)")
                        continue
                    }

                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        try FileManager.default.copyItem(at: url, to: destinationURL)
                        importedFiles.append(destinationURL)
                    } else {
                        print("Failed to access security scoped resource")
                    }
                } catch {
                    print("Error importing file: \(error.localizedDescription)")
                }
            }
        case .failure(let error):
            print("Failed to import file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Tile-style view for the game list in a grid layout
struct GameListTile: View {
    var file: URL
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.secondary)

            Text(file.lastPathComponent)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
        .cornerRadius(10)
    }
}
