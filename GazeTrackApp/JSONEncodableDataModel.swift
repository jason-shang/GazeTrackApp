//
//  JSONEncodableDataModel.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 4/1/23.
//

import Foundation

protocol JSONEncodableDataModel {
    func toJSON() -> Data?
}

/// gazecapture appleFace.json, appleLeftEye.json & appleRightEye.json
struct FaceOrEyeData: Codable, JSONEncodableDataModel {
    var H: [CGFloat]
    var W: [CGFloat]
    var X: [CGFloat]
    var Y: [CGFloat]
    var IsValid: [Int]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

/// gazecapture dotInfo.json
struct DotData: Codable, JSONEncodableDataModel {
    var DotNum: [Int]
    var XPts: [Float]
    var YPts: [Float]
    var XCam: [Float]
    var YCam: [Float]
    var Time: [Float]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

/// gazecapture frames.json
struct FramesData: Codable, JSONEncodableDataModel {
    var frameNames: [String]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

/// gazecapture info.json
/// note: missing type of dataset (train, test or val)
struct InfoData: Codable, JSONEncodableDataModel {
    var TotalFrames: Int
    var NumFaceDetections: Int
    var NumEyeDetections: Int
    var DeviceName: String
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

struct ScreenData: Codable, JSONEncodableDataModel {
    var H: [Float]
    var W: [Float]
    var Orientation: [Int]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}
