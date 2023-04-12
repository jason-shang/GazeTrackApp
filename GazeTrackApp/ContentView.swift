//
//  ContentView.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 03.01.23.
//

import SwiftUI
import Vision

struct ContentView: View {
    
    @EnvironmentObject var faceDetector: FaceDetector
    @EnvironmentObject var captureSession: CaptureSession
    @Binding var recording: Bool
    
    @State var faceBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @State var leftEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @State var rightEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    // real video preview
    var body: some View {
        ZStack {
            if recording {
                recordingView()
            }
            Button(action: {
                recording.toggle()
                if recording {
                    captureSession.setup()
                    captureSession.start()
                    faceDetector.startDataCollection()
                } else {
                    captureSession.stop()
                    if faceDetector.framesCache.count > 0 {
                        faceDetector.saveFramesToDisk()
                    }
                    faceDetector.checkData()
                    let _ = print("leftEyeXs: \(String(describing: faceDetector.lEyeXs))")
                    let _ = print("leftEyeYs: \(String(describing: faceDetector.lEyeYs))")
                    let _ = print("faceBoxXs: \(String(describing: faceDetector.faceXs))")
                    let _ = print("faceBoxYs: \(String(describing: faceDetector.faceYs))")
                    // export data (could refactor the faceDetector.framesCache.count into here)
                }
            }) {
                Text(recording ? "Stop" : "Start")
            }
        }
        
    }
    
    @ViewBuilder
    func recordingView() -> some View {
        // note: I forced the ZStack to take up the entire screen to make sure that the eye bounding boxes, which are converted to image coordinates using the UIScreen device dimensions (represents the size of the entire screen) in FaceDetector.swift, are properly drawn onto the current view canvas (if not taking up entire screen, the bounding boxes will be shifted down a bit)
        // MARK: check if the bounding boxes should be defined with regards to the entire UIScreen or the current view (in other words, are the image frames' sizes the same as the device screen size?) when we have access to data
        ZStack {
            cameraView()
//            VStack {
//                qualityView()
//                Spacer()
//            }
//            VStack {
//                Spacer()
//                positionView()
//            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .onChange(of: faceDetector.landmarks) { landmarks in
             // check VNFaceLandmarks2D for more documentation about landmarks - https://developer.apple.com/documentation/vision/vnfacelandmarks2d
//            guard let leftEye = landmarks?.leftEye else { return }
            
            self.faceBoundingBox = faceDetector.faceBoundingBox
            self.leftEyeBoundingBox = faceDetector.leftEyeBoundingBox
            self.rightEyeBoundingBox = faceDetector.rightEyeBoundingBox
        }
    }
    
    @ViewBuilder
    func cameraView() -> some View {
        if let captureSession = captureSession.captureSession {
            CameraView(captureSession: captureSession)
                .overlay(
                    GeometryReader { geometry in
                        // face bounding box
                        Rectangle()
                            .path(in: self.faceBoundingBox)
                            .stroke(Color.red, lineWidth: 2.0)

                        // eye bounding boxes
                        Rectangle()
                            .path(in: self.leftEyeBoundingBox)
                            .stroke(Color.red, lineWidth: 2.0)
                        
                        Rectangle()
                            .path(in: self.rightEyeBoundingBox)
                            .stroke(Color.red, lineWidth: 2.0)
                        
                        // CGRect origin points
                        Circle().fill(Color.green).frame(width: 3, height: 3).position(faceDetector.leftEyeBoundingBox.origin)
                        Circle().fill(Color.green).frame(width: 3, height: 3).position(faceDetector.rightEyeBoundingBox.origin)
                        
                        // display all 76 face landmarks points
//                        ForEach(self.allPoints, id: \.self) { point in
//                            let vectoredPoint = vector2(Float(point.x),Float(point.y))
//
//                            let vnImagePoint = VNImagePointForFaceLandmarkPoint(
//                                vectoredPoint,
//                                faceDetector.normalizedFace,
//                                Int(geometry.size.width),
//                                Int(geometry.size.height))
//
//                            let imagePoint = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y)
//
//                            Circle().fill(Color.green).frame(width: 3, height: 3).position(imagePoint)
//                        }
                    })
        } else {
            Text("Preparing Capture Session ...")
        }
    }
    
    @ViewBuilder
    func qualityView() -> some View {
        HStack {
            Text(String(format: "Face Capture Quality: %.2f", faceDetector.faceCaptureQuality))
            Spacer()
        }.padding().background(Color.gray)
    }
    
    @ViewBuilder
    func positionView() -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
            ],
            alignment: .leading,
            spacing: 0,
            pinnedViews: [],
            content: {
                Text(String(format: "Pitch: %.2f", faceDetector.pitch))
                Text(String(format: "Roll: %.2f", faceDetector.roll))
                Text(String(format: "Yaw: %.2f", faceDetector.yaw))
            }).padding().background(Color.gray)
    }
    
    // ===================== test model deployment on mobile =====================
  
//    @ViewBuilder
//    func imagePredictorView() -> some View {
//        Text(String(describing: predictImage()))
//    }
//
//    func predictImage() -> [NSNumber] {
//        var inferencer = ImagePredictor()
//        var pixelBuffer = [Float32]()
//        if let image = UIImage(named: "00002__00000") {
//            let resizedImage = image.resized(to: CGSize(width: CGFloat(VideoInputConstants.inputWidth), height: CGFloat(VideoInputConstants.inputHeight)))
//
//            guard let frameBuffer = resizedImage.normalized() else { return [] }
//            pixelBuffer += frameBuffer
//        }
//
//        guard let predictions = inferencer.module.predict(image: &pixelBuffer) else {
//            return []
//        }
//
//        return predictions
//    }
  
  // =============================================================================
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.x)
        hasher.combine(self.y)
    }
}
