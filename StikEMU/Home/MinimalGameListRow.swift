//
//  MinimalGameListRow.swift
//  StikEMU
//
//  Created by Stephen on 10/11/24.
//


import SwiftUI

struct MinimalGameListRow: View {
    let file: URL
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30) // Smaller, cleaner icon
                .foregroundColor(isSelected ? .blue : .gray)
            
            VStack(alignment: .leading) {
                Text(file.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(file.pathExtension.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear) // Subtle highlight when selected
        .contentShape(Rectangle()) // Ensure tappable area covers full row
    }
}
