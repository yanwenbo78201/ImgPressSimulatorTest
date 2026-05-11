//
//  ImageCompressionManager.m
//  ImgPressSimulatorTest
//
//  Created by Computer on 09/05/26.
//

#import "ImageCompressionManager.h"
#import "DefaultImageCompressor.h"

@interface ImageCompressionManager ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, id<ImageCompressorProtocol>> *compressors;
@property (nonatomic, strong) NSString *activeCompressorIdentifier;
@property (nonatomic, strong) id<ImageCompressorProtocol> defaultCompressor;

@end

@implementation ImageCompressionManager

+ (instancetype)sharedManager {
    static ImageCompressionManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _compressors = [NSMutableDictionary dictionary];
        _defaultCompressor = [[DefaultImageCompressor alloc] init];
        _activeCompressorIdentifier = nil; // nil 表示使用默认压缩器
    }
    return self;
}

- (void)registerCompressor:(id<ImageCompressorProtocol>)compressor withIdentifier:(NSString *)identifier {
    if (compressor && identifier) {
        [_compressors setObject:compressor forKey:identifier];
    }
}

- (void)setActiveCompressorWithIdentifier:(NSString * _Nullable)identifier {
    _activeCompressorIdentifier = identifier;
}

- (NSString *)currentCompressorName {
    id<ImageCompressorProtocol> compressor = [self activeCompressor];
    return [compressor compressorName];
}

- (id<ImageCompressorProtocol>)activeCompressor {
    if (_activeCompressorIdentifier) {
        id<ImageCompressorProtocol> compressor = _compressors[_activeCompressorIdentifier];
        if (compressor) {
            return compressor;
        }
    }
    return _defaultCompressor;
}

- (NSData * _Nullable)compressImage:(UIImage *)image error:(NSError * _Nullable * _Nullable)error {
    id<ImageCompressorProtocol> compressor = [self activeCompressor];
    return [compressor compressImage:image error:error];
}

- (NSData * _Nullable)compressImage:(UIImage *)image withCompressor:(NSString *)identifier error:(NSError * _Nullable * _Nullable)error {
    id<ImageCompressorProtocol> compressor = _compressors[identifier];
    if (!compressor) {
        if (error) {
            *error = [NSError errorWithDomain:@"ImageCompressionManager"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"未找到标识符为 '%@' 的压缩器", identifier]}];
        }
        return nil;
    }
    return [compressor compressImage:image error:error];
}

- (NSArray<NSString *> *)availableCompressors {
    NSMutableArray *result = [NSMutableArray array];
    [result addObject:@"default"]; // 默认压缩器标识符
    [result addObjectsFromArray:_compressors.allKeys];
    return [result copy];
}

@end