//
//  PhotoManager.swift
//  PhotoLibrary
//
//  Created by Ahmad Shaheer on 15/07/2025.
//

import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photos: [PhotoItem] = []
    @Published var isLoading = false
    @Published var hasPermission = false
    
    private let imageManager = PHCachingImageManager()
    
    init() {
        requestPhotoLibraryPermission()
    }
    
    func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.hasPermission = status == .authorized
                if self?.hasPermission == true {
                    self?.fetchPhotos()
                }
            }
        }
    }
    
    func fetchPhotos() {
        guard hasPermission else { return }
        
        isLoading = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var newPhotos: [PhotoItem] = []
        
        fetchResult.enumerateObjects { [weak self] asset, index, _ in
            let photoItem = PhotoItem(asset: asset, index: index)
            newPhotos.append(photoItem)
        }
        
        DispatchQueue.main.async {
            self.photos = newPhotos
            self.isLoading = false
        }
    }
    
    func getThumbnail(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    func getFullImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}

struct PhotoItem: Identifiable {
    let id = UUID()
    let asset: PHAsset
    let index: Int
    
    var creationDate: Date? {
        asset.creationDate
    }
    
    var formattedDate: String {
        guard let date = creationDate else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM 'yy"
        return formatter.string(from: date)
    }
    
    var monthYear: String {
        guard let date = creationDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
} 