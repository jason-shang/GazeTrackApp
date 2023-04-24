//
//  DotCalibrationView.swift
//  NeuroGaze
//
//  Created by Nicole Yu on 15/4/23.
//

import SwiftUI

struct DotCalibrationView: View {
    
    @EnvironmentObject var faceDetector: FaceDetector
    
    @State private var isDotVisible: Bool = false
    @State private var dotSize: CGFloat = 18.0
    @State private var position: CGPoint = CGPoint(x: 0, y: 0)
    
    let minDotSize: CGFloat = 18.0
    let maxDotSize: CGFloat = 50.0
    let pulseInterval = 0.3 // in seconds
    
    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(Color.green)
                .frame(width: dotSize, height: dotSize)
                .opacity(isDotVisible ? 1.0 : 0.0)
                .position(position)
                .onAppear() {
                    pulse()
                    updatePosition()
                }
        }
    }
    
    private func pulse() {
        withAnimation(.easeInOut(duration: pulseInterval)) {
            isDotVisible = true
            dotSize = maxDotSize
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + pulseInterval) {
            withAnimation(.easeInOut(duration: pulseInterval)) {
                isDotVisible = false
                dotSize = minDotSize
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + pulseInterval) {
                pulse()
            }
        }
    }
    
    private func updatePosition() {
        // get device bounds
        let bounds = UIScreen.main.bounds
        let deviceWidth = Int(bounds.size.width)
        let deviceHeight = Int(bounds.size.height)
        
        let dispatchGroup = DispatchGroup()
        
        let coordinates: [CGPoint] = [
            CGPoint(x: deviceWidth/3, y: deviceHeight/3),
            CGPoint(x: 2*deviceWidth/3, y: 2*deviceHeight/3)
        ]
        
        for (index, coordinate) in coordinates.enumerated() {
            dispatchGroup.enter()
            let interval = Double(index) * 4
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                position = coordinate
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            print("All tasks complete")
        }
        
    }
}

struct DotCalibration_Previews: PreviewProvider {
    static var previews: some View {
        DotCalibrationView()
    }
}
