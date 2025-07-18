//
//  Slider.swift
//  PhotoLibrary
//
//  Created by Ahmad Shaheer on 15/07/2025.
//

import SwiftUI

struct Slider: View {
    
    @Binding var value: Int
    @State var tempValue: Int = 0
    @State var dragOffset: CGFloat = 0
    let range: ClosedRange<Int>
    let stepWidth: CGFloat = 10 // Increased spacing between bars
    let zoomLevel: ContentView.ZoomLevel // Add zoom level parameter
    let photos: [PhotoItem] // Add photos array
    
    // Get the date for the current column
    private var currentColumnDate: String {
        let photosPerRow = zoomLevel.columns
        let startIndex = tempValue * photosPerRow
//        let endIndex = min(startIndex + photosPerRow, photos.count)
        
        guard startIndex < photos.count else { return "No Photos" }
        
        // Get the first photo in the current column
        let firstPhotoInColumn = photos[startIndex]
        return firstPhotoInColumn.formattedDate
    }
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            let center = size.width / 2
          
            VStack(spacing: 0) {
                
                HStack{
                    Spacer()
                     Text(currentColumnDate)
                        .foregroundStyle(Color("app_blue"))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .padding(.top,10)
                .padding(.bottom,-20)
                
                // Scrubber bars - show exactly one bar per column
                ZStack {
                    ForEach(range, id: \.self) { tick in
                        let x = center + CGFloat(tick - value) * stepWidth + dragOffset
                        
                        VStack(spacing: 0) {
                            Spacer()
                            VStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(tick == tempValue ? Color("app_blue") : Color("app_blue").opacity(0.1))
                                    .frame(width: 2, height: tick == tempValue ? 21 : 11)
                                    .shadow(color: tick == tempValue ? .white.opacity(0.5) : .clear, radius: 2)
                                Spacer()
                            }
                            .frame(height: 25)

                        }
                        .position(x: x, y: size.height / 2 - 25)
                       
                    }
                 
                }
                
              
                Spacer()
            }
         
            .background(.white)
        }
        .padding(.horizontal,40)
        .onChange(of: value) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                tempValue = newValue
            }
        }
        .onChange(of: range) { oldValue, newValue in
            // Update tempValue when range changes to ensure it's valid
            if tempValue > newValue.upperBound {
                tempValue = newValue.upperBound
            }
        }
        .onChange(of: zoomLevel) { oldValue, newValue in
            // Reset tempValue when zoom level changes to ensure it's valid
            if tempValue > range.upperBound {
                tempValue = range.upperBound
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged({ gesture in
                    withAnimation(.interactiveSpring) {
                        let rawOffset = gesture.translation.width
                        let offsetSteps = rawOffset / stepWidth
                        var projected = CGFloat(value) - offsetSteps
                        let lower = CGFloat(range.lowerBound)
                        let upper = CGFloat(range.upperBound)
                        
                        if projected < lower {
                            let overshoot = lower - projected
                            projected = lower - log(overshoot + 1) * 2
                        } else if projected > upper {
                            let overshoot = projected - upper
                            projected = upper + log(overshoot + 1) * 2
                        }
                        
                        self.dragOffset = (CGFloat(value) - projected) * stepWidth
                        let rounded = Int(round(projected))
                        self.tempValue = rounded.clamped(to: range)
                        
                    }
                })
                .onEnded({ gesture in
                    let offsetSteps = gesture.translation.width / stepWidth
                    let finalValue = Int((CGFloat(value) - offsetSteps).rounded()).clamped(to: range)
                    withAnimation(.interactiveSpring) {
                        value = finalValue
                        tempValue = finalValue
                        dragOffset = .zero
                    }
                })
        )
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

//#Preview {
//    Slider(value: .constant(0), range: 0...60, zoomLevel: .medium, photos: <#[PhotoItem]#>)
//}
