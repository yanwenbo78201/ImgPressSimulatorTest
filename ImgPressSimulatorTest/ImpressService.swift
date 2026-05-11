//
//  ObjcImgPressAnTool.swift
//  ImgPressTool
//
//  图片压缩：对外仅提供 **200–600 KB 上传**（与 `ObjcImgPressAnTool` 同策略）。
//  入口：`enum ImpressService`。使用说明见同目录：`ObjcImgPressAnTool-Swift-README.md`。
//

import UIKit

// MARK: - 公开类型

/// 压缩流程中的可恢复错误（与 `Result` 配合使用）。
@objc public enum ImpressError: Int, Error, Equatable {
    case invalidKBRange = 0
    case unableToEncode = 1
    case unableToReachTarget = 2
}

/// 压缩结果：`data` 多为 JPEG；`base64` 首次读取时计算并缓存。
@objc public final class ImpressOutput: NSObject {
   @objc public let data: Data
   @objc public let image: UIImage

    private var cachedBase64: String?
    private let base64Lock = NSLock()

    @objc public var base64: String {
        base64Lock.lock()
        defer { base64Lock.unlock() }
        if let c = cachedBase64 { return c }
        let s = data.base64EncodedString()
        cachedBase64 = s
        return s
    }

    init(data: Data, image: UIImage) {
        self.data = data
        self.image = image
    }
}

// MARK: - 入口（仅 200–600 KB）

/// **仅** 200–600 KB 上传策略：长边 cap 4096、长边下限 256，行为与头文件 `ObjcImgPressAnTool.h` 中上传 API 一致。
@objc public final class ImpressService: NSObject {
    /// 上传：先归一、长边 cap **≤ 4096** 后 `jpg(1.0)` 得首包。
    /// - **&lt; 200KB**：不检查长边，直传首包。
    /// - **200–600KB**：长边 **≥ 256** 直传；长边 &lt; 256 时在 ≤600KB 内拉至长边 **≥ 256**（不刻意比首包更大）。
    /// - **&gt; 600KB**：压入 **200–600KB**。
   public static func compressForUpload200to600(image: UIImage) -> Result<ImpressOutput, ImpressError> {
        let minKB = 200
        let maxKB = 600
        let maxPixel: CGFloat = 4096
        let minLE: CGFloat = 256
        guard let minB = ImpressEngine.byteCount(fromKB: minKB),
              let maxB = ImpressEngine.byteCount(fromKB: maxKB) else {
            return .failure(.invalidKBRange)
        }
        let input = image.ipan_imageByNormalizingOrientation()
        let working = input.ipan_scaledToFitMaxPixelLength(maxPixel)
        guard let j1 = working.jpegData(compressionQuality: 1.0) else { return .failure(.unableToEncode) }
        if j1.count < minB {
            return ImpressEngine.makeCompressOutput(data: j1).map { .success($0) } ?? .failure(.unableToEncode)
        }
        let le = max(working.ipan_pixelDimensions.width, working.ipan_pixelDimensions.height)
        if j1.count <= maxB, le >= minLE {
            return ImpressEngine.makeCompressOutput(data: j1).map { .success($0) } ?? .failure(.unableToEncode)
        }
        if j1.count <= maxB, le < minLE,
           let o = ImpressEngine.makeCompressOutputWhenJPEGUnderBudget(
               working: working, jpegData: j1, maxBytes: maxB, longEdgeHardFloor: minLE
           ) { return .success(o) }
        guard var out = ImpressEngine.compressImageToSize(
            image: working,
            targetMinBytes: minB,
            targetMaxBytes: maxB,
            existingJPEGAtQuality1: j1,
            minimumJPEGQuality: 0,
            minimumLongEdgePixels: minLE,
            minimumLongEdgeHardFloor: minLE
        ) else { return .failure(.unableToReachTarget) }
        if out.count > j1.count, j1.count <= maxB {
            out = j1
        }
        return ImpressEngine.makeCompressOutput(data: out).map { .success($0) } ?? .failure(.unableToEncode)
    }

   @objc public static func compressForUpload200to600Optional(image: UIImage) -> ImpressOutput? {
        try? compressForUpload200to600(image: image).get()
    }

    public static func compressForUploadKilobyteRange200to600Async(
        image: UIImage,
        completion: @escaping (Result<ImpressOutput, ImpressError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let r = ImpressService.compressForUpload200to600(image: image)
            DispatchQueue.main.async { completion(r) }
        }
    }

    @objc public static func compressForUpload200to600Async(
        image: UIImage,
        completion: @escaping (ImpressOutput?, Error?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let r = ImpressService.compressForUpload200to600(image: image)
            DispatchQueue.main.async {
                switch r {
                case .success(let output):
                    completion(output, nil)
                case .failure(let error):
                    completion(nil, error)
                }
            }
        }
    }
}

