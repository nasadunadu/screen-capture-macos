import CoreGraphics

enum ImageEffects {
    static func apply(to image: CGImage, options: ExportOptions) -> CGImage {
        let radius = max(0, options.cornerRadius)
        let shadowPadding: CGFloat = options.shadowEnabled ? 28 : 0
        guard radius > 0 || options.shadowEnabled else { return image }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let outputWidth = Int(width + shadowPadding * 2)
        let outputHeight = Int(height + shadowPadding * 2)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        let target = CGRect(x: shadowPadding, y: shadowPadding, width: width, height: height)
        let path = CGPath(roundedRect: target, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        if options.shadowEnabled {
            context.setShadow(
                offset: CGSize(width: 0, height: -8),
                blur: 18,
                color: CGColor(gray: 0, alpha: 0.38)
            )
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        context.addPath(path)
        context.clip()
        context.draw(image, in: target)
        if options.shadowEnabled { context.endTransparencyLayer() }
        context.restoreGState()
        return context.makeImage() ?? image
    }
}
