////
////  Detector.swift
////  GazeTrackApp
////
////  Created by Jason Shang on 2/16/23.
////
//
//import UIKit
//import AVFoundation
//import Vision
//
//extension ViewController {
//    func setupFaceDetector() {
//        //var requests = [VNTrackObjectRequest]()
//        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
//            
//            if error != nil {
//                print("FaceDetection error: \(String(describing: error)).")
//            }
//            
//            // TODO: make tracking requests, detect facial landmarks, get the points of each facial landmark
////            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
////                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
////                    return
////            }
//            
//            DispatchQueue.main.async {
//                if let results = request.results {
//                    self.extractFaceDetections(results)
//                }
//            }
//        })
//        
//        // Start with detection.  Find face, then track it.
//        self.detectionRequests = [faceDetectionRequest]
//    }
//    
//    func extractFaceDetections(_ results: [VNObservation]) {
//        detectionLayer.sublayers = nil
//
//        for observation in results where observation is VNFaceObservation {
//            guard let objectObservation = observation as? VNFaceObservation else { continue }
//
//            // Transformations
//            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
//            let transformedBounds = CGRect(x: objectBounds.minX, y: screenRect.size.height - objectBounds.maxY, width: objectBounds.maxX - objectBounds.minX, height: objectBounds.maxY - objectBounds.minY)
//
//            let boxLayer = self.drawBoundingBox(transformedBounds)
//            self.detectionLayer.addSublayer(boxLayer)
//            
//            // TODO: track face
////            let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
////            requests.append(faceTrackingRequest)
//        }
//        //self.trackingRequests = requests
//    }
//    
//    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
//        let boxLayer = CALayer()
//        boxLayer.frame = bounds
//        boxLayer.borderWidth = 3.0
//        boxLayer.borderColor = CGColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
//        boxLayer.cornerRadius = 4
//        return boxLayer
//    }
//    
//    func setupDetectionLayer() {
//        detectionLayer = CALayer()
//        detectionLayer.frame = CGRect(x:0, y:0, width: screenRect.size.width, height: screenRect.size.height)
//        self.view.layer.addSublayer(detectionLayer)
//    }
//    
//    // for when orientation of device changes
//    func adjustDetectionLayerDimensions() {
//        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//    }
//    
//    /// - Tag: DrawPaths
//    fileprivate func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
//        guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
//            let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
//            else {
//            return
//        }
//        
//        CATransaction.begin()
//        
//        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
//        
//        let faceRectanglePath = CGMutablePath()
//        let faceLandmarksPath = CGMutablePath()
//        
//        for faceObservation in faceObservations {
//            self.addIndicators(to: faceRectanglePath,
//                               faceLandmarksPath: faceLandmarksPath,
//                               for: faceObservation)
//        }
//        
//        faceRectangleShapeLayer.path = faceRectanglePath
//        faceLandmarksShapeLayer.path = faceLandmarksPath
//        
//        self.updateLayerGeometry()
//        
//        CATransaction.commit()
//    }
//    
//    fileprivate func updateLayerGeometry() {
//        guard let overlayLayer = self.detectionOverlayLayer,
//            let rootLayer = self.rootLayer,
//            let previewLayer = self.previewLayer
//            else {
//            return
//        }
//        
//        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
//        
//        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
//        
//        var rotation: CGFloat
//        var scaleX: CGFloat
//        var scaleY: CGFloat
//        
//        // Rotate the layer into screen orientation.
//        switch UIDevice.current.orientation {
//        case .portraitUpsideDown:
//            rotation = 180
//            scaleX = videoPreviewRect.width / captureDeviceResolution.width
//            scaleY = videoPreviewRect.height / captureDeviceResolution.height
//            
//        case .landscapeLeft:
//            rotation = 90
//            scaleX = videoPreviewRect.height / captureDeviceResolution.width
//            scaleY = scaleX
//            
//        case .landscapeRight:
//            rotation = -90
//            scaleX = videoPreviewRect.height / captureDeviceResolution.width
//            scaleY = scaleX
//            
//        default:
//            rotation = 0
//            scaleX = videoPreviewRect.width / captureDeviceResolution.width
//            scaleY = videoPreviewRect.height / captureDeviceResolution.height
//        }
//        
//        // Scale and mirror the image to ensure upright presentation.
//        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
//            .scaledBy(x: scaleX, y: -scaleY)
//        overlayLayer.setAffineTransform(affineTransform)
//        
//        // Cover entire screen UI.
//        let rootLayerBounds = rootLayer.bounds
//        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
//    }
//    
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//        
//        // Create handler to perform request on the buffer
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
//        
//        // Look for existing tracking requests
//        guard let trackingRequests = self.trackingRequests, !trackingRequests.isEmpty else {
//            // No tracking object detected, so perform initial detection
//            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
//                                                            orientation: .up,
//                                                            options: [:])
//            
//            do {
//                guard let detectRequests = self.detectionRequests else {
//                    return
//                }
//                try imageRequestHandler.perform(detectRequests)
//            } catch let error as NSError {
//                NSLog("Failed to perform FaceRectangleRequest: %@", error)
//            }
//            return
//        }
//        
//        // Track existing tracking request if tracking object detected
//        do {
//            try self.sequenceRequestHandler.perform(trackingRequests,
//                                                     on: pixelBuffer,
//                                                    orientation: .up)
//        } catch let error as NSError {
//            NSLog("Failed to perform SequenceRequest: %@", error)
//        }
//        
//        // Setup the next round of tracking.
//        var newTrackingRequests = [VNTrackObjectRequest]()
//        for trackingRequest in trackingRequests {
//            
//            guard let results = trackingRequest.results else {
//                return
//            }
//            
//            guard let observation = results[0] as? VNDetectedObjectObservation else {
//                return
//            }
//            
//            if !trackingRequest.isLastFrame {
//                if observation.confidence > 0.3 {
//                    trackingRequest.inputObservation = observation
//                } else {
//                    trackingRequest.isLastFrame = true
//                }
//                newTrackingRequests.append(trackingRequest)
//            }
//        }
//        
//        self.trackingRequests = newTrackingRequests
//        
//        if newTrackingRequests.isEmpty {
//            // Nothing to track, so abort.
//            return
//        }
//        
//        // Perform face landmark tracking on detected faces.
//        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
//        
//        // Perform landmark detection on tracked faces.
//        for trackingRequest in newTrackingRequests {
//            
//            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
//                
//                if error != nil {
//                    print("FaceLandmarks error: \(String(describing: error)).")
//                }
//                
//                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
//                      let results = landmarksRequest.results else {
//                        return
//                }
//                
//                // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
//                DispatchQueue.main.async {
//                    self.drawFaceObservations(results)
//                }
//            })
//            
//            guard let trackingResults = trackingRequest.results else {
//                return
//            }
//            
//            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
//                return
//            }
//            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
//            faceLandmarksRequest.inputFaceObservations = [faceObservation]
//            
//            // Continue to track detected facial landmarks.
//            faceLandmarkRequests.append(faceLandmarksRequest)
//            
//            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
//                                                            orientation: .up,
//                                                            options: [:])
//            
//            do {
//                try imageRequestHandler.perform(faceLandmarkRequests)
//            } catch let error as NSError {
//                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
//            }
//        }
//    }
//}
