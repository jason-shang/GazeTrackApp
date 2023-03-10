//
//  ImageClassifier.swift
//  GazeTrackApp
//
//  Created by Jason Shang on 3/10/23.
//

import UIKit

class ImagePredictor {
    lazy var module: TorchModule = {
        if let filePath = Bundle.main.path(forResource: "model", ofType: "pt"),
            let module = TorchModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Failed to load model!")
        }
    }()
    
//    lazy var classes: [String] = {
//        if let filePath = Bundle.main.path(forResource: "classes", ofType: "txt"),
//            let classes = try? String(contentsOfFile: filePath) {
//            return classes.components(separatedBy: .newlines)
//        } else {
//            fatalError("classes file was not found.")
//        }
//    }()
}
