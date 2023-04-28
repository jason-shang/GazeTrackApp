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
    
    var captureSession: CaptureSession
    @Published var curDotNum: Int = 0
    @Published var curDotX: CGFloat = 0.0
    @Published var curDotY: CGFloat = 0.0
    
//    @Published var faceCaptureQuality: Float = 0.0
    
    // relative to top left corner of full frame
//    @Published var faceBoundingBoxDevice = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0) // device coordinates (for display)
//    @Published var faceBoundingBoxImage = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0) // image coordinates (for session data)
    
    // relative to top-left corner of face bounding box (TODO: change it to actually do this! right now it's relative to top left corner of full frame)
    // 1. device coordinates
//    @Published var leftEyeBoundingBoxDevice = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
//    @Published var rightEyeBoundingBoxDevice = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    // 2. image coordinates
//    @Published var leftEyeBoundingBoxImage = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
//    @Published var rightEyeBoundingBoxImage = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
//    @Published var landmarks: VNFaceLandmarks2D?
//
//    @Published var yaw: Float = 0
//    @Published var roll: Float = 0
//    @Published var pitch: Float = 0
//
//    private var bufferWidth: Int = 0
//    private var bufferHeight: Int = 0
//
//    private var faceValid: Bool = false
//    private var leftEyeValid: Bool = false
//    private var rightEyeValid: Bool = false
    
    private var sampleBuffer: CMSampleBuffer?
    
    // PassthroughSubject can both subscribe & broadcast;
    // here, subject receives new values of sampleBuffer from captureSession (see GazeTrackApp AppDelegate) and broadcasts that to downstream subscribers
    let subject = PassthroughSubject<CMSampleBuffer?, Never>()
    var cancellables = [AnyCancellable]()
    
    init(captureSession: CaptureSession) {
        self.captureSession = captureSession
        super.init()
        subject.sink { sampleBuffer in
            self.sampleBuffer = sampleBuffer
            let dotNum = self.curDotNum
            let dotX = self.curDotX
            let dotY = self.curDotY
            
            do {
                guard let sampleBuffer = sampleBuffer else {
                    return
                }
//                guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
//                    print("Error: cannot get dimensions from sample buffer.")
//                    return
//                }
//                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
//                self.bufferWidth = Int(dimensions.width)
//                self.bufferHeight = Int(dimensions.height)
                
                try self.detect(sampleBuffer: sampleBuffer, dotNum: dotNum, dotX: dotX, dotY: dotY)
                
//                if let sessionData = captureSession.sessionData {
//                    sessionData.updateSessionData(faceBoundingBox: self.faceBoundingBoxDevice, leftEyeBoundingBox: self.leftEyeBoundingBoxDevice, rightEyeBoundingBox: self.rightEyeBoundingBoxDevice, faceCaptureQuality: self.faceCaptureQuality, frame: self.sampleBuffer!, faceValid: self.faceValid, leftEyeValid: self.leftEyeValid, rightEyeValid: self.rightEyeValid)
//                }
            } catch {
                print("Error has been thrown")
            }
            
        }.store(in: &cancellables)
    }
    
    /// Set up and perform face detection requests
    /// - Parameter sampleBuffer: CMSampleBuffer object representing the current image frame
    func detect(sampleBuffer: CMSampleBuffer, dotNum: Int, dotX: CGFloat, dotY: CGFloat) throws {
        let handler = VNSequenceRequestHandler()
        
//        let faceLandmarksRequest = VNDetectFaceLandmarksRequest.init(completionHandler: handleRequests)
//        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
//
//        let faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest.init(completionHandler: handleRequests)
//
//        let faceRectanglesRequest = VNDetectFaceRectanglesRequest.init(completionHandler: handleRequests)
//        faceRectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        let faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest()
        let faceRectanglesRequest = VNDetectFaceRectanglesRequest()
        faceRectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        let requests = [faceLandmarksRequest, faceCaptureQualityRequest, faceRectanglesRequest]
        
        let deviceOrientation = UIDevice.current.orientation.cgImagePropertyOrientation
        
        DispatchQueue.global().async {
            do {
                // note: the completion handlers assigned to each of these requests will have access to the results of all these requests,
//                try handler.perform([faceLandmarksRequest, faceCaptureQualityRequest, faceRectanglesRequest], on: sampleBuffer, orientation: deviceOrientation)
                try handler.perform(requests, on: sampleBuffer, orientation: deviceOrientation)
                
                if let results = faceLandmarksRequest.results {
                    self.processFaceObservationResult2(result: results[0], sampleBuffer: sampleBuffer, dotNum: dotNum, dotX: dotX, dotY: dotY)
                }
            } catch {
                // don't do anything
            }
        }
    }
    
    func processFaceObservationResult2(result: VNFaceObservation, sampleBuffer: CMSampleBuffer, dotNum: Int, dotX: CGFloat, dotY: CGFloat) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            print("Error: cannot get dimensions from sample buffer.")
            return
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let bufferWidth = Int(dimensions.width)
        let bufferHeight = Int(dimensions.height)
        
        var faceValid = false
        var leftEyeValid = false
        var rightEyeValid = false
        if bufferWidth > 0 && bufferHeight > 0 {
            faceValid = true
            leftEyeValid = true
            rightEyeValid = true
        }
        
        // get device bounds
        let bounds = UIScreen.main.bounds
        let deviceWidth = Int(bounds.size.width)
        let deviceHeight = Int(bounds.size.height)

        // get face bounding box relative to device coordinates
        let faceBoundingBoxDevice = VNImageRectForNormalizedRect(result.boundingBox, deviceWidth, deviceHeight)
        
        var leftEyeBoundingBoxDevice = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        var rightEyeBoundingBoxDevice = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
        
        if let landmarks = result.landmarks {
            guard let leftEyebrow = landmarks.leftEyebrow else { return }
            guard let rightEyebrow = landmarks.rightEyebrow else { return }
            let leftEyebrowPts = Array([leftEyebrow.normalizedPoints[3], leftEyebrow.normalizedPoints[5]])
            let rightEyebrowPts = Array([rightEyebrow.normalizedPoints[5], rightEyebrow.normalizedPoints[3]])
            
            // 1. device coordinates
            leftEyeBoundingBoxDevice = makeEyeBoundingBox(eyebrowPts: leftEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, faceBoundingBox: faceBoundingBoxDevice, width: deviceWidth, height: deviceHeight)
            rightEyeBoundingBoxDevice = makeEyeBoundingBox(eyebrowPts: rightEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, faceBoundingBox: faceBoundingBoxDevice, width: deviceWidth, height: deviceHeight)
        }
        
        if let sessionData = self.captureSession.sessionData {
            sessionData.updateSessionData(
                faceBoundingBox: faceBoundingBoxDevice,
                leftEyeBoundingBox: leftEyeBoundingBoxDevice,
                rightEyeBoundingBox: rightEyeBoundingBoxDevice,
                frame: sampleBuffer,
                faceValid: faceValid,
                leftEyeValid: leftEyeValid,
                rightEyeValid: rightEyeValid,
                curDotNum: dotNum,
                curDotX: dotX,
                curDotY: dotY
            )
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
//                self.faceValid = false
//
//                // TODO: when should eye detections be invalid?
//                self.leftEyeValid = false
//                self.rightEyeValid = false
                return
            }
            
