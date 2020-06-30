//
//  NSImage+WebpAndCGImage.m
//  WebPImageToolKit
//
//  Created by AnarLong on 30/06/2020.
//  Copyright © 2020 anarl. All rights reserved.
//

#import "NSImage+WebpAndCGImage.h"
#import <CoreGraphics/CoreGraphics.h>

static void free_image_data(void * info, const void * data, size_t size)
{
    if (info != NULL) {
        WebPFreeDecBuffer(&(((WebPDecoderConfig *)info)->output));
        free(info);
    }
    free((void *)data);
}

@implementation NSImage (WebpAndCGImage)

- (CGImageRef)CGImage
{
    NSData * data = [self TIFFRepresentation];
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    
    return imgRef;
}

#pragma mark - Private Methods

+ (NSData *)convertToWebP:(NSImage *)image
                  quality:(CGFloat)quality
                    alpha:(CGFloat)alpha
                   preset:(WebPPreset)preset
              configBlock:(void (^)(WebPConfig *))configBlock
                    error:(NSError **)error
{
    if (alpha < 1) {
        image = [NSImage webPImage:image withAlpha:alpha];
    }
    
    CGImageRef webpImageRef = [image CGImage];
    size_t webPBytesPerRow = CGImageGetBytesPerRow(webpImageRef);
    
    size_t webPImageWidth = CGImageGetWidth(webpImageRef);
    size_t webPImageHeight = CGImageGetHeight(webpImageRef);
    
    CGDataProviderRef webPDataProviderRef = CGImageGetDataProvider(webpImageRef);
    CFDataRef webPImageDataRef = CGDataProviderCopyData(webPDataProviderRef);
    
    uint8_t * webPImageData = (uint8_t *)CFDataGetBytePtr(webPImageDataRef);
    
    WebPConfig config;
    
    if (!WebPConfigPreset(&config, preset, quality)) {
        NSMutableDictionary * errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Configuration preset failed to initialize." forKey:NSLocalizedDescriptionKey];
        if (error != NULL) {
            NSString * domain = [NSString stringWithFormat:@"%@.errorDomain", [[NSBundle mainBundle] bundleIdentifier]];
            *error = [NSError errorWithDomain:domain code:-101 userInfo:errorDetail];
        }
        
        CFRelease(webPImageDataRef);
        return nil;
    }
    
    if (configBlock) {
        configBlock(&config);
    }
    
    if (!WebPValidateConfig(&config)) {
        NSMutableDictionary * errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"One or more configuration parameters are beyond thier valid ranges" forKey:NSLocalizedDescriptionKey];
        
        if (error != NULL) {
            NSString * domain = [NSString stringWithFormat:@"%@.errorDomain", [[NSBundle mainBundle] bundleIdentifier]];
            *error = [NSError errorWithDomain:domain code:-101 userInfo:errorDetail];
        }
        CFRelease(webPImageDataRef);
        return nil;
    }
    
    WebPPicture pic;
    if (!WebPPictureInit(&pic)) {
        NSMutableDictionary * errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to initialize structure. Version mismatch." forKey:NSLocalizedDescriptionKey];
        if (error != NULL) {
            NSString * domain = [NSString stringWithFormat:@"%@.errorDomain", [[NSBundle mainBundle] bundleIdentifier]];
            *error = [NSError errorWithDomain:domain code:-101 userInfo:errorDetail];
        }
        
        CFRelease(webPImageDataRef);
        return nil;
    }
    
    pic.width = (int)webPImageWidth;
    pic.height = (int)webPImageHeight;
    pic.colorspace = WEBP_YUV420;
    
    WebPPictureImportRGBA(&pic, webPImageData, (int)webPBytesPerRow);
    WebPPictureARGBToYUVA(&pic, WEBP_YUV420);
    WebPCleanupTransparentArea(&pic);
    
    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    
    pic.writer = WebPMemoryWrite;
    pic.custom_ptr = &writer;
    WebPEncode(&config, &pic);
    
    NSData * webPFinalData = [NSData dataWithBytes:writer.mem length:writer.size];
    
    free(writer.mem);
    WebPPictureFree(&pic);
    CFRelease(webPImageDataRef);
    
    return webPFinalData;
}


+ (NSImage *)imageWithWebP:(NSString *)filepath error:(NSError **)error
{
    NSError * dataError = nil;
    NSData * imgData = [NSData dataWithContentsOfFile:filepath options:NSDataReadingMappedIfSafe error:&dataError];
    if (dataError != nil) {
        *error = dataError;
        return nil;
    }
    return [NSImage imageWithWebpData:imgData error:error];
}

