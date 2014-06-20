//
//  x264Manager.m
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import "x264Encoder.h"


#define kDefaultBandwidth			500
#define kAvgBitrateCoef				0.6
#define kMaxBitrateCoef				0.8
#define kBitPerByte					8
#define kShortTermDelayStatScope	5
#define kLongTermDelayStatScope		30

@interface x264Encoder ()

@property(assign,nonatomic)int frameWidth;
@property(assign,nonatomic)int frameHeight;

@end


@implementation x264Encoder


- (void)initForX264WithWidth:(int)width height:(int)height{
    
    int bitrate, maxbitrate;
    int m_maxBandwidth =0;
	if (m_maxBandwidth == 0){
		m_maxBandwidth = kDefaultBandwidth;
	}
    
	bitrate = m_maxBandwidth * kAvgBitrateCoef * kBitPerByte;
	maxbitrate = m_maxBandwidth * kMaxBitrateCoef * kBitPerByte;
    
    self.frameHeight = height;
    self.frameWidth = width;
    p264Param =malloc(sizeof(x264_param_t));//video params use for encoding
    p264Pic  =malloc(sizeof(x264_picture_t));//raw image data for storing image data
    memset(p264Pic,0,sizeof(x264_picture_t));//clear memory
    x264_param_default_preset(p264Param,"veryfast","zerolatency");//set encoder params
    p264Param->i_lookahead_threads =0;
    p264Param->i_bframe =0;
    p264Param->i_threads =1;/* encode multiple frames in parallel */
    p264Param->i_keyint_max=200;
    p264Param->i_frame_reference =1;
    p264Param->i_scenecut_threshold =0;
    p264Param->i_bframe_adaptive = X264_B_ADAPT_NONE;
    p264Param->i_width   =width;  //set frame width
    p264Param->i_height  =height;  //set frame height
    p264Param->i_level_idc=21;
    p264Param->i_fps_num=15;
    p264Param->i_fps_den=1;
    
    p264Param->b_vfr_input =0;
    p264Param->b_deblocking_filter=0;
    p264Param->b_cabac =0;
    p264Param->b_repeat_headers = 1;
    p264Param->b_interlaced=0;
    p264Param->b_intra_refresh =1;
    p264Param->b_annexb =1;
  
    p264Param->analyse.intra = 0;
	p264Param->analyse.inter = 0;
	p264Param->analyse.i_me_method = X264_ME_DIA;
	p264Param->analyse.b_transform_8x8 = 0;
	p264Param->analyse.i_weighted_pred = X264_WEIGHTP_NONE;
	p264Param->analyse.b_weighted_bipred = 0;
	p264Param->analyse.i_subpel_refine = 0;
	p264Param->analyse.b_mixed_references = 0;
	p264Param->analyse.i_trellis = 0;
	
	p264Param->rc.i_rc_method = X264_RC_ABR;
    p264Param->rc.i_aq_mode = X264_AQ_NONE;
	p264Param->rc.i_bitrate = bitrate;
	p264Param->rc.i_vbv_max_bitrate = maxbitrate;
	p264Param->rc.i_vbv_buffer_size = bitrate;
	p264Param->rc.b_mb_tree = 0;
	p264Param->rc.i_lookahead = 0;
    
    x264_param_apply_profile(p264Param,"baseline");
    if((p264Handle =x264_encoder_open(p264Param)) ==NULL){
        fprintf(stderr, "x264_encoder_open failed/n" );
        return ;
    }
    x264_picture_alloc(p264Pic,X264_CSP_I420,p264Param->i_width,p264Param->i_height);
    p264Pic->i_type =X264_TYPE_AUTO;
    
}


- (void)initForFilePath{
    NSString *nameStr = @"snapshot.h264";
    const char *filename = [nameStr UTF8String];
    char *path = [self GetFilePathByfileName:filename];
    NSLog(@"%s",path);
    fp = fopen(path,"wb");
}


- (char*)GetFilePathByfileName:(const char*)filename{
    
    NSArray *paths =NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *strName = [NSString stringWithFormat:@"%s",filename];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:strName];
    NSInteger len = [writablePath length];
    char *filepath = (char*)malloc(sizeof(char) * (len +1));
    [writablePath getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}


- (void)encodeToH264:(uint8_t *)input{
    
    int i264Nal;
    int widthXheight = self.frameWidth*self.frameHeight;
    //输出的图片
    x264_picture_t pic_out;
    //把数据分给三个通道
    size_t vPos = widthXheight;
    size_t uPos = widthXheight*5/4;
    
    memcpy(p264Pic->img.plane[0], input,widthXheight);
    memcpy(p264Pic->img.plane[1], input+vPos, widthXheight>>2);
    memcpy(p264Pic->img.plane[2], input+uPos, widthXheight>>2);

    if( x264_encoder_encode(p264Handle, &p264Nal, &i264Nal,p264Pic ,&pic_out) < 0 )
    {
        fprintf(stderr, "x264_encoder_encode failed/n" );
    }
    NSLog(@"i264Nal======%d",i264Nal);
    
    if (i264Nal > 0) {
        
        int i_size;
        char * data=(char *)szBodyBuffer+100;
        for (int i=0 ; i<i264Nal; i++) {
            if (p264Handle->nal_buffer_size <p264Nal[i].i_payload*3/2+4) {
                p264Handle->nal_buffer_size =p264Nal[i].i_payload*2+4;
                x264_free( p264Handle->nal_buffer );
                p264Handle->nal_buffer =x264_malloc(p264Handle->nal_buffer_size );
            }
            i_size =p264Nal[i].i_payload;
            
            memcpy(data,p264Nal[i].p_payload,p264Nal[i].i_payload);
            fwrite(data, 1, i_size,fp);
        }
        
    }
}

- (void)stopEncoding
{
    fclose(fp);
}

@end
