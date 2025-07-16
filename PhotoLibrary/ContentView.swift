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
    @State var sliderValue: Int = 0
    @State var range: ClosedRange<Int> = 0...1
    
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
                Slider(value: $sliderValue, range: range)
                .frame(height: 100)
                .onChange(of: photoManager.photos.count) { oldValue, newValue in
                    range = 0...(newValue - 1)
                }
                
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
        let screenHeight = geometry.size.height - 105 // Account for scrubber only
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
                    LazyHGrid(rows: rows, spacing: 3) {
                        ForEach(Array(photoManager.photos.enumerated()), id: \.element.id) { index, photo in
                            PhotoView(
                                photoItem: photo,
                                size: photoSize,
                                photoManager: photoManager
                            )
                            .id(index)
                        }
                    }
                    
                    
                }
                .onChange(of: sliderValue) { _, newProgress in
                    withAnimation(.interactiveSpring) {
                        proxy.scrollTo(newProgress, anchor: .leading)
                    }
                }
                
            }
        }
    }
    
}

#Preview {
    ContentView()
}
