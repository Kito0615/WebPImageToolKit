//
//  NSImage+WebpAndCGImage.h
//  WebPImageToolKit
//
//  Created by AnarLong on 30/06/2020.
//  Copyright © 2020 anarl. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "encode.h"
#include "decode.h"

@interface NSImage (WebpAndCGImage)

#pragma mark - CGImage Extensions
- (CGImageRef)CGImage;

#pragma mark - Webp Extensions

+ (NSImage *)imageWithWebpData:(NSData *)webpData;

+ (NSImage *)imageFromWebpImage:(NSString *)webpFile;

+ (NSData *)imageToWebp:(NSImage *)img quality:(CGFloat)quality;

+ (void)imageToWebP:(NSImage *)image
            quality:(CGFloat)quality
              alpha:(CGFloat)alpha
             preset:(WebPPreset)preset
   completioniBlock:(void (^)(NSData* result))completionBlock
       failureBlock:(void (^)(NSError* error))failureBlock;

+ (void)imageToWebP:(NSImage *)image
            quality:(CGFloat)quality
              alpha:(CGFloat)alpha
             preset:(WebPPreset)preset
        configBlock:(void (^)(WebPConfig* config))configBlock
    completionBlock:(void (^)(NSData* result))completionBlock
       failureBlock:(void (^)(NSError* error))failureBlock;

+ (void)imageWithWebp:(NSString *)filePath
      completionBlock:(void (^)(NSImage* result))completionBlock
         failureBlock:(void (^)(NSError* error))failureBlock;

- (NSImage *)imageByApplyingAlpha:(CGFloat)alpha;


@end
