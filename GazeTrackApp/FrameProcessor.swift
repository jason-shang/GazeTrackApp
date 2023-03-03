//
//  FrameProcessor.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 3/2/23.
//

//import AVFoundation
//
//class FrameProcessor: NSObject, ObservableObject {
//    
//    // static constant: make FrameProcessor into Singleton class (this instance can be accessed from anywhere
//    static let shared = FrameProcessor()
//    
//    // current frame received from the camera
//    @Published var current: CVPixelBuffer?
//    
//    let videoOutputQueue = DispatchQueue(
//      label: "frameProcessor",
//      qos: .userInitiated,
//      attributes: [],
//      autoreleaseFrequency: .workItem)
//    
//    private override init() {
//      super.init()
//      CameraManager.shared.set(self, queue: videoOutputQueue)
//    }
//}
