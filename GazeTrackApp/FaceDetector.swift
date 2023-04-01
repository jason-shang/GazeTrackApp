//
//  FaceDetector.swift
//  BiometricPhoto
//
//  Created by Jason Shang on 2/16/23.
//

import Foundation
import Vision
import UIKit
import Combine
import AVFoundation

class FaceDetector: NSObject, ObservableObject {
    
    @Published var faceCaptureQuality: Float = 0.0
    
    // relative to top left corner of full frame (need to convert from normalized to device coordinates
    @Published var faceBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    // relative to top-left corner of face bounding box (normalized coordinates! no need to convert to device coordinates)
    @Published var leftEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @Published var rightEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    @Published var landmarks: VNFaceLandmarks2D?
    
    @Published var yaw: Float = 0
    @Published var roll: Float = 0
    @Published var pitch: Float = 0
    
    private var sampleBuffer: CMSampleBuffer?
    
    // PassthroughSubject can both subscribe & broadcast;
    // here, subject receives new values of sampleBuffer from captureSession (see GazeTrackApp AppDelegate) and broadcasts that to downstream subscribers
    let subject = PassthroughSubject<CMSampleBuffer?, Never>()
    var cancellables = [AnyCancellable]()
    
    // MARK: data storage for current recording session
    var faceHeights: [Float] = []
    var faceWidths: [Float] = []
    var faceXs: [Float] = []
    var faceYs: [Float] = []
    var faceValids: [Int] = []
    
    var lEyeHeights: [Float] = []
    var lEyeWidths: [Float] = []
    var lEyeXs: [Float] = []
    var lEyeYs: [Float] = []
    var lEyeValids: [Int] = []
    
    var rEyeHeights: [Float] = []
    var rEyeWidths: [Float] = []
    var rEyeXs: [Float] = []
    var rEyeYs: [Float] = []
    var rEyeValids: [Int] = []
    
    var frameNames: [String] = []
    var frames: [CMSampleBuffer] = []
    var totalFrames: Int = 0
    var numFaceDetections: Int = 0
    var numEyeDetections: Int = 0
    var deviceName: String = "iPhone 13 Pro"
    
    override init() {
        super.init()
        subject.sink { sampleBuffer in
            self.sampleBuffer = sampleBuffer
            do {
                guard let sampleBuffer = sampleBuffer else {
                    return
                }
                try self.detect(sampleBuffer: sampleBuffer)
            } catch {
                print("Error has been thrown")
            }
            
        }.store(in: &cancellables)
    }
    
    /// Resets all face, eye, frame and device data; call when we are starting a new recording/experiment
    func startDataCollection() {
        self.faceHeights = []
        self.faceWidths = []
        self.faceXs = []
        self.faceYs = []
        self.faceValids = []
        
        self.lEyeHeights = []
        self.lEyeWidths = []
        self.lEyeXs = []
        self.lEyeYs = []
        self.lEyeValids = []
        
        self.rEyeHeights = []
        self.rEyeWidths = []
        self.rEyeXs = []
        self.rEyeYs = []
        self.rEyeValids = []
        
        self.frames = []
        self.totalFrames = 0
        self.numFaceDetections = 0
        self.numEyeDetections = 0
        self.deviceName = "iPhone 13 Pro" // account for other models later (can't just use UIDevice.current.model - doesn't give name)
    }
    
    func detect(sampleBuffer: CMSampleBuffer) throws {
        let handler = VNSequenceRequestHandler()
        
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest.init(completionHandler: handleRequests)
        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        
        let faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest.init(completionHandler: handleRequests)
        
        let faceRectanglesRequest = VNDetectFaceRectanglesRequest.init(completionHandler: handleRequests)
        faceRectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        DispatchQueue.global().async {
            do {
                try handler.perform([faceLandmarksRequest, faceCaptureQualityRequest, faceRectanglesRequest], on: sampleBuffer, orientation: .left)
            } catch {
                // don't do anything
            }
        }
        
    }
    
