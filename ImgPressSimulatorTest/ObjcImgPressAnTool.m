//
//  ObjcImgPressAnTool.m
//  ImgPressTool
//

#import "ObjcImgPressAnTool.h"

NSString * const ObjcImgPressAnToolErrorDomain = @"ObjcImgPressAnToolErrorDomain";

#pragma mark - ObjcImgPressAnOutput

@interface ObjcImgPressAnOutput ()
@property (nonatomic, copy, nullable) NSString *cachedBase64;
@property (nonatomic, strong) NSLock *base64Lock;
@end

@implementation ObjcImgPressAnOutput

- (instancetype)initWithData:(NSData *)data image:(UIImage *)image {
    self = [super init];
    if (self) {
        _data = [data copy];
        _image = image;
        _base64Lock = [[NSLock alloc] init];
    }
    return self;
}

- (NSString *)base64 {
    [self.base64Lock lock];
    @try {
        if (self.cachedBase64) {
            return self.cachedBase64;
        }
        NSString *s = [_data base64EncodedStringWithOptions:0];
        self.cachedBase64 = [s copy];
        return self.cachedBase64;
    } @finally {
        [self.base64Lock unlock];
    }
}

@end

#pragma mark - Engine (static)

static CGSize IPTANPixelSize(UIImage *img) {
    return CGSizeMake(img.size.width * img.scale, img.size.height * img.scale);
}

static BOOL IPTANByteCountFromKB(NSInteger kb, NSInteger *outBytes) {
    if (kb < 0) {
        return NO;
    }
    int64_t v = (int64_t)kb * 1024;
    if (v > INT_MAX) {
        return NO;
    }
    *outBytes = (NSInteger)v;
    return YES;
}

static CGFloat IPTANClampedQuality(CGFloat q) {
    if (q < 0) {
        return 0;
    }
    if (q > 1) {
        return 1;
    }
    return q;
}

static UIImage *IPTANNormalizedUpright(UIImage *image) {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    }];
}

static UIImage *IPTANRender(UIImage *image, CGSize pixelSize) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:pixelSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [image drawInRect:CGRectMake(0, 0, pixelSize.width, pixelSize.height)];
    }];
}

static UIImage *IPTANScaledToLongEdgeAtLeast(UIImage *img, CGFloat minLongEdge) {
    CGSize px = IPTANPixelSize(img);
    CGFloat longEdge = MAX(px.width, px.height);
    if (longEdge <= 0 || longEdge >= minLongEdge) {
        return img;
    }
    CGFloat ratio = minLongEdge / longEdge;
    CGSize newSize = CGSizeMake(floor(px.width * ratio), floor(px.height * ratio));
    return IPTANRender(img, newSize);
}

static UIImage *IPTANScaledToPixelLongEdge(UIImage *img, CGFloat targetLongEdge) {
    CGSize px = IPTANPixelSize(img);
    CGFloat longEdge = MAX(px.width, px.height);
    if (longEdge <= 0 || targetLongEdge <= 0) {
        return img;
    }
    CGFloat ratio = targetLongEdge / longEdge;
    CGSize newSize = CGSizeMake(MAX(1, floor(px.width * ratio)), MAX(1, floor(px.height * ratio)));
    return IPTANRender(img, newSize);
}

static UIImage *IPTANScaledToFitMaxPixelDimension(UIImage *img, CGFloat maxPixelDimension) {
    CGSize px = IPTANPixelSize(img);
    CGFloat longEdge = MAX(px.width, px.height);
    if (!(longEdge > maxPixelDimension && longEdge > 0)) {
        return img;
    }
    CGFloat r = maxPixelDimension / longEdge;
    CGSize newSize = CGSizeMake(floor(px.width * r), floor(px.height * r));
    return IPTANRender(img, newSize);
}

static ObjcImgPressAnOutput * _Nullable IPTANMakeCompressOutput(NSData *data) {
    UIImage *image = [UIImage imageWithData:data];
    if (!image) {
        return nil;
    }
    return [[ObjcImgPressAnOutput alloc] initWithData:data image:image];
}

