//
//  ImageCompressorProtocol.h
//  ImgPressSimulatorTest
//
//  Created by Computer on 09/05/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ImageCompressorProtocol <NSObject>

/**
 压缩图片
 
 @param image 输入的UIImage对象
 @param error 错误信息
 @return 压缩后的NSData，如果压缩失败返回nil
 */
- (NSData * _Nullable)compressImage:(UIImage *)image error:(NSError * _Nullable * _Nullable)error;

/**
 获取压缩器名称
 
 @return 压缩器名称，用于标识
 */
- (NSString *)compressorName;

@end

NS_ASSUME_NONNULL_END