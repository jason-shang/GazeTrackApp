//
//  FaceDetector.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 2/16/23.
//

import Foundation
import Vision
import UIKit
import Combine
import AVFoundation

class FaceDetector: NSObject, ObservableObject {
    
    private var captureSession: CaptureSession
    
    @Published var faceCaptureQuality: Float = 0.0
    
    // relative to top left corner of full frame; will be in image/device coordinates
    @Published var faceBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    // relative to top-left corner of face bounding box (image/device coordinates)
    @Published var leftEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @Published var rightEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    @Published var landmarks: VNFaceLandmarks2D?
    
    @Published var yaw: Float = 0
    @Published var roll: Float = 0
    @Published var pitch: Float = 0
    
    private var faceValid: Bool = true
    private var leftEyeValid: Bool = true
    private var rightEyeValid: Bool = true
    
    private var sampleBuffer: CMSampleBuffer?
    
    // PassthroughSubject can both subscribe & broadcast;
    // here, subject receives new values of sampleBuffer from captureSession (see GazeTrackApp AppDelegate) and broadcasts that to downstream subscribers
    let subject = PassthroughSubject<CMSampleBuffer?, Never>()
    var cancellables = [AnyCancellable]()
    
    // MARK: data storage for current recording session
    var faceHeights: [CGFloat] = []
    var faceWidths: [CGFloat] = []
    var faceXs: [CGFloat] = []
    var faceYs: [CGFloat] = []
    var faceValids: [Int] = []
    
    var lEyeHeights: [CGFloat] = []
    var lEyeWidths: [CGFloat] = []
    var lEyeXs: [CGFloat] = []
    var lEyeYs: [CGFloat] = []
    var lEyeValids: [Int] = []
    
    var rEyeHeights: [CGFloat] = []
    var rEyeWidths: [CGFloat] = []
    var rEyeXs: [CGFloat] = []
    var rEyeYs: [CGFloat] = []
    var rEyeValids: [Int] = []
    
    var frameNames: [String] = []
    var framesCache: [UIImage] = []
    let maxFramesCacheSize: Int = 30
    var numFaceDetections: Int = 0
    var numEyeDetections: Int = 0
    var deviceName: String = "iPhone 13 Pro"
    
    var frameNum: Int = 0
    
    init(captureSession: CaptureSession) {
        self.captureSession = captureSession
        super.init()
        subject.sink { sampleBuffer in
            self.sampleBuffer = sampleBuffer
            do {
                guard let sampleBuffer = sampleBuffer else {
                    return
                }
                
                try self.detect(sampleBuffer: sampleBuffer)
                
                captureSession.sessionData!.updateSessionData(faceBoundingBox: self.faceBoundingBox, leftEyeBoundingBox: self.leftEyeBoundingBox, rightEyeBoundingBox: self.rightEyeBoundingBox, faceCaptureQuality: self.faceCaptureQuality, frame: self.sampleBuffer!, faceValid: self.faceValid, leftEyeValid: self.leftEyeValid, rightEyeValid: self.rightEyeValid)
            } catch {
                print("Error has been thrown")
            }
            
        }.store(in: &cancellables)
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
                // note: the completion handlers assigned to each of these requests will have access to the results of all these requests,
                try handler.perform([faceLandmarksRequest, faceCaptureQualityRequest, faceRectanglesRequest], on: sampleBuffer, orientation: .left)
            } catch {
                // don't do anything
            }
        }
    }
    
    /// Retrieves results of the face bounding box & landmarks detection request and assigns them to FaceDetector member variables
    /// - Parameters:
    ///   - request: VNRequest
    ///   - error: Error
    func handleRequests(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard
            let results = request.results as? [VNFaceObservation],
            let result = results.first else { // encountered invalid face detection
                self.faceValid = false
                
                // TODO: when should eye detections be invalid?
                self.leftEyeValid = false
                self.rightEyeValid = false
                return
            }
            
            self.processFaceObservationResult(result: result)
        }
    }
    
    /// From VNFaceObservation result, extracts
    /// 1. face bounding box in image coordinates
    /// 2. yaw, pitch, roll
    /// 3. left and right eye bounding boxes in image coordinates
    /// 4. capture quality
    /// - Parameter result: VNFaceObservation result
    func processFaceObservationResult(result: VNFaceObservation) {
        // get device bounds
        let bounds = UIScreen.main.bounds
        let deviceWidth = Int(bounds.size.width)
        let deviceHeight = Int(bounds.size.height)

        // get face bounding box in image coordinates
        self.faceBoundingBox = VNImageRectForNormalizedRect(result.boundingBox, deviceWidth, deviceHeight)
        
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
        let leftEyebrowPts = Array([leftEyebrow.normalizedPoints[3], leftEyebrow.normalizedPoints[5]])
        let rightEyebrowPts = Array([rightEyebrow.normalizedPoints[5], rightEyebrow.normalizedPoints[3]])
        
        self.leftEyeBoundingBox = makeEyeBoundingBox(eyebrowPts: leftEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, imageCoordsFaceBoundingBox: self.faceBoundingBox, deviceWidth: deviceWidth, deviceHeight: deviceHeight)
        
        self.rightEyeBoundingBox = makeEyeBoundingBox(eyebrowPts: rightEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, imageCoordsFaceBoundingBox: self.faceBoundingBox, deviceWidth: deviceWidth, deviceHeight: deviceHeight)
        
        if let captureQuality = result.faceCaptureQuality {
            self.faceCaptureQuality = captureQuality
        }
    }
    
    /// Make eye bounding box based on the eye landmark and heuristics (proportion relative to the face)
    /// - Parameters:
    ///   - eyebrowPts: 1st point is the left point, the image coordinates of which will serve as the origin point of the eye bounding box; 2nd point is the right point, used to determine the width of the bounding box (if we're using that measure instead of the ratio heuristic)
    ///   - normalizedFaceBoundingBox: face bounding box in normalized coordinates (used for converting eyebrowPts to image coordinates)
    ///   - imageCoordsFaceBoundingBox: face bounding box in image coordinates (used for width calculation)
    ///   - deviceWidth: width
    ///   - deviceHeight: height
    /// - Returns: CGRect of eye bounding box in image coordinates
    func makeEyeBoundingBox(eyebrowPts: [CGPoint], normalizedFaceBoundingBox: CGRect, imageCoordsFaceBoundingBox: CGRect, deviceWidth: Int, deviceHeight: Int) -> CGRect {
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
            normalizedFaceBoundingBox,
            deviceWidth,
            deviceHeight)
        
        let eyebrowRight: CGPoint = eyebrowPts[1]
        let vectoredEyebrowRight = vector2(Float(eyebrowRight.x),Float(eyebrowRight.y))

        let vnImagePointRight = VNImagePointForFaceLandmarkPoint(
            vectoredEyebrowRight,
            normalizedFaceBoundingBox,
            deviceWidth,
            deviceHeight)
    
        let width = vnImagePointRight.x - vnImagePointLeft.x // alternate method for calculating width
        
        // determine height of eye bounding box based on eye/face ratio (heuristics)
        // TODO: refine this proportion (average of all ratios in GazeCapture dataset?)
        let heightProportion = 4.0
        let widthProportion = 4.0
        let eyeBoundingBoxHeight = imageCoordsFaceBoundingBox.height/heightProportion
        let eyeBoundingBoxWidth = imageCoordsFaceBoundingBox.width/widthProportion
        
        return CGRect(x: vnImagePointLeft.x, y: vnImagePointLeft.y, width: eyeBoundingBoxWidth, height: eyeBoundingBoxHeight)
    }
}
