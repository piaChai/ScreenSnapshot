//
//  ImageManager.m
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import "ScreenShotManager.h"

const NSInteger retinaDisplayScreenWidth = 2000;
const NSInteger retinaDisplayScreenHeight = 1000;


@interface ScreenShotManager ()

@property(retain,nonatomic)NSTimer *timer;
- (NSImage *)scaleImage:(NSImage *)image toSize:(NSSize)targetSize;

- (void)compressImage:(CGImageRef)anImage atRate:(float)rate;

- (CGDirectDisplayID *)displayIDs;

- (NSString *)displayDeviceNameFromDisplayID:(CGDirectDisplayID)displayID;

- (NSData *)convertImageDataFormatToYUVFromRGB:(uint8_t* )rgb
                                       byWidth:(size_t)width
                                       height:(size_t)height;
@end


@implementation ScreenShotManager

+ (ScreenShotManager *)sharedManager {
    
    static ScreenShotManager *_sharedManager;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        _sharedManager=[[self alloc] init];
        
    });
    return _sharedManager;
}

- (BOOL)isRetinaDisplay
{
    int width =[[NSScreen mainScreen]frame].size.width;
    int height =[[NSScreen mainScreen]frame].size.height;
    if (width>retinaDisplayScreenWidth && height>retinaDisplayScreenHeight) {
        return true;
    }
    return false;
}

- (void)startCaptureScreen
{
    if (!self.timer) {
        self.timer = [[NSTimer timerWithTimeInterval:1 target:self selector:@selector(captureScreenPerSecond) userInfo:nil repeats:YES]retain];
    }
    [self.timer fire];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopCaptureScreen
{
    if (!self.timer) {
        return;
    }
    [self.timer invalidate];
}

- (void)captureScreenPerSecond
{
    for (int i=0; i<20; i++) {
        [self keepCapturingScreen];
    }
}

- (void)keepCapturingScreen
{
    /* Make a snapshot image of the current display. */
    CGImageRef image = CGDisplayCreateImage(self.displayIDs[self.currentDisplayDeviceIndex]);

    if ([self compressImage:image rate:0.5])
    {
        /* Save the CGImageRef with the document. */
        
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

- (BOOL)compressImage:(CGImageRef)anImage rate:(float)rate
{
    /* if not retina display, no need to compress. */
    if (![self isRetinaDisplay]) {
        return [self saveImage:anImage];
    }
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
    
    return [self saveImage:cgImage];
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


- (NSString *)displayNameFromDisplayID:(CGDirectDisplayID)displayID
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

- (BOOL)saveImage:(CGImageRef)anImage{
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
    
    NSData *yuvData =[self convertImageDataFormatToYUVFromRGB:(uint8_t*)bytes byWidth:width height:height];
    NSDate *currentDate = [NSDate date];
    NSString *dateStr = [NSString stringWithFormat:@"%@",currentDate];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.yuv",dateStr]];
    return [yuvData writeToFile:dataPath atomically:YES];
}

- (NSData *)convertImageDataFormatToYUVFromRGB:(uint8_t *)rgb byWidth:(size_t)width height:(size_t)height{
   	
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

@end
