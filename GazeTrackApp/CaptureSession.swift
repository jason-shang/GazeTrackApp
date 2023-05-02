//
//  CaptureSession.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 3/2/23.
//

import UIKit
import Foundation
import AVFoundation

class CaptureSession: NSObject, ObservableObject {
    @Published var sampleBuffer: CMSampleBuffer?
    
    var captureSession: AVCaptureSession?
    var sessionData: SessionData?
    
    func setup() {
        var allowedAccess = false
        let blocker = DispatchGroup()
        blocker.enter()
        AVCaptureDevice.requestAccess(for: .video) { flag in
            allowedAccess = flag
            blocker.leave()
        }
        blocker.wait()
        if !allowedAccess { return }
        
        if !allowedAccess {
            print("Camera access is not allowed.")
            return
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        let videoDevice = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
        guard videoDevice != nil, let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!), session.canAddInput(videoDeviceInput) else {
            print("Unable to detect camera.")
            return
        }
        session.addInput(videoDeviceInput)
        session.commitConfiguration()
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "SampleBuffer"))
        if (session.canAddOutput(videoOutput)) {
            session.addOutput(videoOutput)
        }
        
        // set the connection's videoOrientation property of the AVCaptureVideoDataOutput to match the device orientation
        if let connection = videoOutput.connection(with: .video) {
            let deviceOrientation = UIDevice.current.orientation
            let videoOrientation: AVCaptureVideoOrientation
            switch deviceOrientation {
            case .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeRight
            case .landscapeRight:
                videoOrientation = .landscapeLeft
            default:
                videoOrientation = .portrait
            }
            connection.videoOrientation = videoOrientation
        }
        
        self.captureSession = session
    }
    
    func start() {
        guard let captureSession = self.captureSession else {
            return
        }
        
        if (!captureSession.isRunning) {
            DispatchQueue.global(qos: .background).async {
                captureSession.startRunning()
                self.sessionData = SessionData()
            }
        }
    }
    
    func stop() {
        guard let captureSession = self.captureSession else {
            return
        }
        if (captureSession.isRunning) {
            captureSession.stopRunning()
        }
        
        // write remaining frames on the frames cache to disk
        if self.sessionData!.framesCache.count > 0 {
            self.sessionData!.saveFramesToDisk()
        }
        
        // for debugging purposes
        self.sessionData!.checkData()
        
        // write all collected info to disk as JSON files
        self.sessionData!.processAndSaveData()
    }
}

extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            self.sampleBuffer = sampleBuffer
        }
    }
}
