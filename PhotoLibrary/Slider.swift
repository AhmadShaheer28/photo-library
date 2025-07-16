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
    let stepWidth: CGFloat = 10
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            let center = size.width / 2
            
            ForEach(range, id: \.self) { tick in
                let x = center + CGFloat(tick - value) * stepWidth + dragOffset
                
                VStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tick == tempValue ? .white : .gray.opacity(0.4))
                        .frame(width: tick == tempValue ? 4 : 2, height: tick == tempValue ? 30 : 15)
                }
                .position(x: x, y: size.height / 2)
            }
            .contentShape(.rect)
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

#Preview {
    Slider(value: .constant(0), range: 0...60)
}
