/*
 
     File: ScreenSnapshotAppDelegate.m 
 Abstract:  
 A UIApplication delegate class. Uses Quartz Display Services to obtain a list
 of all connected displays. Installs a callback function that's invoked whenever
 the configuration of a local display is changed. When the user selects a display
 item from the 'Capture' menu, a screen snapshot image is obtained and displayed
 in a new document window.
  
  Version: 1.0 
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2011 Apple Inc. All Rights Reserved. 
  
 
 */

#import "ScreenSnapshotAppDelegate.h"
#import "ScreenShotManager.h"
#import "x264Encoder.h"

#define NORMALIZE(value) (value > 255 ? 255 : (value < 0 ? 0 : value))

// DisplayRegisterReconfigurationCallback is a client-supplied callback function that’s invoked 
// whenever the configuration of a local display is changed.  Applications who want to register 
// for notifications of display changes would use CGDisplayRegisterReconfigurationCallback
static void DisplayRegisterReconfigurationCallback (CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) 
{
    ScreenSnapshotAppDelegate * snapshotDelegateObject = (ScreenSnapshotAppDelegate*)userInfo;
    static BOOL DisplayConfigurationChanged = NO;
    
    // Before display reconfiguration, this callback fires to inform
    // applications of a pending configuration change. The callback runs
    // once for each on-line display.  The flags passed in are set to
    // kCGDisplayBeginConfigurationFlag.  This callback does not
    // carry other per-display information, as details of how a
    // reconfiguration affects a particular device rely on device-specific
    // behaviors which may not be exposed by a device driver.
    //
    // After display reconfiguration, at the time the callback function
    // is invoked, all display state reported by CoreGraphics, QuickDraw,
    // and the Carbon Display Manager API will be up to date.  This callback
    // runs after the Carbon Display Manager notification callbacks.
    // The callback runs once for each added, removed, and currently
    // on-line display.  Note that in the case of removed displays, calls into
    // the CoreGraphics API with the removed display ID will fail.
    
    // Because the callback is called for each display I use DisplayConfigurationChanged to
    // make sure we only disable the menu to change displays once and then refresh it only once.
    if(flags == kCGDisplayBeginConfigurationFlag) 
    {
        if(DisplayConfigurationChanged == NO) 
        {
            [snapshotDelegateObject disableUI];
            DisplayConfigurationChanged = YES;
        }
    }
    else if(DisplayConfigurationChanged == YES) 
    {
        [snapshotDelegateObject enableUI];
        [snapshotDelegateObject interrogateHardware];
        DisplayConfigurationChanged = NO;
    }
}


@implementation ScreenSnapshotAppDelegate


#pragma mark NSApplicationDelegate

// don't want an untitled document opened upon program launch
// so return NO here
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender 
{ 
	return NO; 
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    /* Save the shared NSDocumentController for use later. */
    
    displays = nil;
    
    /* Populate the Capture menu with a list of displays by iterating over all of the displays. */
    [self interrogateHardware];
    
    // Applications who want to register for notifications of display changes would use 
    // CGDisplayRegisterReconfigurationCallback
    //
    // Display changes are reported via a callback mechanism.
    //
    // Callbacks are invoked when the app is listening for events,
    // on the event processing thread, or from within the display
    // reconfiguration function when in the program that is driving the
    // reconfiguration.
    DisplayRegistrationCallBackSuccessful = NO; // Hasn't been tried yet.
	CGError err = CGDisplayRegisterReconfigurationCallback(DisplayRegisterReconfigurationCallback,self);
	if(err == kCGErrorSuccess)
    {
		DisplayRegistrationCallBackSuccessful = YES;
    }
}

-(void) dealloc
{
	// CGDisplayRemoveReconfigurationCallback Removes the registration of a callback function that’s invoked 
	// whenever a local display is reconfigured.  We only remove the registration if it was successful in the first place.
	if(CGDisplayRemoveReconfigurationCallback != NULL && DisplayRegistrationCallBackSuccessful == YES)
    {
		CGDisplayRemoveReconfigurationCallback(DisplayRegisterReconfigurationCallback, self);
    }
    
    [captureMenuItem release];
    
    if(displays != nil)
    {
		free(displays);
    }
    
	[super dealloc];
}


