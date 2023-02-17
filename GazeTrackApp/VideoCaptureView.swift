//
//  ContentView.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 2/16/23.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    let captureSession = AVCaptureSession()
    @State var isRecording = false
    @State var videoURL: URL?
    
//    var body: some View {
//        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundColor(.accentColor)
//            Text("Hello, world!")
//        }
//        .padding()
//    }
}

struct VideoCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCaptureView()
    }
}