/// `requireFits`: 与 Swift `requireMinQualityFits` 一致。
static NSData * _Nullable IPTANJPEGBinarySearch(UIImage *image, NSInteger maxBytes, BOOL requireFits, NSInteger iterations) {
    if (requireFits) {
        NSData *minData = UIImageJPEGRepresentation(image, 0.02);
        if (!minData || (NSInteger)minData.length > maxBytes) {
            return nil;
        }
        NSData *maxData = UIImageJPEGRepresentation(image, 1.0);
        if (maxData && (NSInteger)maxData.length <= maxBytes) {
            return maxData;
        }
        CGFloat lo = 0.02f;
        CGFloat hi = 1.0f;
        NSData *best = minData;
        for (NSInteger i = 0; i < iterations; i++) {
            @autoreleasepool {
                CGFloat mid = (lo + hi) / 2.0f;
                NSData *d = UIImageJPEGRepresentation(image, mid);
                if (!d) {
                    return nil;
                }
                if ((NSInteger)d.length <= maxBytes) {
                    best = d;
                    lo = mid;
                } else {
                    hi = mid;
                }
            }
        }
        return best;
    }
    NSData *best = nil;
    CGFloat lo = 0.02f;
    CGFloat hi = 1.0f;
    for (NSInteger i = 0; i < iterations; i++) {
        @autoreleasepool {
            CGFloat mid = (lo + hi) / 2.0f;
            NSData *d = UIImageJPEGRepresentation(image, mid);
            if (!d) {
                return nil;
            }
            if ((NSInteger)d.length <= maxBytes) {
                best = d;
                lo = mid;
            } else {
                hi = mid;
            }
        }
    }
    return best;
}

static NSData * _Nullable IPTANCompressStrictlyUnderMax(UIImage *image, NSInteger maxBytes, CGFloat minimumLongEdgeHardFloor) {
    UIImage *img = image;
    BOOL allowBelowHardFloor = NO;
    for (int round = 0; round < 64; round++) {
        @autoreleasepool {
            NSData *data = IPTANJPEGBinarySearch(img, maxBytes, NO, 14);
            if (data) {
                return data;
            }
            CGSize px = IPTANPixelSize(img);
            CGFloat longEdge = MAX(px.width, px.height);
            if (longEdge <= 1) {
                return IPTANJPEGBinarySearch(img, maxBytes, NO, 14);
            }
            CGFloat floorLimit = allowBelowHardFloor ? 1 : minimumLongEdgeHardFloor;
            CGFloat newLE = floor(longEdge * 0.85);
            if (newLE < floorLimit) {
                if (longEdge > floorLimit) {
                    newLE = floorLimit;
                } else {
                    allowBelowHardFloor = YES;
                    newLE = MAX(1, floor(longEdge * 0.85));
                }
            }
            if (newLE >= longEdge - 0.5) {
                if (!allowBelowHardFloor && longEdge <= minimumLongEdgeHardFloor + 0.5) {
                    allowBelowHardFloor = YES;
                    newLE = MAX(1, floor(longEdge * 0.85));
                } else if (longEdge <= 2) {
                    return IPTANJPEGBinarySearch(img, maxBytes, NO, 14);
                } else {
                    newLE = MAX(1, longEdge - 1);
                }
            }
            CGFloat scale = newLE / longEdge;
            CGSize newSize = CGSizeMake(MAX(1, floor(px.width * scale)), MAX(1, floor(px.height * scale)));
            img = IPTANRender(img, newSize);
        }
    }
    return IPTANJPEGBinarySearch(img, maxBytes, NO, 14);
}

