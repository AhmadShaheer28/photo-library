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
    @State private var zoomLevel: ZoomLevel = .medium // New zoom state
    @State private var showZoomIndicator = false // Zoom indicator state
    @State private var gridRefreshID = 0 // Force grid refresh
    @State private var currentPhotoSize: CGSize = .zero // Track current photo size
    @State private var isZooming = false // Track zoom state for smooth transitions
    
    // Zoom levels with corresponding columns
    enum ZoomLevel: Int, CaseIterable {
        case small = 2    // 2 columns
        case medium = 4   // 4 columns (default)
        case large = 8   // 8 columns
        
        var columns: Int { rawValue }
        var displayName: String { "\(rawValue) cols" }
    }
    
    var rows: [GridItem] {
        // Use computed property for immediate updates with consistent 1px spacing
        let columns = zoomLevel.columns
        // Explicitly create GridItems with 1px spacing to prevent any default spacing
        let gridItems = (0..<columns).map { _ in GridItem(.flexible(), spacing: 1) }
        // Ensure spacing is always 1px regardless of zoom level
        return gridItems
    }
    
    // Custom grid configuration to ensure 1px spacing
    func gridConfiguration(photoSize: CGSize) -> some View {
        LazyHGrid(rows: rows, spacing: 1) {
            ForEach(Array(photoManager.photos.enumerated()), id: \.element.id) { index, photo in
                PhotoView(
                    photoItem: photo,
                    size: photoSize,
                    photoManager: photoManager
                )
                .id(index)
                .scaleEffect(isZooming ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isZooming)
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Zoom instructions
                zoomInstructionsView
                
                // Main photo grid area
                mainPhotoGridView(geometry: geometry)
                
                // Line scrubber with integrated date
                Slider(value: $sliderValue, range: range, zoomLevel: zoomLevel, photos: photoManager.photos)
                .frame(height: 100)
                .onChange(of: photoManager.photos.count) { oldValue, newValue in
                    updateSliderRange()
                }
                .onChange(of: zoomLevel) { oldValue, newValue in
                    // Immediate slider update without animation for responsiveness
                    updateSliderRange()
                }
            }
        }
        .background(Color.white)
        .overlay(
            // Zoom indicator overlay
            zoomIndicatorOverlay
        )
        .onAppear {
            if photoManager.hasPermission {
                photoManager.fetchPhotos()
            }
        }
    }
    
    private func updateSliderRange() {
        let photosPerRow = zoomLevel.columns
        let totalColumns = max(1, (photoManager.photos.count + photosPerRow - 1) / photosPerRow)
        range = 0...(totalColumns - 1)
        
        // Ensure slider value is within new range
        if sliderValue > range.upperBound {
            sliderValue = range.upperBound
        }
    }
    
    private func mainPhotoGridView(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height * 0.81 // Account for scrubber and instructions
        let columns = zoomLevel.columns
        let photoSize = CGSize(
            width: (screenHeight) / CGFloat(columns), // Dynamic columns with spacing
            height: (screenHeight) / CGFloat(columns) // Dynamic rows with spacing
        )
        
//        lastCalculatedPhotoSize = photoSize
//        // Update current photo size immediately
//        if currentPhotoSize != photoSize {
//            currentPhotoSize = photoSize
//        }
        
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
        .id(zoomLevel.rawValue) // Only refresh on zoom level change
        .onAppear {
            if currentPhotoSize != photoSize {
                currentPhotoSize = photoSize
            }
        }
        .onChange(of: photoSize) { _,newSize in
            if currentPhotoSize != newSize {
                currentPhotoSize = newSize
            }
        }
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
    
    private var zoomInstructionsView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "hand.draw")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Pinch to zoom: \(zoomLevel.displayName)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    private func photoGridScrollView(screenWidth: CGFloat, photoSize: CGSize) -> some View {
        CustomScrollView(
            content: {
                gridConfiguration(photoSize: photoSize)
                    .id("grid-\(zoomLevel.rawValue)-\(gridRefreshID)") // Force refresh with spacing
            },
            onScroll: { offset in
                updateSliderFromScroll(offset: offset, photoSize: photoSize)
            },
            sliderValue: sliderValue,
            onSliderChange: { newValue in
                sliderValue = newValue
            },
            photoSize: photoSize,
            photoManager: photoManager,
            zoomLevel: zoomLevel,
            onZoomChange: { newZoomLevel in
                // Immediate state update for responsive feel
                isZooming = true
                zoomLevel = newZoomLevel
                withAnimation {
                    gridRefreshID += 1 // Force grid refresh
                }
                
                print("Zoom changed to: \(newZoomLevel.rawValue) columns, forcing 1px spacing")
                
                // Show zoom indicator briefly
                showZoomIndicator = true
                
                // Reset zooming state after a short delay
                DispatchQueue.main.async/*After(deadline: .now() + 0.3)*/ {
                    withAnimation {
                        isZooming = false
                    }
                }
                
                DispatchQueue.main.async/*After(deadline: .now() + 1.0)*/ {
                    withAnimation {
                        showZoomIndicator = false
                    }
                }
            }
        )
    }
    
    private func updateSliderFromScroll(offset: CGFloat, photoSize: CGSize) {
        // Don't update slider from scroll events - let user control it
        // This prevents the feedback loop completely
    }
    
    private var zoomIndicatorOverlay: some View {
        Group {
            if showZoomIndicator {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("\(zoomLevel.columns) columns")
                                .font(.caption)
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(color: .white.opacity(0.2), radius: 8)
                        
                        Spacer()
                    }
                    .padding(.bottom, 120) // Above the slider
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.3), value: showZoomIndicator)
            }
        }
    }
}

