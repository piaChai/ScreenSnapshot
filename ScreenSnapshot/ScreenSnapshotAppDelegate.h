

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/Graphics/IOGraphicsLib.h>


@interface ScreenSnapshotAppDelegate : NSObject <NSApplicationDelegate>
{
@private
    IBOutlet NSMenuItem *captureMenuItem;
    IBOutlet NSMenuItem *screenMenuItem;
	CGDirectDisplayID *displays;
}


@end
