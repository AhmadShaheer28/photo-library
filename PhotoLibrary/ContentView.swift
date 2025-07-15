//
//  ContentView.swift
//  PhotoLibrary
//
//  Created by Ahmad Shaheer on 15/07/2025.
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var photoManager = PhotoManager()
    @State private var totalScrollWidth: CGFloat = 0
    @State private var scrubberProgress: CGFloat = 0.0
    @State private var scrollOffset: CGFloat = 0.0
    @State private var currentIndex: Int = 0
    
    let rows = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main photo grid area
                mainPhotoGridView(geometry: geometry)
                
                // Line scrubber with integrated date
                lineScrubberView(geometry: geometry)
                    .frame(height: 145)
            }
        }
        .background(Color.black)
        .onAppear {
            if photoManager.hasPermission {
                photoManager.fetchPhotos()
            }
        }
    }
    
    private func mainPhotoGridView(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height - 155 // Account for scrubber only
        let photoSize = CGSize(
            width: (screenHeight) / 4, // 4 columns with spacing
            height: (screenHeight) / 4 // 4 rows with spacing
        )
        
        return Group {
            if photoManager.isLoading {
                loadingView
            } else if photoManager.photos.isEmpty {
                emptyStateView
            } else {
                photoGridScrollView(screenWidth: screenWidth, photoSize: photoSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text("Loading photos...")
                .foregroundColor(.white)
                .padding(.top)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Photos Found")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Your photo library appears to be empty or access was denied.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !photoManager.hasPermission {
                Button("Grant Permission") {
                    photoManager.requestPhotoLibraryPermission()
                }
                .foregroundColor(.blue)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func photoGridScrollView(screenWidth: CGFloat, photoSize: CGSize) -> some View {
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                print("GeometryReader appeared: \(geometry.size.width)")
                                totalScrollWidth = geometry.size.width
                            }
                    }
                    
                    LazyHGrid(rows: rows, spacing: 3) {
                        ForEach(Array(photoManager.photos.enumerated()), id: \.element.id) { index, photo in
                            PhotoView(
                                photoItem: photo,
                                size: photoSize,
                                photoManager: photoManager
                            )
                        }
                    }
                    .offset(x: -scrollOffset) // Apply smooth offset
                    
                }
                .onChange(of: scrubberProgress) { _, newProgress in
                    let clampedProgress = max(0, min(1, newProgress))
                    let targetScrollOffset = clampedProgress * totalScrollWidth
                    
                    print("Scrubber progress: \(clampedProgress), scroll offset: \(targetScrollOffset)")
                    
                    withAnimation(.easeInOut(duration: 0.1)) {
                        scrollOffset = targetScrollOffset
                    }
                    
                    // Update current photo index based on progress
                    let photoIndex = Int(clampedProgress * CGFloat(photoManager.photos.count - 1))
                    currentIndex = max(0, min(photoManager.photos.count - 1, photoIndex))
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            // Update scrubber progress when photo grid is dragged
                            let progress = abs(value.translation.width) / totalScrollWidth
                            let clampedProgress = max(0, min(1, progress))
                            
                            // Only update if the change is significant to avoid feedback loops
                            if abs(clampedProgress - scrubberProgress) > 0.01 {
                                print("Photo grid dragged: translation=\(value.translation.width), progress=\(clampedProgress)")
                                scrubberProgress = clampedProgress
                            }
                        }
                )
            }
        }
    }
    
    private func lineScrubberView(geometry: GeometryProxy) -> some View {
        let scrubberHeight: CGFloat = 60
        let lineWidth: CGFloat = 2
        let lineSpacing: CGFloat = 4
        let screenWidth = geometry.size.width
        
        print(screenWidth)
        
        // Calculate how many lines we need to represent the full scroll width
        let numberOfLines = max(1, photoManager.photos.count)
        
        return ZStack {
            // Background
            Color.black.opacity(0.1)
            
            // Fixed center line
            VStack {
                // Date above center line
                if !photoManager.photos.isEmpty && currentIndex < photoManager.photos.count {
                    Text(photoManager.photos[currentIndex].formattedDate)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                }
                
                // Fixed center line
                
            }
            
            // Scrollable scrubber lines
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: lineSpacing) {
                        // Add padding to center the scrubber
                        Spacer()
                            .frame(width: screenWidth / 2 - 5)
                        
                        ForEach(0..<numberOfLines, id: \.self) { lineIndex in
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: lineWidth, height: scrubberHeight * 0.6)
                                .id(lineIndex)
                        }
                        
                        // Add padding to center the scrubber
                        Spacer()
                            .frame(width: screenWidth / 2 - 5)
                    }
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            // Calculate progress based on drag position
                            let maxDragDistance = totalScrollWidth / 2
                            let dragProgress = value.translation.width / maxDragDistance
                            let newProgress = scrubberProgress + dragProgress
                            let clampedProgress = max(0, min(1, newProgress))
                            
                            print("Scrubber drag: translation=\(value.translation.width), progress=\(clampedProgress)")
                            scrubberProgress = clampedProgress
                        }
                        .onEnded { value in
                            // Finalize progress
                            let maxDragDistance = totalScrollWidth / 2
                            let dragProgress = value.translation.width / maxDragDistance
                            let newProgress = scrubberProgress + dragProgress
                            let clampedProgress = max(0, min(1, newProgress))
                            
                            print("Scrubber drag ended: final progress \(clampedProgress)")
                            withAnimation(.easeInOut(duration: 0.1)) {
                                scrubberProgress = clampedProgress
                            }
                        }
                )
            }
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 4, height: scrubberHeight * 0.6)
                .cornerRadius(2)
        }
        .frame(height: scrubberHeight)
    }
}

#Preview {
    ContentView()
}
