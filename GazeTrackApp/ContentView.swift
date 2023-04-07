//
//  ContentView.swift
//  Shared
//
//  Created by Jason Shang on 03.01.23.
//

import SwiftUI
import Vision

struct ContentView: View {
    
    @EnvironmentObject var faceDetector: FaceDetector
    @EnvironmentObject var captureSession: CaptureSession
    @Binding var recording: Bool
    
    @State var allPoints = [CGPoint]()
    @State var leftEyebrowPts = [CGPoint]()
    @State var rightEyebrowPts = [CGPoint]()
    @State var originPts = [CGPoint]()
    
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
                } else {
                    captureSession.stop()
                }
            }) {
                Text(recording ? "Stop" : "Start")
            }
        }
        
    }
    
    @ViewBuilder
    func recordingView() -> some View {
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
//            guard let leftEye = landmarks?.leftEye else { return }
//            guard let rightEye = landmarks?.rightEye else { return }
//            guard let leftPupil = landmarks?.leftPupil else { return }
//            guard let rightPupil = landmarks?.rightPupil else { return }

//            guard let allPoints = landmarks?.allPoints else { return }
            guard let leftEyebrow = landmarks?.leftEyebrow else { return }
            guard let rightEyebrow = landmarks?.rightEyebrow else { return }

            let leftEyebrowPts = Array([leftEyebrow.normalizedPoints[3], leftEyebrow.normalizedPoints[5]])
            let rightEyebrowPts = Array([rightEyebrow.normalizedPoints[5], rightEyebrow.normalizedPoints[3]])

            self.allPoints = faceDetector.allPoints
            self.leftEyebrowPts = leftEyebrowPts
            self.rightEyebrowPts = faceDetector.rightEyebrowPts
            self.originPts = faceDetector.originPts
            
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
                        
                        // display right eye bounding box as individual points
                        ForEach(self.rightEyebrowPts, id: \.self) { point in
                            let vectoredPoint = vector2(Float(point.x),Float(point.y))

                            let vnImagePoint = VNImagePointForFaceLandmarkPoint(
                                vectoredPoint,
                                faceDetector.normalizedFace,
                                Int(geometry.size.width),
                                Int(geometry.size.height))

                            let imagePoint = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y)
                            let p1 = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y+faceBoundingBox.height/4)

                            Circle().fill(Color.green).frame(width: 3, height: 3).position(imagePoint)
                            Circle().fill(Color.green).frame(width: 3, height: 3).position(p1)
                        }
                        
                        // display left eye bounding box as individual points
                        ForEach(self.leftEyebrowPts, id: \.self) { point in
                            let vectoredPoint = vector2(Float(point.x),Float(point.y))

                            let vnImagePoint = VNImagePointForFaceLandmarkPoint(
                                vectoredPoint,
                                faceDetector.normalizedFace,
                                Int(geometry.size.width),
                                Int(geometry.size.height))

                            let imagePoint = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y)
                            let p1 = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y+faceBoundingBox.height/4)

                            Circle().fill(Color.green).frame(width: 3, height: 3).position(imagePoint)
                            Circle().fill(Color.green).frame(width: 3, height: 3).position(p1)
                        }
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
    
    func makeEyeBoundingBox(eyebrowPts: [CGPoint], faceBoundingBox: CGRect, deviceWidth: Int, deviceHeight: Int, boxHeight: CGFloat, boxWidth: CGFloat) -> CGRect {
        if (eyebrowPts.count == 0) {
            return CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        }
        
        // TODO: return invalid detection?
        assert(eyebrowPts.count == 2, "Don't have 2 eyebrow points!")
        
        let eyebrowLeft: CGPoint = eyebrowPts[0]
        let vectoredEyebrowLeft = vector2(Float(eyebrowLeft.x),Float(eyebrowLeft.y))

        // this will be the origin of the bounding box CGRect
        let vnImagePointLeft = VNImagePointForFaceLandmarkPoint(
            vectoredEyebrowLeft,
            faceBoundingBox,
            deviceWidth,
            deviceHeight)
        
//        let eyebrowRight: CGPoint = eyebrowPts[1]
//        let vectoredEyebrowRight = vector2(Float(eyebrowRight.x),Float(eyebrowRight.y))
//        let vnImagePointRight = VNImagePointForFaceLandmarkPoint(
//            vectoredEyebrowRight,
//            faceBoundingBox,
//            deviceWidth,
//            deviceHeight)
    
        // let width = vnImagePointRight.x - vnImagePointLeft.x // alternate method for calculating width
        
        return CGRect(x: vnImagePointLeft.x, y: vnImagePointLeft.y, width: boxWidth, height: boxHeight)
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
