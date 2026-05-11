//
//  ObjcImgPressAnTool.h
//  ImgPressTool
//
//  Objective-C：仅公开 200–600 KB 上传压缩。使用说明见同目录：`ObjcImgPressAnTool-Objective-C-README.md`。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const ObjcImgPressAnToolErrorDomain;

typedef NS_ERROR_ENUM(ObjcImgPressAnToolErrorDomain, ObjcImgPressAnToolErrorCode) {
    ObjcImgPressAnToolErrorInvalidKBRange = 1,
    ObjcImgPressAnToolErrorUnableToEncode = 2,
    ObjcImgPressAnToolErrorUnableToReachTarget = 3,
};

@class ObjcImgPressAnOutput;

/// 200–600 KB 上传策略异步完成（成功时 `error == nil`；失败时 `output == nil`）。
typedef void (^ObjcImgPressAnToolUpload200to600Completion)(ObjcImgPressAnOutput * _Nullable output, NSError * _Nullable error);

/// 压缩结果：`data` 多为 JPEG；`base64` 首次访问时惰性计算并缓存。
@interface ObjcImgPressAnOutput : NSObject

@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, copy, readonly) NSString *base64;

- (instancetype)initWithData:(NSData *)data image:(UIImage *)image NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

/// 200–600 KB 上传压缩（长边 cap 4096、长边下限 256 等；实现见 `ObjcImgPressAnTool.m` 内私有管线）。
@interface ObjcImgPressAnTool : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 200–600 KB 上传策略；仅 `UIImage`。
+ (nullable ObjcImgPressAnOutput *)compressImageForUploadKilobyteRange200To600:(UIImage *)image
                                                                          error:(NSError * _Nullable * _Nullable)outError;

/// 同上，后台队列执行，主线程回调 `completion`（不可为 `NULL`）。
+ (void)compressImageForUploadKilobyteRange200To600:(UIImage *)image
                                          completion:(ObjcImgPressAnToolUpload200to600Completion)completion;

@end

NS_ASSUME_NONNULL_END
