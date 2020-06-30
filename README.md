# WebPImageToolKit
Extension for NSImage to support webp format image.

-----------------

It's easy now to make NSImage support Webp format image. Only one line code

```objective-c
#import <WebPImageToolKit/NSImage+WebpAndCGImage.h>

[NSImage imageFromWebpImage:#{webpfile_path}]
```

or you can asynchronously load webp file like this

```objective-c
[NSImage imageWithWebp:#{webpfile_path}
			 completionBlock:#{completion_block}
					failureBlock:#{failure_block}];
```

