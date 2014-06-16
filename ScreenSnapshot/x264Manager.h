//
//  x264Manager.h
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import <Foundation/Foundation.h>
#import "x264.h"
#import "common.h"


@interface x264Manager : NSObject
{
    x264_param_t * p264Param;
    x264_picture_t * p264Pic;
    x264_t *p264Handle;
    x264_nal_t  *p264Nal;
    int previous_nal_size;
    unsigned  char * pNal;
    FILE *fp;
    unsigned char szBodyBuffer[1024*32];
}
- (void)initForX264;//初始化x264
- (void)initForFilePath;//初始化编码后文件的保存路径
- (void)encoderToH264:(CMSampleBufferRef )pixelBuffer;//将CMSampleBufferRef格式的数据编码成h264并写入文件
@end