static ObjcImgPressAnOutput * _Nullable IPTANMakeCompressOutputWhenJPEGUnderBudget(UIImage *working, NSData *jpegData, NSInteger maxBytes, CGFloat longEdgeHardFloor) {
    CGSize px = IPTANPixelSize(working);
    CGFloat longEdge = MAX(px.width, px.height);
    /// 与 Swift `makeCompressOutputWhenJPEGUnderBudget` 一致：长边 **≥** 硬下限即可直出首包。
    if (longEdge >= longEdgeHardFloor) {
        return IPTANMakeCompressOutput(jpegData);
    }
    // 不接纳比原首包更大的重编码；有效上限 = min(上传 max，首包 jpg 体积)
    NSInteger cap = MAX(1, MIN(maxBytes, (NSInteger)jpegData.length));
    UIImage *img = IPTANScaledToLongEdgeAtLeast(working, longEdgeHardFloor);
    NSData *q1 = UIImageJPEGRepresentation(img, 1.0);
    if (q1 && (NSInteger)q1.length <= cap) {
        return IPTANMakeCompressOutput(q1);
    }
    NSData *fitted = IPTANJPEGBinarySearch(img, cap, YES, 18);
    if (fitted) {
        return IPTANMakeCompressOutput(fitted);
    }
    for (int i = 0; i < 32; i++) {
        BOOL tooSmall = NO;
        ObjcImgPressAnOutput *found = nil;
        @autoreleasepool {
            CGSize ipx = IPTANPixelSize(img);
            CGFloat le = MAX(ipx.width, ipx.height);
            if (le <= 2) {
                tooSmall = YES;
            } else {
                CGFloat newLE = MAX(2, floor(le * 0.92));
                img = IPTANScaledToPixelLongEdge(img, newLE);
                NSData *d = IPTANJPEGBinarySearch(img, cap, YES, 18);
                if (d) {
                    found = IPTANMakeCompressOutput(d);
                }
            }
        }
        if (found) {
            return found;
        }
        if (tooSmall) {
            break;
        }
    }
    NSData *guaranteed = IPTANCompressStrictlyUnderMax(img, cap, longEdgeHardFloor);
    if (guaranteed) {
        return IPTANMakeCompressOutput(guaranteed);
    }
    return IPTANMakeCompressOutput(jpegData);
}

