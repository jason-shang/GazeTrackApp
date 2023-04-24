//
//  SessionData.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 3/2/23.
//

import Foundation
import CoreMedia
import UIKit

class SessionData {
    
    var sessionName: String
    
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
    
    var screenH: [Int]
    var screenW: [Int]
    var orientation: [Int]

    var frameNum: Int
    
    var curDotIndex: Int

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
        self.maxFramesCacheSize = 20
        self.numFaceDetections = 0
        self.numEyeDetections = 0
        self.deviceName = "iPhone 13 Pro"
        
        self.screenH = [Int]()
        self.screenW = [Int]()
        self.orientation = [Int]()

        self.frameNum = 0
        
        self.curDotIndex = 0
        
        // initialize session name and then create the directory in document directory (will store all files from this session)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMddyy-HH:mm:ss"
        self.sessionName = dateFormatter.string(from: Date())
        createDirectory(directoryName: self.sessionName)
    }
    
    /// Create directory to which all data (frames & other json files) from the current session will be written
    /// - Parameter directoryName: directory name that represents when this session is first started
    func createDirectory(directoryName: String) {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the document directory")
            return
        }

        let folderURL = documentDirectory.appendingPathComponent(directoryName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            // Handle error
            print("Error creating directory")
            return
        }
    }

    /// Append face and eye bounding box data from the current sampleBuffer (frame) to the current session's data storage
    /// - Parameters:
    ///   - faceBoundingBox: image coordinates face bounding box
    ///   - leftEyeBoundingBox: image coordinates left eye bounding box
    ///   - rightEyeBoundingBox: image coordinates right eye bounding box
    ///   - frame:
    ///   - faceValid:
    ///   - leftEyeValid:
    ///   - rightEyeValid:
    func updateSessionData(faceBoundingBox: CGRect, leftEyeBoundingBox: CGRect, rightEyeBoundingBox: CGRect, frame: CMSampleBuffer, faceValid: Bool, leftEyeValid: Bool, rightEyeValid: Bool) {
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
        self.frameNames.append("\(self.sessionName)_\(self.frameNum).jpg")

        // convert image to UIImage to save memory, then cache and flush when cache reaches max cache size
        guard let image = self.uiImageFromSampleBuffer(sampleBuffer: frame) else { return }
        self.framesCache.append(image)

        if self.framesCache.count >= self.maxFramesCacheSize {
            self.saveFramesToDisk()
        }
        
        let bounds = UIScreen.main.bounds
        let deviceWidth = Int(bounds.size.width)
        let deviceHeight = Int(bounds.size.height)
        
        self.screenH.append(deviceHeight)
        self.screenW.append(deviceWidth)
        
        switch UIDevice.current.orientation {
        case .unknown:
            self.orientation.append(0)
        case .portrait:
            self.orientation.append(1)
        case .portraitUpsideDown:
            self.orientation.append(2)
        case .landscapeLeft:
            self.orientation.append(3)
        case .landscapeRight:
            self.orientation.append(4)
        case .faceUp:
            self.orientation.append(5)
        case .faceDown:
            self.orientation.append(6)
        @unknown default:
            self.orientation.append(0)
        }
    }
    
    /// Converts image from a sampleBuffer to a UIImage (less memory footprint and allows for direct conversion to jpeg format)
    /// - Parameter sampleBuffer: CMSampleBuffer object representing the current image frame
    /// - Returns: sampleBuffer converted into a UIImage (same dimensions as sampleBuffer)
    func uiImageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        let ciimage = CIImage(cvPixelBuffer: imageBuffer)

        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciimage, from: ciimage.extent)!
        let image = UIImage(cgImage: cgImage)
        let flippedImage = image.withHorizontallyFlippedOrientation()
        
        return flippedImage
    }
    
    
    /// Scale image to the desired aspect ratio (same as the screen)
    /// - Parameter image: UIImage; frame to be scaled
    /// - Returns: frame scaled to the desired aspect ratio (screen aspect ratio)
    func scaleImageToScreenSize(image: UIImage) -> UIImage {
        let targetSize = UIScreen.main.bounds.size
        let imageAspectRatio = image.size.width / image.size.height

        var cropRect = CGRect.zero
        if imageAspectRatio > targetSize.width / targetSize.height {
            let newWidth = image.size.height * targetSize.width / targetSize.height
            cropRect = CGRect(x: (image.size.width - newWidth) / 2, y: 0, width: newWidth, height: image.size.height)
        } else {
            let newHeight = image.size.width * targetSize.height / targetSize.width
            cropRect = CGRect(x: 0, y: (image.size.height - newHeight) / 2, width: image.size.width, height: newHeight)
        }

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            print("could not crop")
            return UIImage()
        }

        let croppedImage = UIImage(cgImage: cgImage)

        return croppedImage
    }

    /// writes image frames stored in framesCache to disk, then clears the cache
    func saveFramesToDisk() {
        let framesCacheCopy = self.framesCache
        self.framesCache.removeAll()
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing the document directory")
            return
        }
        
        // use documentsDirectory for saving files
        for frame in framesCacheCopy {
            // scale image to device coordinates
            let scaledImage = scaleImageToScreenSize(image: frame)
            
            if let imageData = scaledImage.jpegData(compressionQuality: 0.8) { // could adjust compression quality (1.0 max, 0.0 min)
                let fileName = "frame_\(self.frameNum).jpg"
                let folderURL = documentDirectory.appendingPathComponent(self.sessionName, isDirectory: true)
                let fileURL = folderURL.appendingPathComponent(fileName)
                do {
//                    print("writing \(fileName) to disk")
                    try imageData.write(to: fileURL)
                    self.frameNum += 1
//                    print("\(self.frameNum) number of disk writes")
                } catch {
                    print("Error writing image to disk: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// write various data stores to documentDirectory as json files
    func processAndSaveData() {
        let faceData = FaceOrEyeData(H: self.faceHeights, W: self.faceWidths, X: self.faceXs, Y: self.faceYs, IsValid: self.faceValids)
        let lEyeData = FaceOrEyeData(H: self.lEyeHeights, W: self.lEyeWidths, X: self.lEyeXs, Y: self.lEyeYs, IsValid: self.lEyeValids)
        let rEyeData = FaceOrEyeData(H: self.rEyeHeights, W: self.rEyeWidths, X: self.rEyeXs, Y: self.rEyeYs, IsValid: self.rEyeValids)
        let framesData = FramesData(frameNames: self.frameNames)
        let infoData = InfoData(TotalFrames: self.frameNum, NumFaceDetections: self.numFaceDetections, NumEyeDetections: self.numEyeDetections, DeviceName: self.deviceName)
//        let screenData = ScreenData(H: <#T##[Float]#>, W: <#T##[Float]#>, Orientation: <#T##[Int]#>)
        
        // still missing:
        // dotInfo.json
        // faceGrid.json
        // screen.json
        
        saveAsJSON(data: faceData, fileName: "appleFace")
        saveAsJSON(data: lEyeData, fileName: "appleLeftEye")
        saveAsJSON(data: rEyeData, fileName: "appleRightEye")
        saveAsJSON(data: framesData, fileName: "frames")
        saveAsJSON(data: infoData, fileName: "info")
    }

    /// saves data to app's documents directory (local storage, no Cloud backup)
    /// - Parameter data: JSONEncodableDataModel passed in from FaceDetector
    func saveAsJSON<T: JSONEncodableDataModel>(data: T, fileName: String) {
        guard let json = data.toJSON() else { return }
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing documents directory!")
            return
        }
        
        let folderURL = documentDirectory.appendingPathComponent(self.sessionName, isDirectory: true)
        let fileURL = folderURL.appendingPathComponent(fileName).appendingPathExtension("json")

        do {
            try json.write(to: fileURL)
//            print("Saved to \(fileURL.absoluteString)")
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
