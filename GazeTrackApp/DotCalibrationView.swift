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
            CGPoint(x: deviceWidth/4, y: 4*deviceHeight/9),
            CGPoint(x: 3*deviceWidth/4, y: 3*deviceHeight/5),
            CGPoint(x: 6*deviceWidth/7, y: deviceHeight/2),
            CGPoint(x: 3*deviceWidth/8, y: 2*deviceHeight/7),
            CGPoint(x: deviceWidth/3, y: deviceHeight/2)
        ]
        
        for (index, coordinate) in coordinates.enumerated() {
            dispatchGroup.enter()
            let interval = Double(index) * 3
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                position = coordinate
                faceDetector.curDotNum = index
                faceDetector.curDotX = coordinate.x
                faceDetector.curDotY = coordinate.y
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