static NSData * _Nullable IPTANCompressImageToSize(UIImage *image,
                                                   NSInteger targetMinBytes,
                                                   NSInteger targetMaxBytes,
                                                   NSData * _Nullable existingJPEGAtQuality1,
                                                   CGFloat minimumJPEGQuality,
                                                   CGFloat minimumLongEdgePixels,
                                                   CGFloat minimumLongEdgeHardFloor) {
    UIImage *currentImage = image;
    NSData *currentData = nil;
    if (existingJPEGAtQuality1) {
        currentData = existingJPEGAtQuality1;
    } else {
        currentData = UIImageJPEGRepresentation(image, 1.0);
        if (!currentData) {
            return nil;
        }
    }

    CGFloat qualityFloor = IPTANClampedQuality(minimumJPEGQuality);
    BOOL hasQualityFloor = qualityFloor > 0;
    CGFloat longEdgeFloor = MAX(0, minimumLongEdgePixels);

    if ((NSInteger)currentData.length <= targetMaxBytes) {
        return currentData;
    }

    CGFloat lowQuality = hasQualityFloor ? qualityFloor : 0.0f;
    CGFloat highQuality = 1.0f;
    NSData *bestData = nil;

    if ((NSInteger)currentData.length > targetMaxBytes) {
        double ratio = (double)targetMaxBytes / (double)MAX((NSInteger)currentData.length, 1);
        CGFloat probeQ = (CGFloat)pow(MAX(ratio, 1e-8), 0.52);
        if (hasQualityFloor) {
            probeQ = MAX(probeQ, qualityFloor);
        }
        probeQ = MIN(MAX(probeQ, 0.03f), 0.995f);
        NSData *probeOK = nil;
        @autoreleasepool {
            NSData *probeData = UIImageJPEGRepresentation(currentImage, probeQ);
            if (probeData) {
                if ((NSInteger)probeData.length <= targetMaxBytes) {
                    bestData = probeData;
                    lowQuality = probeQ;
                    highQuality = 1.0f;
                    if ((NSInteger)probeData.length >= targetMinBytes) {
                        probeOK = probeData;
                    }
                } else {
                    highQuality = probeQ;
                    lowQuality = hasQualityFloor ? qualityFloor : 0.0f;
                }
            }
        }
        if (probeOK) {
            return probeOK;
        }
    }

    for (int iter = 0; iter < 12; iter++) {
        NSData *earlyOut = nil;
        BOOL encodeBreak = NO;
        @autoreleasepool {
            CGFloat midQuality = MAX((lowQuality + highQuality) / 2.0f, hasQualityFloor ? qualityFloor : 0);
            NSData *testData = UIImageJPEGRepresentation(currentImage, midQuality);
            if (!testData) {
                encodeBreak = YES;
            } else if ((NSInteger)testData.length > targetMaxBytes) {
                highQuality = midQuality;
            } else {
                bestData = testData;
                lowQuality = midQuality;
                if ((NSInteger)testData.length >= targetMinBytes) {
                    earlyOut = testData;
                }
            }
        }
        if (encodeBreak) {
            break;
        }
        if (earlyOut) {
            return earlyOut;
        }
    }

    if (bestData && (NSInteger)bestData.length < targetMinBytes) {
        CGFloat startQ = MAX(lowQuality + 0.02f, hasQualityFloor ? qualityFloor : 0);
        for (CGFloat quality = startQ; quality <= 1.0f + 1e-6f; quality += 0.02f) {
            NSData *stepOut = nil;
            BOOL stepBreak = NO;
            @autoreleasepool {
                CGFloat q = MAX(quality, hasQualityFloor ? qualityFloor : 0);
                NSData *betterData = UIImageJPEGRepresentation(currentImage, q);
                if (!betterData) {
                    stepBreak = YES;
                } else if ((NSInteger)betterData.length >= targetMinBytes) {
                    stepOut = betterData;
                } else if ((NSInteger)betterData.length > targetMaxBytes) {
                    stepBreak = YES;
                }
            }
            if (stepOut) {
                return stepOut;
            }
            if (stepBreak) {
                break;
            }
        }
        UIImage *bestImg = [UIImage imageWithData:bestData];
        if (bestImg) {
            return IPTANCompressStrictlyUnderMax(bestImg, targetMaxBytes, minimumLongEdgeHardFloor);
        }
        return bestData;
    }

    if (!bestData || (NSInteger)bestData.length > targetMaxBytes) {
        UIImage *resizedImage = currentImage;
        NSInteger lastDataSize = (NSInteger)currentData.length;

        while (resizedImage && lastDataSize > targetMaxBytes) {
            NSData *recurseData = nil;
            BOOL stopShrink = NO;
            @autoreleasepool {
                CGSize rpx = IPTANPixelSize(resizedImage);
                CGFloat longEdge = MAX(rpx.width, rpx.height);
                if (longEdgeFloor > 0 && longEdge <= longEdgeFloor) {
                    stopShrink = YES;
                } else {
                    double ratio = sqrt((double)targetMaxBytes / (double)lastDataSize) * 0.96;
                    double clamped = MIN(MAX(ratio, 0.66), 0.96);
                    if (longEdgeFloor > 0) {
                        CGFloat minScale = longEdgeFloor / longEdge;
                        clamped = MAX(clamped, minScale);
                    }
                    if (clamped >= 0.999) {
                        stopShrink = YES;
                    } else if (longEdge * (CGFloat)clamped < 32) {
                        stopShrink = YES;
                    } else {
                        CGFloat newW = MAX(1, floor(rpx.width * (CGFloat)clamped));
                        CGFloat newH = MAX(1, floor(rpx.height * (CGFloat)clamped));
                        CGSize newSize = CGSizeMake(newW, newH);
                        UIImage *newImage = IPTANRender(resizedImage, newSize);
                        resizedImage = newImage;
                        currentImage = newImage;
                        NSData *newData = UIImageJPEGRepresentation(newImage, 0.9);
                        if (!newData) {
                            stopShrink = YES;
                        } else {
                            lastDataSize = (NSInteger)newData.length;
                            if (lastDataSize <= targetMaxBytes) {
                                recurseData = IPTANCompressImageToSize(newImage, targetMinBytes, targetMaxBytes, nil,
                                                                     qualityFloor, longEdgeFloor, minimumLongEdgeHardFloor);
                            }
                        }
                    }
                }
            }
            if (recurseData) {
                return recurseData;
            }
            if (stopShrink) {
                break;
            }
        }
    }

    return IPTANCompressStrictlyUnderMax(currentImage, targetMaxBytes, minimumLongEdgeHardFloor);
}