    /// Retrieves results of the face bounding box & landmarks detection request and assigns it to the FaceDetector member variables
    /// - Parameters:
    ///   - request: VNRequest
    ///   - error: Error
    func handleRequests(request: VNRequest, error: Error?) {
        var bounds = UIScreen.main.bounds
        var deviceWidth = Int(bounds.size.width)
        var deviceHeight = Int(bounds.size.height)
        
        DispatchQueue.main.async {
            guard
                let results = request.results as? [VNFaceObservation],
                let result = results.first else { return }
            
//            self.faceBoundingBox = VNImageRectForNormalizedRect(result.boundingBox, deviceWidth, deviceHeight)
            self.faceBoundingBox = result.boundingBox
            
            if let yaw = result.yaw,
               let pitch = result.pitch,
               let roll = result.roll {
                self.yaw = yaw.floatValue
                self.pitch = pitch.floatValue
                self.roll = roll.floatValue
            }
            
            if let landmarks = result.landmarks {
                self.landmarks = landmarks
            }
            
            guard let leftEyebrow = self.landmarks?.leftEyebrow else { return }
            guard let rightEyebrow = self.landmarks?.rightEyebrow else { return }

            self.leftEyeBoundingBox = self.makeEyeBoundingBox(eyebrowLeft: leftEyebrow.normalizedPoints[0], eyebrowRight: leftEyebrow.normalizedPoints[3], faceBoundingBox: self.faceBoundingBox)

            self.rightEyeBoundingBox = self.makeEyeBoundingBox(eyebrowLeft: rightEyebrow.normalizedPoints[0], eyebrowRight: rightEyebrow.normalizedPoints[3], faceBoundingBox: self.faceBoundingBox)
            
            if let captureQuality = result.faceCaptureQuality {
                self.faceCaptureQuality = captureQuality
            }
        }
    }
    
    func updateSessionData() {
        //let height =
        self.faceHeights
        self.faceWidths = []
        self.faceXs = []
        self.faceYs = []
        self.faceValids = []
        
        self.lEyeHeights = []
        self.lEyeWidths = []
        self.lEyeXs = []
        self.lEyeYs = []
        self.lEyeValids = []
        
        self.rEyeHeights = []
        self.rEyeWidths = []
        self.rEyeXs = []
        self.rEyeYs = []
        self.rEyeValids = []
        
        self.frames = []
        self.totalFrames = 0
        self.numFaceDetections = 0
        self.numEyeDetections = 0
    }
    
    /*
     * construct eye bounding box based on face/eye proportion (3.34 from GazeCapture subject 00002, frame 00000 -> 00002__00000.jpg)
     */
    func makeEyeBoundingBox(eyebrowLeft: CGPoint, eyebrowRight: CGPoint, faceBoundingBox: CGRect) -> CGRect {
        let proportion = 3.34
        let normalizedBoundingBox = CGRect(x: eyebrowLeft.x, y: eyebrowLeft.y, width: eyebrowRight.x - eyebrowLeft.x, height: faceBoundingBox.height/proportion)
        
//        // convert bounding box from normalized coordinates to coordinates of the original image (devie coordinates)
//        let imageCoordsBoundingBox = VNImageRectForNormalizedRect(normalizedBoundingBox, deviceWidth, deviceHeight)
        return normalizedBoundingBox
    }
    
    // crop to eyes using the min and max (just the eyes, makeEyeBoundingBox would make bigger rectangles that are more similar to GazeCapture)
    // UNUSED!
    func cropParts(partsPoints points: [CGPoint], horizontalSpacing hPadding:CGFloat, verticalSpacing vPadding:CGFloat, originalImage image:CIImage) -> CGRect {
        if let Minx = points.min(by: { a,b -> Bool in
            a.x < b.x
        }),
            let Miny = points.min(by: { a,b -> Bool in
                a.y < b.y
            }),
            let Maxx = points.max(by: { a,b -> Bool in
                a.x < b.x
            }),
            let Maxy = points.max(by: { a,b -> Bool in
                a.y < b.y
            }) {
            let partsWidth =  Maxx.x - Minx.x
            let partsHeight = Maxy.y - Miny.y
            let partsBox = CGRect(x: Minx.x - (partsWidth * hPadding), y: Miny.y - (partsHeight * vPadding), width: partsWidth + (partsWidth * hPadding * 2), height: partsHeight + (partsHeight * vPadding * 2))
            return partsBox
        } else {
            print("WARNING: Failed to make eye bounding boxes")
            return CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        }
    }
}

//extension CGPoint {
//    func convertToImagePoint(_ originalImage:CIImage,_ boundingBox:CGRect)->CGPoint {
//        let imageWidth = originalImage.extent.width
//        let imageHeight = originalImage.extent.height
//        let vectoredPoint = vector2(Float(self.x),Float(self.y))
//        let vnImagePoint = VNImagePointForFaceLandmarkPoint(vectoredPoint,boundingBox, Int(imageWidth), Int(imageHeight))
//        let imagePoint = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y)
//        return imagePoint
//    }
//}
