//
//  Detector.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 2/16/23.
//

import UIKit
import AVFoundation
import Vision

extension ViewController {
    func setupFaceDetector() {
        //var requests = [VNTrackObjectRequest]()
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
//            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
//                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
//                    return
//            }
            
            DispatchQueue.main.async {
                if let results = request.results {
                    self.extractFaceDetections(results)
                }
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
    }
    
    func extractFaceDetections(_ results: [VNObservation]) {
        detectionLayer.sublayers = nil

        for observation in results where observation is VNFaceObservation {
            guard let objectObservation = observation as? VNFaceObservation else { continue }

            // Transformations
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
            let transformedBounds = CGRect(x: objectBounds.minX, y: screenRect.size.height - objectBounds.maxY, width: objectBounds.maxX - objectBounds.minX, height: objectBounds.maxY - objectBounds.minY)

            let boxLayer = self.drawBoundingBox(transformedBounds)
            self.detectionLayer.addSublayer(boxLayer)
            
            // TODO: track face
//            let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
//            requests.append(faceTrackingRequest)
        }
        //self.trackingRequests = requests
    }
    
    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
        let boxLayer = CALayer()
        boxLayer.frame = bounds
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = CGColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        boxLayer.cornerRadius = 4
        return boxLayer
    }
    
    func setupDetectionLayer() {
        detectionLayer = CALayer()
        detectionLayer.frame = CGRect(x:0, y:0, width: screenRect.size.width, height: screenRect.size.height)
        self.view.layer.addSublayer(detectionLayer)
    }
    
    // for when orientation of device changes
    func adjustDetectionLayerDimensions() {
        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:]) // Create handler to perform request on the buffer

        do {
            try imageRequestHandler.perform(self.detectionRequests!) // Schedules vision requests to be performed
        } catch {
            print(error)
        }
    }
}