static NSError *IPTANMakeError(ObjcImgPressAnToolErrorCode code) {
    NSString *msg = @"";
    switch (code) {
        case ObjcImgPressAnToolErrorInvalidKBRange:
            msg = @"Invalid KB range or byte overflow.";
            break;
        case ObjcImgPressAnToolErrorUnableToEncode:
            msg = @"Unable to encode JPEG.";
            break;
        case ObjcImgPressAnToolErrorUnableToReachTarget:
            msg = @"Unable to reach target size range.";
            break;
        default:
            break;
    }
    return [NSError errorWithDomain:ObjcImgPressAnToolErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
}

#pragma mark - ObjcImgPressAnTool

@implementation ObjcImgPressAnTool

+ (nullable ObjcImgPressAnOutput *)compressImageForUploadKilobyteRange200To600:(UIImage *)image
                                                                         error:(NSError * _Nullable * _Nullable)outError {
    NSInteger minB = 0;
    NSInteger maxB = 0;
    if (!IPTANByteCountFromKB(200, &minB) || !IPTANByteCountFromKB(600, &maxB)) {
        if (outError) {
            *outError = IPTANMakeError(ObjcImgPressAnToolErrorInvalidKBRange);
        }
        return nil;
    }
    const CGFloat kMaxPx = 4096.0f;
    const CGFloat kMinLE = 256.0f;
    UIImage *input = IPTANNormalizedUpright(image);
    UIImage *working = IPTANScaledToFitMaxPixelDimension(input, kMaxPx);
    NSData *j1 = UIImageJPEGRepresentation(working, 1.0);
    if (!j1) {
        if (outError) {
            *outError = IPTANMakeError(ObjcImgPressAnToolErrorUnableToEncode);
        }
        return nil;
    }
    if ((NSInteger)j1.length < minB) {
        ObjcImgPressAnOutput *out = IPTANMakeCompressOutput(j1);
        if (!out && outError) {
            *outError = IPTANMakeError(ObjcImgPressAnToolErrorUnableToEncode);
        }
        return out;
    }
    CGSize wpx = IPTANPixelSize(working);
    CGFloat le = MAX(wpx.width, wpx.height);
    if ((NSInteger)j1.length <= maxB && le >= kMinLE) {
        ObjcImgPressAnOutput *out = IPTANMakeCompressOutput(j1);
        if (!out && outError) {
            *outError = IPTANMakeError(ObjcImgPressAnToolErrorUnableToEncode);
        }
        return out;
    }
    if ((NSInteger)j1.length <= maxB && le < kMinLE) {
        ObjcImgPressAnOutput *ub = IPTANMakeCompressOutputWhenJPEGUnderBudget(working, j1, maxB, kMinLE);
        if (ub) {
            return ub;
        }
    }
    NSData *outData = IPTANCompressImageToSize(working, minB, maxB, j1, 0, kMinLE, kMinLE);
    if (!outData) {
        if (outError) {
            *outError = IPTANMakeError(ObjcImgPressAnToolErrorUnableToReachTarget);
        }
        return nil;
    }
    if ((NSInteger)outData.length > (NSInteger)j1.length && (NSInteger)j1.length <= maxB) {
        outData = j1;
    }
    ObjcImgPressAnOutput *fo = IPTANMakeCompressOutput(outData);
    if (!fo && outError) {
        *outError = IPTANMakeError(ObjcImgPressAnToolErrorUnableToEncode);
    }
    return fo;
}

+ (void)compressImageForUploadKilobyteRange200To600:(UIImage *)image
                                        completion:(ObjcImgPressAnToolUpload200to600Completion)completion {
    NSParameterAssert(completion);
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *err = nil;
        ObjcImgPressAnOutput *out = [self compressImageForUploadKilobyteRange200To600:image error:&err];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(out, err);
        });
    });
}

@end
