//
//  Orientation.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 4/14/23.
//

import AVFoundation
import Foundation
import UIKit

extension AVCaptureVideoOrientation {
    
    static func from(_ deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch (deviceOrientation) {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}

extension UIDeviceOrientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .portrait:
            print("portrait")
            return .down
        case .portraitUpsideDown:
            print("portrait upside down")
            return .up
        case .landscapeLeft:
            print("landscapeLeft")
            return .left
        case .landscapeRight:
            print("landscapeRight")
            return .right
        default:
            print("default")
            return .up
        }
    }
}
