//
//  ImageManager.m
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import "ScreenShotManager.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/Graphics/IOGraphicsLib.h>
#import "x264Encoder.h"

#define IS_RETINA ([[NSScreen mainScreen]backingScaleFactor] > 1.0)

const NSInteger kDefaultFramesPerSec = 20;
const CGFloat kDefaultCompressRate = 0.5;



@interface ScreenShotManager ()
{
   NSTimer *timer;
}
@property(nonatomic,retain)x264Encoder *encoder;

- (NSImage *)scaleImage:(NSImage *)image toSize:(NSSize)targetSize;

- (BOOL)compressImage:(CGImageRef)anImage atRate:(float)rate;


- (void)saveImage:(CGImageRef)anImage;

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

- (id)init
{
    if (self = [super init]) {
        self.framePerSec = kDefaultFramesPerSec;
        self.selectedScreenIndex = 0;
        self.compressRate = kDefaultCompressRate;
        [self initDisplayList];
    }
    return self;
}


- (void)initDisplayList
{
    CGError				err = CGDisplayNoErr;
	CGDisplayCount		dspCount = 0;
    
    err = CGGetActiveDisplayList(0, NULL, &dspCount);
    
    self.displayCount = dspCount;
    
    if(err != CGDisplayNoErr)
    {
        NSLog(@"getting dispaly list error = %d",err);
        return;
    }
    
    self.displayIDs = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
    
    err = CGGetActiveDisplayList(dspCount,
                                 self.displayIDs,
                                 &dspCount);
	
    if(err != CGDisplayNoErr)
    {
        NSLog(@"Could not get active display list (%d)\n", err);
        return;
    }
}

- (void)startCaptureScreen
{
        timer =[NSTimer timerWithTimeInterval:(1/self.framePerSec) target:self selector:@selector(captureScreen) userInfo:nil repeats:YES];
        [timer fire];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)stopCaptureScreen
{
    if (!timer) {
        return;
    }
    [self.encoder stopEncoding];
    [timer invalidate];
}


- (void)captureScreen
{
    CGDirectDisplayID *displays = self.displayIDs;
    NSInteger index = self.selectedScreenIndex;
    CGFloat rate = self.compressRate;
    CGImageRef image = CGDisplayCreateImage(displays[index]);
    [self compressImage:image rate:rate];
    CFRelease(image);
}

- (void)compressImage:(CGImageRef)anImage rate:(float)rate
{
    /* if not retina display, no need to compress. */
//    if (!IS_RETINA) {
//        [self saveImage:anImage];
//        return;
//    }
    CGSize imageSize = CGSizeMake (
                                   CGImageGetWidth(anImage),
                                   CGImageGetHeight(anImage)
                                   );
    //CGImage -> NSImage
    NSImage *inputImage = [[NSImage alloc]initWithCGImage:anImage size:NSSizeFromCGSize(imageSize)];
    NSSize outputSize = NSMakeSize(imageSize.width*rate,imageSize.height*rate);
    //modify size of image
    NSImage *outputImage  = [self scaleImage:inputImage toSize:outputSize];
    [inputImage release];
    //
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, outputSize.width, outputSize.height, 8, 0, [[NSColorSpace genericRGBColorSpace] CGColorSpace], kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
    [outputImage drawInRect:NSMakeRect(0, 0, outputSize.width, outputSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [outputImage release];
    [NSGraphicsContext restoreGraphicsState];
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);
    [self saveImage:cgImage];
    CGImageRelease(cgImage);
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


- (void)saveImage:(CGImageRef)anImage{
    size_t width  = CGImageGetWidth(anImage);
    size_t height = CGImageGetHeight(anImage);
    
    CGDataProviderRef provider = CGImageGetDataProvider(anImage);
    NSData* data = (id)CGDataProviderCopyData(provider);
    [data autorelease];
    /**
     *  获取图片data的所有bytes的开始指针位置，size = width*height*4
     */
    const uint8_t* bytes = [data bytes];
    
    NSData *yuvData =[self convertImageDataFormatToYUVFromRGB:(uint8_t*)bytes byWidth:width height:height];
    
    const uint8_t *yuvBytes = [yuvData bytes];
    if (!self.encoder) {
        self.encoder = [[x264Encoder alloc]init];
        [self.encoder initForX264WithWidth:(int)width height:(int)height];
        [self.encoder initForFilePath];
    }
    [self.encoder encodeToH264:yuvBytes];
}


- (NSData *)convertImageDataFormatToYUVFromRGB:(uint8_t *)rgb byWidth:(size_t)width height:(size_t)height{
   	
    
	size_t i;
    size_t j;
    size_t x;
    size_t y;
    
    uint8_t * YUV_Image= malloc(width*height*3/2);
    size_t vPos = width*height;
    size_t uPos = width*height*5/4;
    
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
