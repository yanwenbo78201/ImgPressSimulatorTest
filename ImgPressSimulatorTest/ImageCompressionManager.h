//
//  ImageCompressionManager.h
//  ImgPressSimulatorTest
//
//  Created by Computer on 09/05/26.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ImageCompressorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ImageCompressionManager : NSObject

/**
 获取单例
 
 @return 共享的压缩管理器实例
 */
+ (instancetype)sharedManager;

/**
 注册自定义压缩器
 
 @param compressor 实现了 ImageCompressorProtocol 的压缩器实例
 @param identifier 压缩器标识符（用于切换）
 */
- (void)registerCompressor:(id<ImageCompressorProtocol>)compressor withIdentifier:(NSString *)identifier;

/**
 设置当前使用的压缩器
 
 @param identifier 压缩器标识符，nil 则使用默认压缩器
 */
- (void)setActiveCompressorWithIdentifier:(NSString * _Nullable)identifier;

/**
 获取当前压缩器名称
 
 @return 当前压缩器名称
 */
- (NSString *)currentCompressorName;

/**
 压缩图片（使用当前激活的压缩器）
 
 @param image 输入的UIImage对象
 @param error 错误信息
 @return 压缩后的NSData，如果压缩失败返回nil
 */
- (NSData * _Nullable)compressImage:(UIImage *)image error:(NSError * _Nullable * _Nullable)error;

/**
 压缩图片（使用指定的压缩器）
 
 @param image 输入的UIImage对象
 @param identifier 压缩器标识符
 @param error 错误信息
 @return 压缩后的NSData，如果压缩失败返回nil
 */
- (NSData * _Nullable)compressImage:(UIImage *)image withCompressor:(NSString *)identifier error:(NSError * _Nullable * _Nullable)error;

/**
 获取已注册的所有压缩器标识符
 
 @return 标识符数组
 */
- (NSArray<NSString *> *)availableCompressors;

@end

NS_ASSUME_NONNULL_END