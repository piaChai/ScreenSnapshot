//
//  ImageManager.h
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/Graphics/IOGraphicsLib.h>

@interface ScreenShotManager : NSObject
@property(assign,nonatomic)NSInteger screenShotCount;
@property(assign,nonatomic)NSInteger currentDisplayDeviceIndex;
@property(assign,nonatomic)CGDirectDisplayID *displayIDs;
@property(copy,nonatomic)NSString *filePath;

+ (ScreenShotManager *)sharedManager;

- (BOOL)isRetinaDisplay;

- (void)startCaptureScreen;

- (void)stopCaptureScreen;

@end
