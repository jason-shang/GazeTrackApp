//
//  FaceDetector.swift
//  BiometricPhoto
//
//  Created by Tobias Wissmüller on 11.01.22.
//

import Foundation
import Vision
import UIKit
import Combine
import AVFoundation

class FaceDetector: NSObject, ObservableObject {
    
    @Published var faceCaptureQuality: Float = 0.0
    
    @Published var boundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @Published var leftEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    @Published var rightEyeBoundingBox = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
    
    @Published var landmarks: VNFaceLandmarks2D?
    
    @Published var yaw: Float = 0
    @Published var roll: Float = 0
    @Published var pitch: Float = 0
    
    private var sampleBuffer: CMSampleBuffer?
    
    let subject = PassthroughSubject<CMSampleBuffer?, Never>()
    var cancellables = [AnyCancellable]()
    
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
    
    
    func detect(sampleBuffer: CMSampleBuffer) throws {
        let handler = VNSequenceRequestHandler()
        
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest.init(completionHandler: handleRequests)
        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        
        let faceCaptureQualityRequest = VNDetectFaceCaptureQualityRequest.init(completionHandler: handleRequests)
        
        let faceRectanglesRequest = VNDetectFaceRectanglesRequest.init(completionHandler: handleRequests)
        faceLandmarksRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        DispatchQueue.global().async {
            do {
                try handler.perform([faceLandmarksRequest, faceCaptureQualityRequest, faceRectanglesRequest], on: sampleBuffer, orientation: .left)
            } catch {
                // don't do anything
            }
        }
        
    }
    
    func handleRequests(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard
                let results = request.results as? [VNFaceObservation],
                let result = results.first else { return }
            
            self.boundingBox = result.boundingBox
            
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
            
            self.leftEyeBoundingBox = self.makeEyeBoundingBox(eyebrowLeft: leftEyebrow.normalizedPoints[0], eyebrowRight: leftEyebrow.normalizedPoints[3], faceBoundingBox: self.boundingBox)
            
            self.rightEyeBoundingBox = self.makeEyeBoundingBox(eyebrowLeft: rightEyebrow.normalizedPoints[0], eyebrowRight: rightEyebrow.normalizedPoints[3], faceBoundingBox: self.boundingBox)
            
            if let captureQuality = result.faceCaptureQuality {
                self.faceCaptureQuality = captureQuality
            }
        }
    }
    
    // construct eye bounding box based on face/eye proportion (3.34 from GazeCapture subject 00002, frame 00000 -> 00002__00000.jpg)
    // convert landmark points to coordinates of the original image!
    func makeEyeBoundingBox(eyebrowLeft: CGPoint, eyebrowRight: CGPoint, faceBoundingBox: CGRect) -> CGRect {
        let proportion = 3.34
        // TODO: get all this in device coordinates
        let eyebrowLeftImageCoords = VNImagePointForNormalizedPoint(eyebrowLeft, <#Int#>, <#Int#>)
        return CGRect(x: eyebrowLeft.x, y: eyebrowLeft.y, width: eyebrowRight.x-eyebrowLeft.x, height: faceBoundingBox.height/proportion)
    }
    
    // crop to eyes using the min and max (just the eyes, makeEyeBoundingBox would make bigger rectangles that are more similar to GazeCapture)
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

extension CGPoint {
    func convertToImagePoint(_ originalImage:CIImage,_ boundingBox:CGRect)->CGPoint {
        let imageWidth = originalImage.extent.width
        let imageHeight = originalImage.extent.height
        let vectoredPoint = vector2(Float(self.x),Float(self.y))
        let vnImagePoint = VNImagePointForFaceLandmarkPoint(vectoredPoint,boundingBox, Int(imageWidth), Int(imageHeight))
        let imagePoint = CGPoint(x: vnImagePoint.x, y: vnImagePoint.y)
        return imagePoint
    }
}