#pragma mark Display routines

/* 
 A display item was selected from the Capture menu. This takes a
 a snapshot image of the screen and creates a new document window
 with the image.
*/
- (void)selectDisplayItem:(id)sender
{
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    
    /* Get the index for the chosen display from the CGDirectDisplayID array. */
    NSInteger displaysIndex = [menuItem tag];
    
//    NSDictionary *dic = @{@"index":[NSNumber numberWithInteger:displaysIndex]};
    
    timer = [[NSTimer timerWithTimeInterval:1 target:self selector:@selector(captureScreenPerSecond) userInfo:nil repeats:YES]retain];
    [timer fire];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)captureScreenPerSecond
{
    for (int i=0; i<20; i++) {
        [self captureScreenForDisplayIndex:0];
    }
}

- (void)captureScreenForDisplayIndex:(NSInteger)displaysIndex
{
    pictureCount++;
    NSLog(@"count = %d",pictureCount);
    while (pictureCount>20) {
        [timer invalidate];
        pictureCount=0;
        return;
    }
    
//    NSInteger displaysIndex = 0;
    
    /* Make a snapshot image of the current display. */
    CGImageRef image = CGDisplayCreateImage(displays[displaysIndex]);
    
//    NSError *error = nil;
//    /* Create a new document. */
//    ImageDocument *newDocument = [documentController openUntitledDocumentAndDisplay:YES error:&error];
    if (1)
    {
        /* Save the CGImageRef with the document. */
        [self compressImage:image rate:0.5];
    }
    else
    {
        /* Display the error. */
//        NSAlert *alert = [NSAlert alertWithError:error];
//        [alert runModal];
        return;
    }
    if (image)
    {
        CFRelease(image);
    }
}

- (BOOL)isHighResolution
{
   int width =[[NSScreen mainScreen]frame].size.width;
   int height =[[NSScreen mainScreen]frame].size.width;
    if (width>2000 && height>1000) {
        return true;
    }
    return false;
}