+ (NSImage *)imageWithWebpData:(NSData *)webpData error:(NSError **)error
{
    int width = 0, height = 0;
    if (!WebPGetInfo([webpData bytes], [webpData length], &width, &height)) {
        NSMutableDictionary * errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Header formatting error." forKey:NSLocalizedDescriptionKey];
        if (error != NULL) {
            NSString * domain = [NSString stringWithFormat:@"%@.errorDomain", [[NSBundle mainBundle] bundleIdentifier]];
            *error = [NSError errorWithDomain:domain code:-101 userInfo:errorDetail];
        }
        return nil;
    }
    
    WebPDecoderConfig * config = malloc(sizeof(WebPDecoderConfig));
    
    if (!WebPInitDecoderConfig(config)) {
        NSMutableDictionary * errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Failed to initialize structure. Version mismatch." forKey:NSLocalizedDescriptionKey];
        if (error != NULL) {
            NSString * domain = [NSString stringWithFormat:@"%@.errorDomain", [[NSBundle mainBundle] bundleIdentifier]];
            *error = [NSError errorWithDomain:domain code:-101 userInfo:errorDetail];
        }
        return nil;
    }
    
    config->options.no_fancy_upsampling = 1;
    config->options.bypass_filtering = 1;
    config->options.use_threads = 1;
    config->output.colorspace = MODE_RGBA;
    
    VP8StatusCode decodeStatus = WebPDecode([webpData bytes], [webpData length], config);
    if (decodeStatus != VP8_STATUS_OK) {
        NSString * errorString = [self statusForVP8Code:decodeStatus];
        NSMutableDictionary * errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:errorString forKey:NSLocalizedDescriptionKey];
        
        if (error != NULL) {
            NSString * domain = [NSString stringWithFormat:@"%@.errorDomain", [[NSBundle mainBundle] bundleIdentifier]];
            *error = [NSError errorWithDomain:domain code:-101 userInfo:errorDetail];
        }
        return nil;
    }
    
    uint8_t * data = WebPDecodeRGBA([webpData bytes], [webpData length], &width, &height);
    CGDataProviderRef providerRef = CGDataProviderCreateWithData(config, data, config->options.scaled_width * config->options.scaled_height * 4, free_image_data);
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault|kCGImageAlphaLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(width, height, 8, 32, 4 * width, colorSpaceRef, bitmapInfo, providerRef, NULL, YES, renderingIntent);
    NSImage * result = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(width, height)];
    
    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(providerRef);
    
    return result;
}

#pragma mark - Synchronous methods
+ (NSImage *)imageFromWebpImage:(NSString *)webpFile
{
    NSParameterAssert(webpFile != nil);
    return [self imageWithWebP:webpFile error:nil];
}

+ (NSImage *)imageWithWebpData:(NSData *)webpData
{
    NSParameterAssert(webpData != nil);
    return [self imageWithWebpData:webpData error:nil];
}

+ (NSData *)imageToWebp:(NSImage *)img quality:(CGFloat)quality
{
    NSParameterAssert(img != nil);
    NSParameterAssert(quality >= 0.0f && quality <= 100.0f);
    return [self convertToWebP:img quality:quality alpha:1.0f preset:WEBP_PRESET_DEFAULT configBlock:nil error:nil];
}

#pragma mark - Asynchronous methods
+ (void)imageWithWebp:(NSString *)filePath completionBlock:(void (^)(NSImage *))completionBlock failureBlock:(void (^)(NSError *))failureBlock
{
    NSParameterAssert(filePath != nil);
    NSParameterAssert(completionBlock != nil);
    NSParameterAssert(failureBlock != nil);
    
    dispatch_queue_t fromWebPQueue = dispatch_queue_create("com.digiarty.nsimagewebp.fromwebp", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(fromWebPQueue, ^{
        NSError * error = nil;
        NSImage * webPImage = [self imageWithWebP:filePath error:&error];
        
        if (webPImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(webPImage);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                failureBlock(error);
            });
        }
    });
}

