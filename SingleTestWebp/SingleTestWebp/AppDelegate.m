//
//  AppDelegate.m
//  SingleTestWebp
//
//  Created by AnarLong on 30/06/2020.
//  Copyright © 2020 anarl. All rights reserved.
//

#import "AppDelegate.h"
#import <WebPImageToolKit/NSImage+WebpAndCGImage.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *demoView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSString * webpFile = [[NSBundle mainBundle] pathForResource:@"webp-demo" ofType:@"webp"];
    if (webpFile) {
        self.demoView.image = [NSImage imageFromWebpImage:webpFile];
    }
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
