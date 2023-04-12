//
//  FrameProcessor.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 3/2/23.
//

import Foundation
import CoreMedia

class SessionData {
    
    
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
    
    func saveFrameImages(frames: [CMSampleBuffer]) {
        return
    }
}
