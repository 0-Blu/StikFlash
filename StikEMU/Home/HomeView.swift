//
//  HomeView.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var showFileImporter = false
    @State private var importedFiles: [URL] = []
    @Binding var selectedFile: URL?
    @Binding var isPresented: Bool // This binding controls whether the popover is shown

    // Path to save imported files
    private let saveDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImportedFiles", isDirectory: true)
    }()

    var body: some View {
        VStack(spacing: 20) {
            Text("StikEMU")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer().frame(height: 20) // Padding

            // Imported Files List
            if importedFiles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                    Text("No files imported yet.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // ScrollView for file list with increased height
                ScrollView {
                    VStack(spacing: 1) {
                        HStack {
                            Text("Flash Games:")
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)

                        VStack(spacing: 1) { // Very small spacing to mimic thin dividers
                            ForEach(importedFiles, id: \.self) { file in
                                MinimalGameListRow(file: file, isSelected: selectedFile == file)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedFile = file
                                            isPresented = false // Dismiss the popover when a game is selected
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(maxHeight: 400) // Adjust this to make the scroll area longer
                .padding(.horizontal)
            }

            Spacer()

            // Import File Button placed under the imported games
            Button(action: {
                withAnimation {
                    showFileImporter = true
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                    Text("Import File")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom, 20) // Added padding below the button
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result: result)
            }
        }
        .onAppear(perform: loadImportedFiles)
        .frame(minWidth: 300, minHeight: 500) // Adjust the popover's overall size
    }

    // File import handling logic
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

    // Load imported files
    private func loadImportedFiles() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: saveDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            importedFiles = files
        } catch {
            print("Error loading imported files: \(error.localizedDescription)")
        }
    }
}

struct MinimalGameListRow: View {
    var file: URL
    var isSelected: Bool

    var body: some View {
        HStack {
            Text(file.lastPathComponent)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}
