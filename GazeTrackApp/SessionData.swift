//
//  FrameProcessor.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 3/2/23.
//

import Foundation
import CoreMedia
import UIKit

class SessionData {
    var faceHeights: [CGFloat]
    var faceWidths: [CGFloat]
    var faceXs: [CGFloat]
    var faceYs: [CGFloat]
    var faceValids: [Int]

    var lEyeHeights: [CGFloat]
    var lEyeWidths: [CGFloat]
    var lEyeXs: [CGFloat]
    var lEyeYs: [CGFloat]
    var lEyeValids: [Int]

    var rEyeHeights: [CGFloat]
    var rEyeWidths: [CGFloat]
    var rEyeXs: [CGFloat]
    var rEyeYs: [CGFloat]
    var rEyeValids: [Int]

    var frameNames: [String]
    var framesCache: [UIImage]
    let maxFramesCacheSize: Int
    var numFaceDetections: Int
    var numEyeDetections: Int
    var deviceName: String

    var frameNum: Int

    init() {
        self.faceHeights = [CGFloat]()
        self.faceWidths = [CGFloat]()
        self.faceXs = [CGFloat]()
        self.faceYs = [CGFloat]()
        self.faceValids = [Int]()

        self.lEyeHeights = [CGFloat]()
        self.lEyeWidths = [CGFloat]()
        self.lEyeXs = [CGFloat]()
        self.lEyeYs = [CGFloat]()
        self.lEyeValids = [Int]()

        self.rEyeHeights = [CGFloat]()
        self.rEyeWidths = [CGFloat]()
        self.rEyeXs = [CGFloat]()
        self.rEyeYs = [CGFloat]()
        self.rEyeValids = [Int]()

        self.frameNames = [String]()
        self.framesCache = [UIImage]()
        self.maxFramesCacheSize = 0
        self.numFaceDetections = 0
        self.numEyeDetections = 0
        self.deviceName = "iPhone 13 Pro"

        self.frameNum = 0
    }

    /// Append face and eye bounding box data from the current sampleBuffer (frame) to the current session's data storage
    /// - Parameters:
    ///   - faceBoundingBox: image coordinates face bounding box
    ///   - leftEyeBoundingBox: image coordinates left eye bounding box
    ///   - rightEyeBoundingBox: image coordinates right eye bounding box
    ///   - faceCaptureQuality: faceCaptureQuality - [0.0, 1.0], float
    ///   - frame:
    ///   - faceValid:
    ///   - leftEyeValid:
    ///   - rightEyeValid:
    func updateSessionData(faceBoundingBox: CGRect, leftEyeBoundingBox: CGRect, rightEyeBoundingBox: CGRect, faceCaptureQuality: Float, frame: CMSampleBuffer, faceValid: Bool, leftEyeValid: Bool, rightEyeValid: Bool) {
        self.faceHeights.append(faceBoundingBox.height)
        self.faceWidths.append(faceBoundingBox.width)
        self.faceXs.append(faceBoundingBox.origin.x)
        self.faceYs.append(faceBoundingBox.origin.y)

        self.lEyeHeights.append(leftEyeBoundingBox.height)
        self.lEyeWidths.append(leftEyeBoundingBox.width)
        self.lEyeXs.append(leftEyeBoundingBox.origin.x)
        self.lEyeYs.append(leftEyeBoundingBox.origin.y)

        self.rEyeHeights.append(rightEyeBoundingBox.height)
        self.rEyeWidths.append(rightEyeBoundingBox.width)
        self.rEyeXs.append(rightEyeBoundingBox.origin.x)
        self.rEyeYs.append(rightEyeBoundingBox.origin.y)

        if faceValid {
            self.faceValids.append(1)
            self.numFaceDetections += 1
        } else {
            self.faceValids.append(0)
        }

        self.lEyeValids.append(leftEyeValid ? 1 : 0)
        self.rEyeValids.append(rightEyeValid ? 1 : 0)
        if (leftEyeValid && rightEyeValid) { self.numEyeDetections += 1 }
        self.frameNames.append("session\(1)_\(self.frameNum).jpg") //TODO: update session index

        // convert image to UIImage to save memory, then cache and flush when cache reaches max cache size
        guard let image = self.uiImageFromSampleBuffer(sampleBuffer: frame) else { return }
        self.framesCache.append(image)
        print("frames cache size: \(self.framesCache.count)")

        if self.framesCache.count >= self.maxFramesCacheSize {
            self.saveFramesToDisk()
        }
    }

