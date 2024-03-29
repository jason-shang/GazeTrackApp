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
        
        // we're taking in dummy data (ignores imageBuffer)
        // TODO: generate similar format data from imageBuffer (see gazetrack_dataset.py data)
        
        NSString *leye1_path = [[NSBundle mainBundle] pathForResource:@"leye1" ofType:@"csv"];
        NSString *leye2_path = [[NSBundle mainBundle] pathForResource:@"leye2" ofType:@"csv"];
        NSString *leye3_path = [[NSBundle mainBundle] pathForResource:@"leye3" ofType:@"csv"];
        
        NSArray *leye1_data = [self readCSVFile:leye1_path];
        NSArray *leye2_data = [self readCSVFile:leye2_path];
        NSArray *leye3_data = [self readCSVFile:leye3_path];
        
        NSString *reye1_path = [[NSBundle mainBundle] pathForResource:@"reye1" ofType:@"csv"];
        NSString *reye2_path = [[NSBundle mainBundle] pathForResource:@"reye2" ofType:@"csv"];
        NSString *reye3_path = [[NSBundle mainBundle] pathForResource:@"reye3" ofType:@"csv"];
        
        NSArray *reye1_data = [self readCSVFile:reye1_path];
        NSArray *reye2_data = [self readCSVFile:reye2_path];
        NSArray *reye3_data = [self readCSVFile:reye3_path];
        
        // TODO: the data might not be read in properly. reye1_data has count of 129 ([reye1_data count]), and kps_data has length of 12 ???
        
        NSString *kps_path = [[NSBundle mainBundle] pathForResource:@"kps" ofType:@"csv"];
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
        
        // MARK: quantize input tensors
        // scale & zero point determined through calibration data
        // note: quantizedValue = round(realValue / scale + zeroPoint)
        // approach 1: PyTorch's dynamic quantization; scale value = range of values divided by the maximum value that can be represented by the given bit width (e.g. 255 for 8-bit) ((r_max - r_min)/255), and the zero point value is set to 0
        double leye_scale = [self getScale:leye_tensor];
        double reye_scale = [self getScale:reye_tensor];
        double kps_scale = [self getScale:kps_tensor];
        at::Tensor quantized_leye_tensor = torch::quantize_per_tensor(leye_tensor, leye_scale, 0, at::kQInt8);
        at::Tensor quantized_reye_tensor = torch::quantize_per_tensor(reye_tensor, reye_scale, 0, at::kQInt8);
        at::Tensor quantized_kps_tensor = torch::quantize_per_tensor(kps_tensor, kps_scale, 0, at::kQInt8);
        
        // approach 2: PyTorch's post-training static quantization, uses "histogram scaling"
        // https://medium.com/@sanjanasrinivas73/post-training-static-quantization-pytorch-37dd187ba105
        
        // the shapes look correct? (1, 3, 128, 128) & (1, 3, 128, 128) & (1, 11)...
        // MARK: open github issue: https://github.com/pytorch/pytorch/issues/76726
        NSLog(@"left");
        [self printShape:quantized_leye_tensor];
        NSLog(@"right");
        [self printShape:quantized_reye_tensor];
        NSLog(@"kps");
        [self printShape:quantized_kps_tensor];
        
        torch::autograd::AutoGradMode guard(false);
        at::AutoNonVariableTypeMode non_var_type_mode(true);
        auto outputTensor = _impl.forward({quantized_leye_tensor, quantized_reye_tensor, quantized_kps_tensor}).toTensor();
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

- (void)printShape:(at::Tensor)tensor {
    NSArray<NSNumber *> *shape = @[];
    int ndim = tensor.dim();
    for (int i = 0; i < ndim; i++) {
        NSNumber *dim = [NSNumber numberWithInt:tensor.size(i)];
        shape = [shape arrayByAddingObject:dim];
    }

    for (int i = 0; i < [shape count]; i++) {
        NSLog(@"%@", [shape objectAtIndex:i]);
    }
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

- (double)getScale:(at::Tensor)tensor {
    at::Tensor max = torch::max(tensor);
    at::Tensor min = torch::min(tensor);
    return (max.item<float>() - min.item<float>())/255.0;
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
