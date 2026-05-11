//
//  DefaultImageCompressor.m
//  ImgPressSimulatorTest
//
//  Created by Computer on 09/05/26.
//

#import "DefaultImageCompressor.h"
#import "ObjcImgPressAnTool.h"

@implementation DefaultImageCompressor

- (NSData * _Nullable)compressImage:(UIImage *)image error:(NSError * _Nullable * _Nullable)error {
    ObjcImgPressAnOutput *output = [ObjcImgPressAnTool compressImageForUploadKilobyteRange200To600:image error:error];
    if (output) {
        return output.data;
    }
    return nil;
}

- (NSString *)compressorName {
    return @"ObjcImgPressAnTool";
}

@end