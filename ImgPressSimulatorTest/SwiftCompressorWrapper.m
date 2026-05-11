//
//  SwiftCompressorWrapper.m
//  ImgPressSimulatorTest
//
//  Created by Computer on 09/05/26.
//

#import "SwiftCompressorWrapper.h"

@implementation SwiftCompressorWrapper

- (NSData * _Nullable)compressImage:(UIImage *)image error:(NSError * _Nullable * _Nullable)error {
    // 使用JPEG压缩，质量0.8
    return UIImageJPEGRepresentation(image, 0.8);
}

- (NSString *)compressorName {
    return @"SwiftCompressor";
}

@end