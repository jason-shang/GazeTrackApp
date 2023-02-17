//
//  ContentView.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 2/16/23.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    
    var body: some View {
        HostedViewController()
            .ignoresSafeArea()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