// MARK: - UIImage 便捷

extension UIImage {
    func ipan_compressForUploadKilobyteRange200to600() -> Result<ImpressOutput, ImpressError> {
        ImpressService.compressForUpload200to600(image: self)
    }
}

// MARK: - 像素绘制

fileprivate enum ImpressRenderer {
    static func render(_ image: UIImage, pixelSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}

// MARK: - UIImage 像素工具

fileprivate extension UIImage {
    var ipan_pixelDimensions: CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }

    func ipan_imageByNormalizingOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }

    func ipan_scaledToMinimumLongEdge(_ minLongEdge: CGFloat) -> UIImage {
        let px = ipan_pixelDimensions
        let longEdge = max(px.width, px.height)
        guard longEdge > 0, longEdge < minLongEdge else { return self }
        let ratio = minLongEdge / longEdge
        let newSize = CGSize(width: floor(px.width * ratio), height: floor(px.height * ratio))
        return ImpressRenderer.render(self, pixelSize: newSize)
    }

    func ipan_scaledToTargetLongEdge(_ targetLongEdge: CGFloat) -> UIImage {
        let px = ipan_pixelDimensions
        let longEdge = max(px.width, px.height)
        guard longEdge > 0, targetLongEdge > 0 else { return self }
        let ratio = targetLongEdge / longEdge
        let newSize = CGSize(width: max(1, floor(px.width * ratio)), height: max(1, floor(px.height * ratio)))
        return ImpressRenderer.render(self, pixelSize: newSize)
    }

    func ipan_scaledToFitMaxPixelLength(_ maxPixelLength: CGFloat) -> UIImage {
        let px = ipan_pixelDimensions
        let longEdge = max(px.width, px.height)
        guard longEdge > maxPixelLength, longEdge > 0 else { return self }
        let ratio = maxPixelLength / longEdge
        let newSize = CGSize(width: floor(px.width * ratio), height: floor(px.height * ratio))
        return ImpressRenderer.render(self, pixelSize: newSize)
    }
}

// MARK: - 核心引擎

