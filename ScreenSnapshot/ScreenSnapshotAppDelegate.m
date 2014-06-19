

#import "ScreenSnapshotAppDelegate.h"
#import "ScreenShotManager.h"
#import "x264Encoder.h"

#define NORMALIZE(value) (value > 255 ? 255 : (value < 0 ? 0 : value))

#define IS_RETINA ([[NSScreen mainScreen]backingScaleFactor] > 1.0)

const NSInteger kCaptureMenuItemOptionStartTag = 101;
const NSInteger kCaptureMenuItemOptionStopTag = 102;
const NSInteger kScreenMenuItemScreenItemTag = 103;



@implementation ScreenSnapshotAppDelegate

-(void) dealloc
{
    [captureMenuItem release];
    
    [screenMenuItem release];
    
    if(displays != nil)
    {
		free(displays);
    }
	[super dealloc];
}

#pragma mark NSApplicationDelegate


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender 
{ 
	return NO; 
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    
    [self initCaptureMenuItem];
    
    [self initScreenMenuItem];
    
}

- (void)initScreenMenuItem
{
    NSMenu *screenMenu = [[NSMenu alloc] initWithTitle:@"Screen"];
    
    CGDisplayCount dspCount =[[ScreenShotManager sharedManager] displayCount];
    
    if (displays) {
        free(displays);
    }
    
    displays = [[ScreenShotManager sharedManager] displayIDs];
    
    for(int i= 0; i < dspCount; i++)
    {
        NSString* name = [self displayNameFromDisplayID:displays[i]];
        NSMenuItem *displayMenuItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(selectScreenItem:) keyEquivalent:@""];
        [displayMenuItem setTag:i+kScreenMenuItemScreenItemTag];
        [screenMenu addItem:displayMenuItem];
    }
    [[screenMenu itemAtIndex:0]setState:NSOnState];
    [screenMenuItem setSubmenu:screenMenu];
}

- (void)initCaptureMenuItem
{
    NSMenu *captureMenu = [[NSMenu alloc] initWithTitle:@"Capture"];
    
    NSMenuItem *startMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start" action:@selector(selectCaptureItem:) keyEquivalent:@""];
    [startMenuItem setTag:kCaptureMenuItemOptionStartTag];
    [captureMenu addItem:startMenuItem];
    [startMenuItem release];
    
    NSMenuItem *stopMenuItem = [[NSMenuItem alloc] initWithTitle:@"Stop" action:@selector(selectCaptureItem:) keyEquivalent:@""];
    [stopMenuItem setTag:kCaptureMenuItemOptionStopTag];
    [captureMenu addItem:stopMenuItem];
    [stopMenuItem release];
    
    [captureMenuItem setSubmenu:captureMenu];
    
    [captureMenu release];
}




#pragma mark Display routines


- (void)selectCaptureItem:(id)sender
{
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    
    NSInteger displaysIndex = [menuItem tag];
    
    switch (displaysIndex) {
        case kCaptureMenuItemOptionStartTag:
        {
            [[ScreenShotManager sharedManager] startCaptureScreen];
        }
            break;
        case kCaptureMenuItemOptionStopTag:
        {
            [[ScreenShotManager sharedManager] stopCaptureScreen];
        }
            break;
        default:
            break;
    }
}

- (void)selectScreenItem:(id)sender
{
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    
    NSInteger screenIndex = [menuItem tag]-kScreenMenuItemScreenItemTag;
    
    NSInteger selectedIndex = [[ScreenShotManager sharedManager] selectedScreenIndex];
    
    [[[screenMenuItem submenu]itemAtIndex:selectedIndex]setState:NSOffState];
    
    [[[screenMenuItem submenu]itemAtIndex:screenIndex]setState:NSOnState];
    
    [[ScreenShotManager sharedManager] setSelectedScreenIndex:screenIndex];
}

-(NSString *)displayNameFromDisplayID:(CGDirectDisplayID)displayID
{
    NSString *displayProductName = nil;
    
    NSDictionary *displayInfo = (NSDictionary *)IODisplayCreateInfoDictionary(CGDisplayIOServicePort(displayID), kIODisplayOnlyPreferredName);
    NSDictionary *localizedNames = [displayInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];
    
    if ([localizedNames count] > 0)
    {
        displayProductName = [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] retain];
    }
    
    [displayInfo release];
    return [displayProductName autorelease];
}


@end
