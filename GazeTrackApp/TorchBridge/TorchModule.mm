// Copyright (c) 2020 Facebook, Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.



#import "TorchModule.h"
#import <LibTorch/LibTorch.h>
#import <Foundation/Foundation.h>

@implementation TorchModule {
 @protected
  torch::jit::script::Module _impl;
}

- (nullable instancetype)initWithFileAtPath:(NSString*)filePath {
  self = [super init];
  if (self) {
    try {
      _impl = torch::jit::load(filePath.UTF8String);
      _impl.eval();
    } catch (const std::exception& exception) {
      NSLog(@"%s", exception.what());
      return nil;
    }
  }
  return self;
}

- (NSArray<NSNumber*>*)predictImage:(void*)imageBuffer {
    try {
        NSString *message = @"in predictImage";
        NSLog(@"%@", message);
        
        // takes in dummy data (ignores imageBuffer)
        // TODO: generate similar format data from imageBuffer (see gazetrack_dataset.py data)
        
        NSString *leye1_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/leye1.csv";
        //NSString *leye1_path = @"../DummyData/leye1.csv";
        NSString *leye2_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/leye2.csv";
        NSString *leye3_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/leye3.csv";
        
        NSArray *leye1_data = [self readCSVFile:leye1_path];
        NSArray *leye2_data = [self readCSVFile:leye2_path];
        NSArray *leye3_data = [self readCSVFile:leye3_path];
        
        NSString *reye1_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/reye1.csv";
        NSString *reye2_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/reye2.csv";
        NSString *reye3_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/reye3.csv";
        
        NSArray *reye1_data = [self readCSVFile:reye1_path];
        NSArray *reye2_data = [self readCSVFile:reye2_path];
        NSArray *reye3_data = [self readCSVFile:reye3_path];
        
        // MARK: the data might not be read in properly. reye1_data has count of 129 ([reye1_data count]), and kps_data has length of 12 ???
        
        NSString *kps_path = @"/Users/jason/Documents/School/Duke/2022-2023/BME493/GazeTrackApp/GazeTrackApp/DummyData/kps.csv";
        NSArray *kps_data = [self readCSVFile:kps_path];
        
        at::Tensor leye_tensor = [self convertToTensor:leye1_data :leye2_data :leye3_data];
        at::Tensor reye_tensor = [self convertToTensor:reye1_data :reye2_data :reye3_data];
        
        at::Tensor kps_tensor = torch::zeros({1, 11}, torch::kFloat32);
        NSUInteger count = [reye1_data count];
        NSLog(@"count: %lu", (unsigned long)count);
        for (int i = 0; i < 11; i++) {
            id obj = [kps_data objectAtIndex:i][0];
            kps_tensor[0][i] = [obj floatValue];
        }
        
        torch::autograd::AutoGradMode guard(false);
        at::AutoNonVariableTypeMode non_var_type_mode(true);
        auto outputTensor = _impl.forward({leye_tensor, reye_tensor, kps_tensor}).toTensor();
        float* floatBuffer = outputTensor.data_ptr<float>();
        if (!floatBuffer) {
          return nil;
        }
        NSMutableArray* results = [[NSMutableArray alloc] init];
        for (int i = 0; i < 1000; i++) {
          [results addObject:@(floatBuffer[i])];
        }
        NSLog(@"results: ");
        NSLog(@"%@", [results copy]);
        return [results copy];
    } catch (const std::exception& exception) {
        NSLog(@"%s", exception.what());
    }
    return nil;
}

- (NSArray *)readCSVFile:(NSString *)filePath {
    NSError *error;
    NSString *fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"Error reading file: %@", error.localizedDescription);
        return nil;
    }
    
    NSArray *lines = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *data = [NSMutableArray array];
    for (NSString *line in lines) {
        NSArray *values = [line componentsSeparatedByString:@","];
        NSMutableArray *row = [NSMutableArray array];
        for (NSString *value in values) {
            [row addObject:@([value floatValue])];
        }
        [data addObject:row];
    }
    return data;
}

// "stack" the 3 NSArrays we read in from the CSVs into a 3x128x128 torch tensor
- (at::Tensor)convertToTensor:(NSArray *)array1 :(NSArray *)array2 :(NSArray *)array3 {
    // Allocate memory for the tensor
    // TODO: double check the size of the tensor (should this be 1x3x128x128?)
    at::Tensor tensor = torch::zeros({1, 3, 128, 128}, torch::kFloat32);

    // Copy data from the NSArray objects to the tensor
    for (int i = 0; i < 128; i++) {
        for (int j = 0; j < 128; j++) {
            float value1 = [[array1 objectAtIndex:i][j] floatValue];
            float value2 = [[array2 objectAtIndex:i][j] floatValue];
            float value3 = [[array3 objectAtIndex:i][j] floatValue];
            tensor[0][0][i][j] = value1;
            tensor[0][1][i][j] = value2;
            tensor[0][2][i][j] = value3;
        }
    }

    return tensor;
}

//- (NSArray<NSNumber*>*)predictImage:(void*)imageBuffer {
//  try {
//    at::Tensor imageTensor = torch::from_blob(imageBuffer, {1, 3, 480, 640}, at::kFloat);
//    torch::autograd::AutoGradMode guard(false);
//    at::AutoNonVariableTypeMode non_var_type_mode(true);
//    auto outputTensor = _impl.forward({tensor}).toTensor();
//    float* floatBuffer = outputTensor.data_ptr<float>();
//    if (!floatBuffer) {
//      return nil;
//    }
//    NSMutableArray* results = [[NSMutableArray alloc] init];
//    for (int i = 0; i < 1000; i++) {
//      [results addObject:@(floatBuffer[i])];
//    }
//    return [results copy];
//  } catch (const std::exception& exception) {
//    NSLog(@"%s", exception.what());
//  }
//  return nil;
//}

@end
