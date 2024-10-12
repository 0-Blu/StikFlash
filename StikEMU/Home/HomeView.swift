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

    // Path to save imported files
    private let saveDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImportedFiles", isDirectory: true)
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("")
                Text("StikEMU")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer().frame(height: 20) // Smaller padding

                // Imported Files List
                if importedFiles.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50) // Smaller icon
                            .foregroundColor(.gray)
                        Text("No files imported yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Minimalistic ScrollView for file list
                    ScrollView {
                        HStack{
                            Text("Flash Games:")
                                .fontWeight(.bold)
                            Spacer()
                        }
                        VStack(spacing: 1) { // Very small spacing to mimic thin dividers
                            ForEach(importedFiles, id: \.self) { file in
                                MinimalGameListRow(file: file, isSelected: selectedFile == file)
                                    .onTapGesture {
                                        withAnimation {
                                            selectedFile = file
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()

                // Minimalistic Import Button with added bottom padding
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
                    .background(Color.gray.opacity(0.1)) // Minimalist background, no gradient
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
            .navigationBarHidden(true)
            .onAppear(perform: loadImportedFiles)
        }
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