//            self.processFaceObservationResult(result: result)
        }
    }
    
    /// From VNFaceObservation result, extracts
    /// 1. face bounding box in image coordinates AND device coordinates
    /// 2. yaw, pitch, roll
    /// 3. left and right eye bounding boxes in image coordinates AND device coordinates
    /// 4. capture quality
    /// - Parameter result: VNFaceObservation result
//    func processFaceObservationResult(result: VNFaceObservation) {
//        if self.bufferWidth > 0 && self.bufferHeight > 0 {
//            self.faceValid = true
//            self.leftEyeValid = true
//            self.rightEyeValid = true
//        }
//
//        // get device bounds
//        let bounds = UIScreen.main.bounds
//        let deviceWidth = Int(bounds.size.width)
//        let deviceHeight = Int(bounds.size.height)
//
//        // get face bounding box relative to device coordinates
//        self.faceBoundingBoxDevice = VNImageRectForNormalizedRect(result.boundingBox, deviceWidth, deviceHeight)
//
//        // get face bounding box relative to image coordinates
////        self.faceBoundingBoxImage = VNImageRectForNormalizedRect(result.boundingBox, self.bufferWidth, self.bufferHeight)
//
//        if let yaw = result.yaw,
//           let pitch = result.pitch,
//           let roll = result.roll {
//            self.yaw = yaw.floatValue
//            self.pitch = pitch.floatValue
//            self.roll = roll.floatValue
//        }
//
//        if let landmarks = result.landmarks {
//            self.landmarks = landmarks
//        }
//
//        guard let leftEyebrow = self.landmarks?.leftEyebrow else { return }
//        guard let rightEyebrow = self.landmarks?.rightEyebrow else { return }
//        let leftEyebrowPts = Array([leftEyebrow.normalizedPoints[3], leftEyebrow.normalizedPoints[5]])
//        let rightEyebrowPts = Array([rightEyebrow.normalizedPoints[5], rightEyebrow.normalizedPoints[3]])
//
//        // 1. device coordinates
//        self.leftEyeBoundingBoxDevice = makeEyeBoundingBox(eyebrowPts: leftEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, faceBoundingBox: self.faceBoundingBoxDevice, width: deviceWidth, height: deviceHeight)
//        self.rightEyeBoundingBoxDevice = makeEyeBoundingBox(eyebrowPts: rightEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, faceBoundingBox: self.faceBoundingBoxDevice, width: deviceWidth, height: deviceHeight)
//
//        // 2. image coordinates
////        self.leftEyeBoundingBoxImage = makeEyeBoundingBox(eyebrowPts: leftEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, faceBoundingBox: self.faceBoundingBoxImage, width: self.bufferWidth, height: self.bufferHeight)
////        self.rightEyeBoundingBoxImage = makeEyeBoundingBox(eyebrowPts: rightEyebrowPts, normalizedFaceBoundingBox: result.boundingBox, faceBoundingBox: self.faceBoundingBoxImage, width: self.bufferWidth, height: self.bufferHeight)
//
//        if let captureQuality = result.faceCaptureQuality {
//            self.faceCaptureQuality = captureQuality
//        }
//    }
    
    /// Make eye bounding box based on the eye landmark and heuristics (proportion relative to the face)
    /// - Parameters:
    ///   - eyebrowPts: 1st point is the left point, the image coordinates of which will serve as the origin point of the eye bounding box; 2nd point is the right point, used to determine the width of the bounding box (if we're using that measure instead of the ratio heuristic)
    ///   - normalizedFaceBoundingBox: face bounding box in normalized coordinates (used for converting eyebrowPts to image/device coordinates)
    ///   - faceBoundingBox: face bounding box in image or device coordinates (used for width calculation)
    ///   - width: width by which to convert the normalized coordinates to either device or image coordinates (either device width or imageWidth)
    ///   - height: height by which to convert the normalized coordinates to either device or image coordinates (either device height or imageHeight)
    /// - Returns: CGRect of eye bounding box in either image or device coordinates, depending on whether the faceBoundingBox, width, height passed in are in image or device coordinates
    func makeEyeBoundingBox(eyebrowPts: [CGPoint], normalizedFaceBoundingBox: CGRect, faceBoundingBox: CGRect, width: Int, height: Int) -> CGRect {
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
            width,
            height)
        
        let eyebrowRight: CGPoint = eyebrowPts[1]
        let vectoredEyebrowRight = vector2(Float(eyebrowRight.x),Float(eyebrowRight.y))

        let vnImagePointRight = VNImagePointForFaceLandmarkPoint(
            vectoredEyebrowRight,
            normalizedFaceBoundingBox,
            width,
            height)
    
        let width = vnImagePointRight.x - vnImagePointLeft.x // alternate method for calculating width
        
        // determine height of eye bounding box based on eye/face ratio (heuristics)
        // TODO: refine this proportion (average of all ratios in GazeCapture dataset?)
        let heightProportion = 4.0
        let widthProportion = 3.5
        let eyeBoundingBoxHeight = faceBoundingBox.height/heightProportion
        let eyeBoundingBoxWidth = faceBoundingBox.width/widthProportion
        
        return CGRect(x: vnImagePointLeft.x - faceBoundingBox.origin.x,
                      y: vnImagePointLeft.y - faceBoundingBox.origin.y,
                      width: eyeBoundingBoxWidth,
                      height: eyeBoundingBoxHeight)
    }
}