+ (void)imageToWebP:(NSImage *)image quality:(CGFloat)quality alpha:(CGFloat)alpha preset:(WebPPreset)preset completioniBlock:(void (^)(NSData *))completionBlock failureBlock:(void (^)(NSError *))failureBlock
{
    [self imageToWebP:image quality:quality alpha:alpha preset:preset configBlock:nil completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)imageToWebP:(NSImage *)image quality:(CGFloat)quality alpha:(CGFloat)alpha preset:(WebPPreset)preset configBlock:(void (^)(WebPConfig *))configBlock completionBlock:(void (^)(NSData *))completionBlock failureBlock:(void (^)(NSError *))failureBlock
{
    NSAssert(image != nil, @"imageToWebP:quality:alpha:configBlock:completionBlock:failureBlock image cannot be nil");
    NSAssert(quality > 0 && quality < 100, @"imageToWebP:quality:alpha:configBlock:completionBlock:failureBlock quality has to be [0, 100]");
    NSAssert(alpha > 0 && alpha < 1, @"imageToWebP:quality:alpha:configBlock:completionBlock:failureBlock alpha has to be [0,1]");
    NSAssert(completionBlock != nil, @"imageToWebP:quality:alpha:configBlock:completionBlock:failureBlock completionBlock cannot be nil");
    NSAssert(failureBlock != nil, @"imageToWebP:quality:alpha:configBlock:completionBlock:failureBlock failureBlock cannot be nil");
    
    dispatch_queue_t toWebPQueue = dispatch_queue_create("com.digiarty.nsimagewebp.towebp", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(toWebPQueue, ^{
        NSError * error = nil;
        NSData * webPFinalData = [self convertToWebP:image quality:quality alpha:alpha preset:preset configBlock:configBlock error:&error];
        if (!error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(webPFinalData);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                failureBlock(error);
            });
        }
    });
    
}

#pragma mark - Utilities
- (NSImage *)imageByApplyingAlpha:(CGFloat)alpha
{
    NSParameterAssert(alpha >= 0.0f && alpha <= 100.0f);
    
    if (alpha <= 1) {
        NSImage * image = [[NSImage alloc] initWithSize:self.size];
        NSBitmapImageRep * rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:self.size.width pixelsHigh:self.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [image addRepresentation:rep];
        [image lockFocus];
        CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextClearRect(ctx, NSMakeRect(0, 0, self.size.width, self.size.height));
        CGContextSetFillColorWithColor(ctx, [[NSColor blueColor] CGColor]);
        CGContextFillEllipseInRect(ctx, NSMakeRect(0, 0, self.size.width, self.size.height));
        
        [image unlockFocus];
        
        return image;
    } else {
        return self;
    }
}

+ (NSImage *)webPImage:(NSImage *)image withAlpha:(CGFloat)alpha
{
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    UInt8 * pixelBuffer = malloc(height * width * 4);
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    
    CGContextRef context = CGBitmapContextCreate(pixelBuffer, width, height, bitsPerComponent, bytesPerRow, colorSpace, (kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big));
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    CGDataProviderRef dataProviderRef = CGImageGetDataProvider(imageRef);
    CFDataRef dataRef = CGDataProviderCopyData(dataProviderRef);
    
    GLubyte * pixels = (GLubyte*)CFDataGetBytePtr(dataRef);
    
    
    for (int y = 0; y < height; y ++) {
        for (int x = 0; x < width; x ++) {
            NSInteger byteIndex = ((width * 4) * y) + (x * 4);
            pixelBuffer[byteIndex + 3] = pixels[byteIndex + 3] * alpha;
        }
    }
    
    CGContextRef ctx = CGBitmapContextCreate(pixelBuffer, width, height, bitsPerComponent, bytesPerRow, colorSpace, (kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big));
    CGImageRef newImgRef = CGBitmapContextCreateImage(ctx);
    
    free(pixelBuffer);
    CFRelease(dataRef);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(ctx);
    
    NSImage * newImage = [[NSImage alloc] initWithCGImage:newImgRef size:NSMakeSize(width, height)];
    CGImageRelease(newImgRef);
    return newImage;
}

#pragma mark - Error status
+ (NSString *)statusForVP8Code:(VP8StatusCode)code
{
    NSString *errorString;
    switch (code) {
        case VP8_STATUS_OUT_OF_MEMORY:
            errorString = @"OUT_OF_MEMORY";
            break;
        case VP8_STATUS_INVALID_PARAM:
            errorString = @"INVALID_PARAM";
            break;
        case VP8_STATUS_BITSTREAM_ERROR:
            errorString = @"BITSTREAM_ERROR";
            break;
        case VP8_STATUS_UNSUPPORTED_FEATURE:
            errorString = @"UNSUPPORTED_FEATURE";
            break;
        case VP8_STATUS_SUSPENDED:
            errorString = @"SUSPENDED";
            break;
        case VP8_STATUS_USER_ABORT:
            errorString = @"USER_ABORT";
            break;
        case VP8_STATUS_NOT_ENOUGH_DATA:
            errorString = @"NOT_ENOUGH_DATA";
            break;
        default:
            errorString = @"UNEXPECTED_ERROR";
            break;
    }
    return errorString;
}

@end
