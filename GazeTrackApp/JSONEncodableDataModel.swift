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
struct FaceAndEyeData: Codable, JSONEncodableDataModel {
    var heights: [Float]
    var widths: [Float]
    var xs: [Float]
    var ys: [Float]
    var valids: [Int]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

/// gazecapture dotInfo.json
struct DotData: Codable, JSONEncodableDataModel {
    var dotNums: [Int]
    var XPts: [Float]
    var XCam: [Float]
    var YCam: [Float]
    var Time: [Float]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

/// gazecapture frames.json
struct FrameData: Codable, JSONEncodableDataModel {
    var frameNames: [String]
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

/// gazecapture info.json
/// note: missing type of dataset (train, test or val)
struct InfoData: Codable, JSONEncodableDataModel {
    var totalFrames: Int
    var numFaceDetections: Int
    var numEyeDetections: Int
    var deviceNmae: String
    
    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}
