//
//  ImageManager.h
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import <Foundation/Foundation.h>



@interface ScreenShotManager : NSObject
@property(assign,nonatomic)NSInteger selectedScreenIndex;

@property(assign,nonatomic)CGDirectDisplayID *displayIDs;//开一个线程不停刷新屏幕列表?
@property(assign,nonatomic)CGDisplayCount displayCount;

@property(copy,nonatomic)NSString *filePath;

@property(assign,nonatomic)NSInteger framePerSec;
@property(assign,nonatomic)CGFloat compressRate;

+ (ScreenShotManager *)sharedManager;

- (void)startCaptureScreen;

- (void)stopCaptureScreen;


@end