    func uiImageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        let ciimage = CIImage(cvPixelBuffer: imageBuffer)

        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let image = UIImage(cgImage: cgImage)
        return image
    }

    // writes frames stored in framesCache to disk, then clears the cache
    func saveFramesToDisk() {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // use documentsDirectory for saving files
            for frame in self.framesCache {
                if let imageData = frame.jpegData(compressionQuality: 0.5) { // could adjust compression quality (1.0 max, 0.0 min)
                    let fileName = "session\(1)_\(self.frameNum).jpg"
                    let fileURL = documentsDirectory.appendingPathComponent(fileName)
                    do {
                        print("writing \(fileName) to disk")
                        try imageData.write(to: fileURL)
                        self.frameNum += 1
                        print("\(self.frameNum) number of disk writes")
                    } catch {
                        print("Error writing image to disk: \(error.localizedDescription)")
                    }
                }
            }
        }

        self.framesCache.removeAll()
    }
    
    func processAndSaveData() {
        let faceData = FaceOrEyeData(heights: self.faceHeights, widths: self.faceWidths, xs: self.faceXs, ys: self.faceYs, valids: self.faceValids)
        let lEyeData = FaceOrEyeData(heights: self.lEyeHeights, widths: self.lEyeWidths, xs: self.lEyeXs, ys: self.lEyeYs, valids: self.lEyeValids)
        let rEyeData = FaceOrEyeData(heights: self.rEyeHeights, widths: self.rEyeWidths, xs: self.rEyeXs, ys: self.rEyeYs, valids: self.rEyeValids)
        let framesData = FramesData(frameNames: self.frameNames)
        let infoData = InfoData(totalFrames: self.frameNum, numFaceDetections: self.numFaceDetections, numEyeDetections: self.numEyeDetections, deviceNmae: self.deviceName)
        
        // still missing:
        // dotInfo.json
        // faceGrid.json
        // screen.json
        
        saveAsJSON(data: faceData, fileName: "session\(1)Face")
        saveAsJSON(data: lEyeData, fileName: "session\(1)lEye")
        saveAsJSON(data: rEyeData, fileName: "session\(1)rEye")
        saveAsJSON(data: framesData, fileName: "session\(1)Frames")
        saveAsJSON(data: infoData, fileName: "session\(1)Info")
    }

    /// saves data to app's documents directory (local storage, no Cloud backup)
    /// - Parameter data: JSONEncodableDataModel passed in from FaceDetector
    func saveAsJSON<T: JSONEncodableDataModel>(data: T, fileName: String) {
        guard let json = data.toJSON() else { return }
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirectory.appendingPathComponent(fileName).appendingPathExtension("json")

        do {
            try json.write(to: fileURL)
            print("Saved to \(fileURL.absoluteString)")
        } catch {
            print("Error writing JSON data: \(error)")
        }
    }
    
    // for debugging purposes
    func checkData() {
        print("faceHeights: \(self.faceHeights.count)")
        print("faceWidths: \(self.faceWidths.count)")
        print("faceXs: \(self.faceXs.count)")
        print("faceYs: \(self.faceYs.count)")
        print("faceValids: \(self.faceValids.count)")
        
        print("==================")
        print(self.lEyeHeights.count)
        print(self.lEyeWidths.count)
        print(self.lEyeXs.count)
        print(self.lEyeYs.count)
        print(self.lEyeValids.count)
        
        print("==================")
        print(self.rEyeHeights.count)
        print(self.rEyeWidths.count)
        print(self.rEyeXs.count)
        print(self.rEyeYs.count)
        print(self.rEyeValids.count)
        
        print("==================")
        print("frames: \(self.framesCache.count)")
        print("total number of frames: \(self.frameNum)")
        print("numFaceDetections: \(self.numFaceDetections)")
        print("numEyeDetections: \(self.numEyeDetections)")
    }
}