- (void)compressImage:(CGImageRef)anImage rate:(float)rate
{
    /* Save new image. */
    
//    if (![self isHighResolution]) {
//        [self getRGBArrayFromImage:anImage];
//        return;
//    }
    CGSize imageSize = CGSizeMake (
                                   CGImageGetWidth(anImage),
                                   CGImageGetHeight(anImage)
                                   );
    NSImage *nextImage = [[NSImage alloc]initWithCGImage:anImage size:NSSizeFromCGSize(imageSize)];
    NSSize outputSize = NSMakeSize(imageSize.width*rate,imageSize.height*rate);
    NSImage *outputImage  = [self scaleImage:nextImage toSize:outputSize];
    
    NSSize outputImageSize = [outputImage size];
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, outputImageSize.width, outputImageSize.height, 8, 0, [[NSColorSpace genericRGBColorSpace] CGColorSpace], kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
    [outputImage drawInRect:NSMakeRect(0, 0, outputImageSize.width, outputImageSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    [self getRGBArrayFromImage:cgImage];
    
//    NSData *imgData = [outputImage TIFFRepresentation];
//    NSDate *currentDate = [NSDate date];
//    NSString *dateStr = [NSString stringWithFormat:@"%@",currentDate];
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",dateStr]];
//    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:imgData];
////    NSSize pointsSize = bitmapRep.size;
////    NSSize pixelSize = NSMakeSize(bitmapRep.pixelsWide, bitmapRep.pixelsHigh);
////    CGFloat currentDPI = ceilf((72.0f * pixelSize.width)/pointsSize.width);
////    NSLog(@"current DPI %f", currentDPI);
////    NSSize updatedPointsSize = pointsSize;
//    NSData *saveData = [bitmapRep representationUsingType:NSPNGFileType properties:nil];
//    BOOL success2 = [saveData writeToFile:dataPath atomically:YES];
//    [nextImage release];
    
    
    
}

- (NSImage *)scaleImage:(NSImage *)image toSize:(NSSize)targetSize
{
    if ([image isValid])
    {
        NSSize imageSize = [image size];
        float width  = imageSize.width;
        float height = imageSize.height;
        float targetWidth  = targetSize.width;
        float targetHeight = targetSize.height;
        float scaleFactor  = 0.0;
        float scaledWidth  = targetWidth;
        float scaledHeight = targetHeight;
        
        NSPoint thumbnailPoint = NSZeroPoint;
        
        if (!NSEqualSizes(imageSize, targetSize))
        {
            float widthFactor  = targetWidth / width;
            float heightFactor = targetHeight / height;
            
            if (widthFactor < heightFactor)
            {
                scaleFactor = widthFactor;
            }
            else
            {
                scaleFactor = heightFactor;
            }
            
            scaledWidth  = width  * scaleFactor;
            scaledHeight = height * scaleFactor;
            
            if (widthFactor < heightFactor)
            {
                thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
            }
            
            else if (widthFactor > heightFactor)
            {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
            
            NSImage *newImage = [[NSImage alloc] initWithSize:targetSize];
            
            [newImage lockFocus];
            
            NSRect thumbnailRect;
            thumbnailRect.origin = thumbnailPoint;
            thumbnailRect.size.width = scaledWidth;
            thumbnailRect.size.height = scaledHeight;
            
            [image drawInRect:thumbnailRect
                     fromRect:NSZeroRect
                    operation:NSCompositeSourceOver
                     fraction:1.0];
            
            [newImage unlockFocus];
            return newImage;
        }
    }
    return nil;
}

- (void)getRGBArrayFromImage:(CGImageRef)anImage
{
    size_t width  = CGImageGetWidth(anImage);
    size_t height = CGImageGetHeight(anImage);
    
    //bytes each row
    size_t bytesPerRow = CGImageGetBytesPerRow(anImage);
    //bits for each pixel 32
    size_t bitsPerPixel = CGImageGetBitsPerPixel(anImage);
    //bits for each color 8
    size_t bitsPerComponent = CGImageGetBitsPerComponent(anImage);
    // 4 bytes each pixel, r,g,b,a
    size_t bytesPerPixel = bitsPerPixel / bitsPerComponent;
    
    CGDataProviderRef provider = CGImageGetDataProvider(anImage);
    NSData* data = (id)CGDataProviderCopyData(provider);
    [data autorelease];
    /**
     *  获取图片data的所有bytes的开始指针位置，size = width*height*4
     */
    const uint8_t* bytes = [data bytes];
    
    //int len = [data length];

    NSData *yuvData =[self convertImageDataToYUVFormatFromRGBBitStream:(uint8_t*)bytes byWidth:width height:height];
    
    /*output to .yuv files*/
    NSDate *currentDate = [NSDate date];
    NSString *dateStr = [NSString stringWithFormat:@"%@",currentDate];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.yuv",dateStr]];
    BOOL success2 = [yuvData writeToFile:dataPath atomically:YES];
    
    const uint8_t *yuvBytes = [yuvData bytes];
    
    x264Encoder *encoder = [[x264Encoder alloc]init];
    int aWidth = (int)width;
    int aHeight = (int)height;
    [encoder initForX264WithWidth:aWidth height:aHeight];
    [encoder initForFilePath];
    [encoder encodeToH264:yuvBytes];
    /**
     *  分配rgba空间
     */
//    char* rgb = (char*)malloc(width*height*4);
//    NSLog(@"%lu",width*height);
//    printf("Pixel Data:\n");
    
//    for (int i=0; i<width*height; i++) {
//        const uint8_t* byte = &bytes[i];
//        rgba[i*4] = byte[i*4];
//        rgba[i*4+1] = byte[i*4+1];
//        rgba[i*4+2] = byte[i*4+2];
//        rgba[i*4+3] = byte[i*4+3];
//    }
    
    
    
//    for(size_t row = 0; row < height; row++)
//    {
//        for(size_t col = 0; col < width; col++)
//        {
//            //第n个pixel
//            size_t n = row*width+col;
//            //第n个pixel的起始点是第m个byte
//            size_t m = row * bytesPerRow + col * bytesPerPixel;
//            //得到对应的这个pixel的开始位置的值
//            const uint8_t* pixel = &bytes[m];
//
//            
//            rgb[n*4] = pixel[0];
//            rgb[n*4+1] = pixel[1];
//            rgb[n*4+2] = pixel[2];
//            rgb[n*4+3] = pixel[3];
//        }
//    }
//    printf("%s",rgb);
}

- (NSData *)convertImageDataToYUVFormatFromRGBBitStream:(uint8_t* )rgb byWidth:(size_t)width height:(size_t)height
{
//    //uint8_t length = width*height*3/2;
//    uint8_t * YUV_Image= malloc(width*height*3/2); //YUV420 4个Y对应1个U,1个V,UV都变成原来的1/4
//    int i=0,j=0;
//    size_t vPos = width*height;
//    size_t uPos = width*height*1.25;//start position of u & v
//    
//    for(i=0;i<height;i++){
//        bool isV=false;
//        if(i%2==0) isV=true; // this is a U line
//        for(j=0;j<width;j++){
//            
//            size_t pos = width * i + j; // pixel position
//            uint8_t B =1224 * src[pos*4];
//            uint8_t G =2404 * src[pos*4+1];
//            uint8_t R =467 * src[pos*4+2];
//            uint8_t Y= B+G+R;
//    
//            uint8_t U= (uint8_t)((B-Y) * 493/1000);
//            uint8_t V= (uint8_t)((R-Y) * 877/1000);
//            
//            
//            YUV_Image[pos] = Y;//前面全部放为Y
//            
//            bool isChr=false;  // is this a chroma point
//            if( j%2==0 ){
//               isChr=true;
//            }
//            if( isChr && isV ){
//               YUV_Image[vPos+(j+i*width)/2]=V;
////                NSLog(@"V=%hhu",V);
////                NSLog(@"vPos=%lu",vPos+(j+i*width)/2);
//            }
//            if( isChr && !isV ){
//               YUV_Image[uPos+(j+i*width)/2]=U;
////                NSLog(@"U=%hhu",U);
////                NSLog(@"uPos=%lu",uPos+(j+i*width)/2);
//            }
//        }
//    }
    
	size_t i;
    size_t j;
    size_t x;
    size_t y;
    
    uint8_t * YUV_Image= malloc(width*height*3/2);
    size_t vPos = width*height;
    size_t uPos = width*height*1.25;
    
	for(y=0; y<height; y++)
	{
		for(x=0; x<width; x++)
		{
			j = y*width + x;
			i = j*4;
            
			int a, b, c;
			int yy;
			a = 1224 * rgb[i];
			b = 2404 * rgb[i+1];
			c = 467 * rgb[i+2];
			yy = a + b + c;
			yy = yy >> 12;
			YUV_Image[j] = (uint8_t)yy;
            
            //
			if(x%2 == 1 && y%2 == 1)
			{
				j = (width>>1) * (y>>1) + (x>>1);
                
				int uu;
				int a, b, c;
				a = 2766*rgb[i];
				b = 5426*rgb[i+1];
				c = 8192*rgb[i+2];
				uu = c - a - b;
				uu = uu>>14;
				uu += 128;
//				U[j] = (unsigned char)uu;
                YUV_Image[uPos+j] = (uint8_t)uu;
                
				int vv;
				//int a, b, c;
				a = 8192*rgb[i];
				b = 6855*rgb[i+1];
				c = 1337*rgb[i+2];
				vv = a - b - c;
				vv = vv>>14;
				vv += 128;
				//NORMALIZE(vv);
				//V[j] = (unsigned char)vv;
                YUV_Image[vPos+j] = (uint8_t)vv;
			}
		}
	}

    return [NSData dataWithBytesNoCopy:YUV_Image length:(width*height*3/2)];
}

//- (NSData *)convertImageDataToYUVFormatFromRGBBitStream:(uint8_t* )rgb byWidth:(size_t)width height:(size_t)height
//{
//    //±‰¡ø…˘√˜
//    unsigned int i, j, x, y;
//    //i ‰»Î∆´“∆
//    //j ‰≥ˆ∆´“∆
//    unsigned char *Y = NULL;
//    unsigned char *U = NULL;
//    unsigned char *V = NULL;
//    uint8_t * yuv= malloc(width*height*3/2);
//    Y = yuv[0];
//    U = yuv[2];
//    V = yuv[1];
//    
//    for(y=0; y<height; y++)
//    {
//        for(x=0; x<width; x++)
//        {
//            j = y*((int)width) + x;
//            i = j*4;
//            
//            int a, b, c;
//            int yy;
//            
//            a = 1224 * rgb[i];
//            b = 2404 * rgb[i+1];
//            c = 467 * rgb[i+2];
//            yy = a + b + c;
//            yy = yy >> 12;
//            Y[j] = (unsigned char)yy;
//            
//            if(x%2 == 1 && y%2 == 1)
//            {
//                j = ((int)width>>1) * (y>>1) + (x>>1);
//                int uu;
//                int a, b, c;
//                a = 2766*rgb[i];
//                b = 5426*rgb[i+1];
//                c = 8192*rgb[i+2];
//                uu = c - a - b;
//                uu = uu>>14;
//                uu += 128;
//                U[j] = (unsigned char)uu;
//                
//                int vv;
//                //int a, b, c;
//                a = 8192*rgb[i];
//                b = 6855*rgb[i+1];
//                c = 1337*rgb[i+2];
//                vv = a - b - c;
//                vv = vv>>14;
//                vv += 128;
////                NORMALIZE(vv);
//                V[j] = (unsigned char)vv;
//            }
//        }
//    }
//    return [NSData dataWithBytesNoCopy:yuv length:(width*height*3/2)];
//}









/* Get the localized name of a display, given the display ID. */
-(NSString *)displayNameFromDisplayID:(CGDirectDisplayID)displayID
{
    NSString *displayProductName = nil;
    
    /* Get a CFDictionary with a key for the preferred name of the display. */
    NSDictionary *displayInfo = (NSDictionary *)IODisplayCreateInfoDictionary(CGDisplayIOServicePort(displayID), kIODisplayOnlyPreferredName);
    /* Retrieve the display product name. */
    NSDictionary *localizedNames = [displayInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];
    
    /* Use the first name. */
    if ([localizedNames count] > 0) 
    {
        displayProductName = [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] retain];
    }
    
    [displayInfo release];
    return [displayProductName autorelease];
}

/* Populate the Capture menu with a list of displays by iterating over all of the displays. */
-(void)interrogateHardware
{
	CGError				err = CGDisplayNoErr;
	CGDisplayCount		dspCount = 0;
    
    /* How many active displays do we have? */
    err = CGGetActiveDisplayList(0, NULL, &dspCount);
    
	/* If we are getting an error here then their won't be much to display. */
    if(err != CGDisplayNoErr)
    {
        return;
    }
	
	/* Maybe this isn't the first time though this function. */
	if(displays != nil)
    {
		free(displays);
    }
    
	/* Allocate enough memory to hold all the display IDs we have. */
    
    displays = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
    
	// Get the list of active displays
    err = CGGetActiveDisplayList(dspCount,
                                 displays,
                                 &dspCount);
	
	/* More error-checking here. */
    if(err != CGDisplayNoErr)
    {
        NSLog(@"Could not get active display list (%d)\n", err);
        return;
    }

    /* Create the 'Capture Screen' menu. */
    NSMenu *captureMenu = [[NSMenu alloc] initWithTitle:@"Capture Screen"];

    int i;
    /* Now we iterate through them. */
    for(i = 0; i < dspCount; i++)
    {
        /* Get display name for the selected display. */
        NSString* name = [self displayNameFromDisplayID:displays[i]];

        /* Create new menu item for the display. */
        NSMenuItem *displayMenuItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(selectDisplayItem:) keyEquivalent:@""];
        /* Save display index with the menu item. That way, when it is selected we can easily retrieve
           the display ID from the displays array. */
        [displayMenuItem setTag:i];
        /* Add the display menu item to the menu. */
        [captureMenu addItem:displayMenuItem];
        
        [displayMenuItem release];
    }
    
    /* Set the display menu items as a submenu of the Capture menu. */
    [captureMenuItem setSubmenu:captureMenu];
    [captureMenu release];
}

#pragma mark Menus

/* Disable the Capture Screen menu. */
-(void) disableUI
{
    [captureMenuItem setEnabled:NO];
}

/* Enable the Capture Screen menu. */
-(void) enableUI
{
    [captureMenuItem setEnabled:YES];
}

@end
