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
import SwiftUI

class FaceDetector: NSObject, ObservableObject {
    
    @Published var faceCaptureQuality: Float = 0.0
    
    @Published var allPoints = [CGPoint]()
    @Published var rightEyebrowPts = [CGPoint]()
    @Published var originPts = [CGPoint]()
    
    // relative to top left corner of full frame; will be in image/device coordinates
    @Published var faceBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @Published var normalizedFace = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    // relative to top-left corner of face bounding box (image/device coordinates)
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
        
        DispatchQueue.main.async {
            guard
                let results = request.results as? [VNFaceObservation],
                let result = results.first else { return }
            
            self.processFaceObservationResult(result: result)
        }
    }
    
    func processFaceObservationResult(result: VNFaceObservation) {
        // get device bounds
        let bounds = UIScreen.main.bounds
        let deviceWidth = Int(bounds.size.width)
        let deviceHeight = Int(bounds.size.height)

        // get face bounding box in image coordinates
        self.faceBoundingBox = VNImageRectForNormalizedRect(result.boundingBox, deviceWidth, deviceHeight)
        
        // MARK: for debugging purposes
        self.normalizedFace = result.boundingBox
        
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
        
        guard let allPoints = self.landmarks?.allPoints else { return }
        self.allPoints = allPoints.normalizedPoints
        let leftEyebrowPts = Array([leftEyebrow.normalizedPoints[3], leftEyebrow.normalizedPoints[5]])
        let rightEyebrowPts = Array([rightEyebrow.normalizedPoints[5], rightEyebrow.normalizedPoints[3]])
        self.rightEyebrowPts = rightEyebrowPts
        
        // determine height of eye bounding box based on eye/face ratio
        // TODO: refine this proportion (average of all ratios in GazeCapture dataset?)
        let heightProportion = 4.0
        let widthProportion = 4.0
        let eyeBoundingBoxHeight = faceBoundingBox.height/heightProportion
        let eyeBoundingBoxWidth = faceBoundingBox.width/widthProportion
        
        self.leftEyeBoundingBox = makeEyeBoundingBox(eyebrowPts: leftEyebrowPts, faceBoundingBox: result.boundingBox, deviceWidth: deviceWidth, deviceHeight: deviceHeight, boxHeight: eyeBoundingBoxHeight, boxWidth: eyeBoundingBoxWidth)
        
        self.rightEyeBoundingBox = makeEyeBoundingBox(eyebrowPts: rightEyebrowPts, faceBoundingBox: result.boundingBox, deviceWidth: deviceWidth, deviceHeight: deviceHeight, boxHeight: eyeBoundingBoxHeight, boxWidth: eyeBoundingBoxWidth)
        
        if let captureQuality = result.faceCaptureQuality {
            self.faceCaptureQuality = captureQuality
        }
        
        // for debugging purposes: can delete after
        var originPts = [CGPoint]()
        for point in self.rightEyebrowPts {
            let vectoredPoint = vector2(Float(point.x), Float(point.y))
            let vnImagePoint = VNImagePointForFaceLandmarkPoint(
                vectoredPoint,
                result.boundingBox,
                deviceWidth,
                deviceHeight)

            let imagePoint = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y)
            let p1 = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y+faceBoundingBox.height/4)
            originPts.append(imagePoint)
            originPts.append(p1)
        }
        self.originPts = originPts
    }
    
    /// Make eye bounding box based on the eye landmark and heuristics (proportion relative to the face)
    /// - Parameters:
    ///   - eyebrowPts:
    ///   - faceBoundingBox: face bounding box in normalized coordinates
    ///   - deviceWidth: width
    ///   - deviceHeight: height
    ///   - boxHeight: desired height of eye bounding box (based on heuristics)
    ///   - boxWidth: desired width of eye bounding box (based on heuristics)
    /// - Returns: CGRect of eye bounding box in image coordinates
    func makeEyeBoundingBox(eyebrowPts: [CGPoint], faceBoundingBox: CGRect, deviceWidth: Int, deviceHeight: Int, boxHeight: CGFloat, boxWidth: CGFloat) -> CGRect {
        if (eyebrowPts.count == 0) {
            return CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        }
        
        // TODO: return invalid detection?
        assert(eyebrowPts.count == 2, "Don't have 2 eyebrow points!")
        
        let eyebrowLeft: CGPoint = eyebrowPts[0]
        let vectoredEyebrowLeft = vector2(Float(eyebrowLeft.x), Float(eyebrowLeft.y))

        // this will be the origin of the bounding box CGRect
        let vnImagePointLeft = VNImagePointForFaceLandmarkPoint(
            vectoredEyebrowLeft,
            faceBoundingBox,
            deviceWidth,
            deviceHeight)
        
        let eyebrowRight: CGPoint = eyebrowPts[1]
        let vectoredEyebrowRight = vector2(Float(eyebrowRight.x),Float(eyebrowRight.y))

        let vnImagePointRight = VNImagePointForFaceLandmarkPoint(
            vectoredEyebrowRight,
            faceBoundingBox,
            deviceWidth,
            deviceHeight)
    
         let width = vnImagePointRight.x - vnImagePointLeft.x // alternate method for calculating width
        
        let box = CGRect(x: vnImagePointLeft.x, y: vnImagePointLeft.y, width: width, height: boxHeight)
        print("image point: \(String(describing: vnImagePointLeft))")
        print("origin point: \(String(describing: box.origin))")
        
        return CGRect(x: vnImagePointLeft.x, y: vnImagePointLeft.y, width: width, height: boxHeight)
    }
    
    func updateSessionData() {
        // TODO: change this!
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
    }
}
