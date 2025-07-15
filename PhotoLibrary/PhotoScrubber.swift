//
//  PhotoScrubber.swift
//  PhotoLibrary
//
//  Created by Ahmad Shaheer on 15/07/2025.
//

import SwiftUI
import Photos

struct PhotoScrubber: View {
    let photos: [PhotoItem]
    @ObservedObject var photoManager: PhotoManager
    @Binding var currentIndex: Int
    let scrubberHeight: CGFloat = 60
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoView(
                            photoItem: photo,
                            size: CGSize(width: scrubberHeight, height: scrubberHeight),
                            photoManager: photoManager
                        )
                        .id(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentIndex = index
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    currentIndex == index ? Color.blue : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: scrubberHeight)
            .background(Color.black.opacity(0.1))
            .onChange(of: currentIndex) { _,newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
} 