struct CustomScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    let onScroll: (CGFloat) -> Void
    let sliderValue: Int
    let onSliderChange: (Int) -> Void
    let photoSize: CGSize
    let photoManager: PhotoManager
    let zoomLevel: ContentView.ZoomLevel
    let onZoomChange: (ContentView.ZoomLevel) -> Void
    
    init(
        @ViewBuilder content: () -> Content,
        onScroll: @escaping (CGFloat) -> Void,
        sliderValue: Int,
        onSliderChange: @escaping (Int) -> Void,
        photoSize: CGSize,
        photoManager: PhotoManager,
        zoomLevel: ContentView.ZoomLevel,
        onZoomChange: @escaping (ContentView.ZoomLevel) -> Void
    ) {
        self.content = content()
        self.onScroll = onScroll
        self.sliderValue = sliderValue
        self.onSliderChange = onSliderChange
        self.photoSize = photoSize
        self.photoManager = photoManager
        self.zoomLevel = zoomLevel
        self.onZoomChange = onZoomChange
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll, onSliderChange: onSliderChange, photoManager: photoManager, onZoomChange: onZoomChange)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isPagingEnabled = false
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        context.coordinator.scrollView = scrollView
        context.coordinator.hostingController = hostingController
        context.coordinator.photoSize = photoSize
        context.coordinator.zoomLevel = zoomLevel
        
        // Add pinch gesture recognizer
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinchGesture(_:)))
        scrollView.addGestureRecognizer(pinchGesture)
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onScroll = onScroll
        context.coordinator.onSliderChange = onSliderChange
        context.coordinator.photoSize = photoSize
        context.coordinator.zoomLevel = zoomLevel
        context.coordinator.onZoomChange = onZoomChange
        
        // Handle slider changes - always scroll when slider changes
        if context.coordinator.lastSliderValue != sliderValue {
            context.coordinator.lastSliderValue = sliderValue
            context.coordinator.scrollToSliderValue(sliderValue)
        }
        
        // Handle zoom level changes efficiently
        if context.coordinator.lastZoomLevel != zoomLevel {
            context.coordinator.lastZoomLevel = zoomLevel
            // Update content immediately
            context.coordinator.hostingController?.rootView = content
        } else {
            // Only update content if zoom level hasn't changed
            context.coordinator.hostingController?.rootView = content
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var onScroll: (CGFloat) -> Void
        var onSliderChange: (Int) -> Void
        var onZoomChange: (ContentView.ZoomLevel) -> Void
        weak var scrollView: UIScrollView?
        weak var hostingController: UIHostingController<Content>?
        var lastSliderValue: Int = 0
        var photoSize: CGSize = .zero
        var zoomLevel: ContentView.ZoomLevel = .medium
        var lastZoomLevel: ContentView.ZoomLevel = .medium
        let photoManager: PhotoManager
        var isProgrammaticScroll = false
        
        // Zoom gesture tracking
        private var initialZoomLevel: ContentView.ZoomLevel = .medium
        private var lastScale: CGFloat = 1.0
        
        init(onScroll: @escaping (CGFloat) -> Void, onSliderChange: @escaping (Int) -> Void, photoManager: PhotoManager, onZoomChange: @escaping (ContentView.ZoomLevel) -> Void) {
            self.onScroll = onScroll
            self.onSliderChange = onSliderChange
            self.photoManager = photoManager
            self.onZoomChange = onZoomChange
        }
        
        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                initialZoomLevel = zoomLevel
                lastScale = gesture.scale
                
                
            case .changed:
                let scale = gesture.scale / lastScale
                let scaleThreshold: CGFloat = 1.15 // Lower threshold for more responsive zoom
                
                if scale > scaleThreshold {
                    // Zoom in
                    if let currentIndex = ContentView.ZoomLevel.allCases.firstIndex(of: zoomLevel),
                       currentIndex < ContentView.ZoomLevel.allCases.count - 1 {
                        let newZoomLevel = ContentView.ZoomLevel.allCases[currentIndex + 1]
                        if newZoomLevel != zoomLevel {
                            zoomLevel = newZoomLevel
                            onZoomChange(newZoomLevel)
                            lastScale = gesture.scale
                            
                            // Light haptic feedback for better responsiveness
//                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
//                            impactFeedback.impactOccurred()
                        }
                    }
                } else if scale < 1.0 / scaleThreshold {
                    // Zoom out
                    if let currentIndex = ContentView.ZoomLevel.allCases.firstIndex(of: zoomLevel),
                       currentIndex > 0 {
                        let newZoomLevel = ContentView.ZoomLevel.allCases[currentIndex - 1]
                        if newZoomLevel != zoomLevel {
                            zoomLevel = newZoomLevel
                            onZoomChange(newZoomLevel)
                            lastScale = gesture.scale
                            
//                            // Light haptic feedback for better responsiveness
//                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
//                            impactFeedback.impactOccurred()
                        }
                    }
                }
                
            case .ended, .cancelled:
                // Reset scale tracking
                lastScale = 1.0
                
            default:
                break
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Only update slider from user scroll, not programmatic scroll
            if isProgrammaticScroll { return }
            
            let offset = scrollView.contentOffset.x
            let screenWidth = UIScreen.main.bounds.width
            let totalColumns = max(1, (photoManager.photos.count + zoomLevel.columns - 1) / zoomLevel.columns)
            
            // Calculate progress based on scroll position
            let contentWidth = scrollView.contentSize.width
            let maxScrollOffset = max(0, contentWidth - screenWidth)
            let progress = maxScrollOffset > 0 ? offset / maxScrollOffset : 0
            
            // Map progress to slider value
            let newSliderValue = Int(round(progress * CGFloat(totalColumns - 1)))
            let clampedValue = max(0, min(newSliderValue, totalColumns - 1))
            
            // Only update if the value actually changed
            if clampedValue != lastSliderValue {
                lastSliderValue = clampedValue
                onSliderChange(clampedValue)
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // No action needed - slider controls scroll only
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            // No action needed - slider controls scroll only
        }
        
        func scrollToSliderValue(_ value: Int) {
            guard let scrollView = scrollView else { return }
            
            isProgrammaticScroll = true
            
            // Simple approach: map slider value directly to scroll position
            let totalColumns = max(1, (photoManager.photos.count + zoomLevel.columns - 1) / zoomLevel.columns)
            let progress = CGFloat(value) / CGFloat(max(1, totalColumns - 1))
            
            // Calculate scroll range
            let contentWidth = scrollView.contentSize.width
            let screenWidth = scrollView.bounds.width
            let maxScrollOffset = max(0, contentWidth - screenWidth)
            
            // Map progress to scroll offset
            let targetOffset = progress * maxScrollOffset
            
            print("Slider value: \(value), Total columns: \(totalColumns), Progress: \(progress), Max scroll: \(maxScrollOffset), Target offset: \(targetOffset)")
            
            scrollView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: true)
            
            // Reset flag after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isProgrammaticScroll = false
            }
        }
    }
}

#Preview {
    ContentView()
}