fileprivate enum ImpressEngine {
    static func byteCount(fromKB kb: Int) -> Int? {
        guard kb >= 0 else { return nil }
        let v = Int64(kb) * 1024
        guard v <= Int64(Int.max) else { return nil }
        return Int(v)
    }

    static func clampedQuality(_ q: CGFloat) -> CGFloat {
        min(max(q, 0), 1)
    }

    static func makeCompressOutput(data: Data) -> ImpressOutput? {
        guard let image = UIImage(data: data) else { return nil }
        return ImpressOutput(data: data, image: image)
    }

    static func jpegDataBinarySearchBestFit(
        image: UIImage,
        maxBytes: Int,
        requireMinQualityFits: Bool,
        iterations: Int
    ) -> Data? {
        if requireMinQualityFits {
            guard let minData = image.jpegData(compressionQuality: 0.02) else { return nil }
            if minData.count > maxBytes { return nil }
            if let maxData = image.jpegData(compressionQuality: 1.0), maxData.count <= maxBytes {
                return maxData
            }
            var lo: CGFloat = 0.02
            var hi: CGFloat = 1.0
            var best = minData
            for _ in 0..<iterations {
                var encodeFailed = false
                autoreleasepool {
                    let mid = (lo + hi) / 2
                    guard let d = image.jpegData(compressionQuality: mid) else {
                        encodeFailed = true
                        return
                    }
                    if d.count <= maxBytes {
                        best = d
                        lo = mid
                    } else {
                        hi = mid
                    }
                }
                if encodeFailed { return nil }
            }
            return best
        }
        var best: Data?
        var lo: CGFloat = 0.02
        var hi: CGFloat = 1.0
        for _ in 0..<iterations {
            var encodeFailed = false
            autoreleasepool {
                let mid = (lo + hi) / 2
                guard let d = image.jpegData(compressionQuality: mid) else {
                    encodeFailed = true
                    return
                }
                if d.count <= maxBytes {
                    best = d
                    lo = mid
                } else {
                    hi = mid
                }
            }
            if encodeFailed { return nil }
        }
        return best
    }

    static func makeCompressOutputWhenJPEGUnderBudget(working: UIImage, jpegData: Data, maxBytes: Int, longEdgeHardFloor: CGFloat) -> ImpressOutput? {
        let px = working.ipan_pixelDimensions
        let longEdge = max(px.width, px.height)
        if longEdge >= longEdgeHardFloor {
            return makeCompressOutput(data: jpegData)
        }
        let cap = min(maxBytes, max(1, jpegData.count))
        var img = working.ipan_scaledToMinimumLongEdge(longEdgeHardFloor)
        if let q1 = img.jpegData(compressionQuality: 1.0), q1.count <= cap {
            return makeCompressOutput(data: q1)
        }
        if let fitted = jpegDataBinarySearchBestFit(image: img, maxBytes: cap, requireMinQualityFits: true, iterations: 18) {
            return makeCompressOutput(data: fitted)
        }
        for _ in 0..<32 {
            var done: ImpressOutput?
            var tooSmall = false
            autoreleasepool {
                let le = max(img.ipan_pixelDimensions.width, img.ipan_pixelDimensions.height)
                guard le > 2 else { tooSmall = true; return }
                let newLE = max(2, floor(le * 0.92))
                img = img.ipan_scaledToTargetLongEdge(newLE)
                if let d = jpegDataBinarySearchBestFit(image: img, maxBytes: cap, requireMinQualityFits: true, iterations: 18) {
                    done = makeCompressOutput(data: d)
                }
            }
            if let out = done { return out }
            if tooSmall { break }
        }
        if let guaranteed = compressStrictlyUnderMax(image: img, maxBytes: cap, minimumLongEdgeHardFloor: longEdgeHardFloor) {
            return makeCompressOutput(data: guaranteed)
        }
        return makeCompressOutput(data: jpegData)
    }

    static func compressImageToSize(
        image: UIImage,
        targetMinBytes: Int,
        targetMaxBytes: Int,
        existingJPEGAtQuality1: Data? = nil,
        minimumJPEGQuality: CGFloat = 0,
        minimumLongEdgePixels: CGFloat = 0,
        minimumLongEdgeHardFloor: CGFloat
    ) -> Data? {
        var currentImage: UIImage? = image
        let currentData: Data
        if let existing = existingJPEGAtQuality1 {
            currentData = existing
        } else if let encoded = image.jpegData(compressionQuality: 1.0) {
            currentData = encoded
        } else {
            return nil
        }

        let qualityFloor = clampedQuality(minimumJPEGQuality)
        let hasQualityFloor = qualityFloor > 0
        let longEdgeFloor = max(0, minimumLongEdgePixels)

        if currentData.count <= targetMaxBytes {
            return currentData
        }

        var lowQuality: CGFloat = hasQualityFloor ? qualityFloor : 0.0
        var highQuality: CGFloat = 1.0
        var bestData: Data?

        if currentData.count > targetMaxBytes {
            let ratio = Double(targetMaxBytes) / Double(max(currentData.count, 1))
            var probeQ = CGFloat(pow(max(ratio, 1e-8), 0.52))
            if hasQualityFloor { probeQ = max(probeQ, qualityFloor) }
            probeQ = min(max(probeQ, 0.03), 0.995)
            var probeOK: Data?
            autoreleasepool {
                if let probeData = currentImage?.jpegData(compressionQuality: probeQ) {
                    if probeData.count <= targetMaxBytes {
                        bestData = probeData
                        lowQuality = probeQ
                        highQuality = 1.0
                        if probeData.count >= targetMinBytes {
                            probeOK = probeData
                        }
                    } else {
                        highQuality = probeQ
                        lowQuality = hasQualityFloor ? qualityFloor : 0.0
                    }
                }
            }
            if let d = probeOK { return d }
        }

        for _ in 0..<12 {
            var earlyOK: Data?
            var encodeBreak = false
            autoreleasepool {
                let midQuality = max((lowQuality + highQuality) / 2, hasQualityFloor ? qualityFloor : 0)
                guard let testData = currentImage?.jpegData(compressionQuality: midQuality) else {
                    encodeBreak = true
                    return
                }
                if testData.count > targetMaxBytes {
                    highQuality = midQuality
                } else {
                    bestData = testData
                    lowQuality = midQuality
                    if testData.count >= targetMinBytes {
                        earlyOK = testData
                    }
                }
            }
            if encodeBreak { break }
            if let ok = earlyOK { return ok }
        }

        if let best = bestData, best.count < targetMinBytes {
            let startQ = max(lowQuality + 0.02, hasQualityFloor ? qualityFloor : 0)
            for quality in stride(from: startQ, through: 1.0, by: 0.02) {
                var stepExit: Data?
                var stepBreak = false
                autoreleasepool {
                    let q = max(quality, hasQualityFloor ? qualityFloor : 0)
                    guard let betterData = currentImage?.jpegData(compressionQuality: q) else { stepBreak = true; return }
                    if betterData.count >= targetMinBytes {
                        stepExit = betterData
                    } else if betterData.count > targetMaxBytes {
                        stepBreak = true
                    }
                }
                if let d = stepExit { return d }
                if stepBreak { break }
            }
            if let bestImg = UIImage(data: best) {
                return compressStrictlyUnderMax(image: bestImg, maxBytes: targetMaxBytes, minimumLongEdgeHardFloor: minimumLongEdgeHardFloor)
            }
            return best
        }

        if bestData == nil || bestData!.count > targetMaxBytes {
            var resizedImage = currentImage
            var lastDataSize = currentData.count

            while let img = resizedImage, lastDataSize > targetMaxBytes {
                var recurseData: Data?
                var stopShrink = false
                autoreleasepool {
                    let px = img.ipan_pixelDimensions
                    let longEdge = max(px.width, px.height)
                    if longEdgeFloor > 0, longEdge <= longEdgeFloor {
                        stopShrink = true
                        return
                    }
                    let ratio = sqrt(Double(targetMaxBytes) / Double(lastDataSize)) * 0.96
                    var clamped = min(max(ratio, 0.66), 0.96)
                    if longEdgeFloor > 0 {
                        let minScale = CGFloat(longEdgeFloor) / longEdge
                        clamped = max(clamped, minScale)
                    }
                    if clamped >= 0.999 {
                        stopShrink = true
                        return
                    }
                    if longEdge * CGFloat(clamped) < 32 {
                        stopShrink = true
                        return
                    }
                    let newW = max(1, floor(px.width * CGFloat(clamped)))
                    let newH = max(1, floor(px.height * CGFloat(clamped)))
                    let newSize = CGSize(width: newW, height: newH)
                    let newImage = ImpressRenderer.render(img, pixelSize: newSize)
                    resizedImage = newImage
                    currentImage = newImage
                    guard let newData = newImage.jpegData(compressionQuality: 0.9) else {
                        stopShrink = true
                        return
                    }
                    lastDataSize = newData.count
                    if newData.count <= targetMaxBytes {
                        recurseData = compressImageToSize(
                            image: newImage,
                            targetMinBytes: targetMinBytes,
                            targetMaxBytes: targetMaxBytes,
                            existingJPEGAtQuality1: nil,
                            minimumJPEGQuality: qualityFloor,
                            minimumLongEdgePixels: longEdgeFloor,
                            minimumLongEdgeHardFloor: minimumLongEdgeHardFloor
                        )
                    }
                }
                if let d = recurseData { return d }
                if stopShrink { break }
            }
        }

        guard let finalImage = currentImage else { return nil }
        return compressStrictlyUnderMax(image: finalImage, maxBytes: targetMaxBytes, minimumLongEdgeHardFloor: minimumLongEdgeHardFloor)
    }

    static func compressStrictlyUnderMax(image: UIImage, maxBytes: Int, minimumLongEdgeHardFloor: CGFloat) -> Data? {
        var img = image
        var allowBelowHardFloor = false
        for _ in 0..<64 {
            var earlyReturn: Data?
            autoreleasepool {
                if let data = jpegDataBinarySearchBestFit(image: img, maxBytes: maxBytes, requireMinQualityFits: false, iterations: 14) {
                    earlyReturn = data
                    return
                }
                let px = img.ipan_pixelDimensions
                let longEdge = max(px.width, px.height)
                if longEdge <= 1 {
                    earlyReturn = jpegDataBinarySearchBestFit(image: img, maxBytes: maxBytes, requireMinQualityFits: false, iterations: 14)
                    return
                }
                let floorLimit: CGFloat = allowBelowHardFloor ? 1 : minimumLongEdgeHardFloor
                var newLE = floor(longEdge * 0.85)
                if newLE < floorLimit {
                    if longEdge > floorLimit {
                        newLE = floorLimit
                    } else {
                        allowBelowHardFloor = true
                        newLE = max(1, floor(longEdge * 0.85))
                    }
                }
                if newLE >= longEdge - 0.5 {
                    if !allowBelowHardFloor && longEdge <= minimumLongEdgeHardFloor + 0.5 {
                        allowBelowHardFloor = true
                        newLE = max(1, floor(longEdge * 0.85))
                    } else if longEdge <= 2 {
                        earlyReturn = jpegDataBinarySearchBestFit(image: img, maxBytes: maxBytes, requireMinQualityFits: false, iterations: 14)
                        return
                    } else {
                        newLE = max(1, longEdge - 1)
                    }
                }
                let scale = newLE / longEdge
                let newSize = CGSize(width: max(1, floor(px.width * scale)), height: max(1, floor(px.height * scale)))
                img = ImpressRenderer.render(img, pixelSize: newSize)
            }
            if let d = earlyReturn { return d }
        }
        return autoreleasepool {
            jpegDataBinarySearchBestFit(image: img, maxBytes: maxBytes, requireMinQualityFits: false, iterations: 14)
        }
    }
}
