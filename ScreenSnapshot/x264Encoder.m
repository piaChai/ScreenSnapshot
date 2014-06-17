//
//  x264Manager.m
//  ScreenSnapshot
//
//  Created by hulingzhi on 14-6-16.
//
//

#import "x264Encoder.h"

@interface x264Encoder ()

@property(assign,nonatomic)int frameWidth;
@property(assign,nonatomic)int frameHeight;

@end


@implementation x264Encoder


- (void)initForX264WithWidth:(int)width height:(int)height{
    
    
    self.frameHeight = height;
    self.frameWidth = width;
    p264Param =malloc(sizeof(x264_param_t));//video params use for encoding
    p264Pic  =malloc(sizeof(x264_picture_t));//raw image data for storing image data
    memset(p264Pic,0,sizeof(x264_picture_t));//clear memory
    x264_param_default_preset(p264Param,"veryfast","zerolatency");//set encoder params
    p264Param->i_threads =1;/* encode multiple frames in parallel */
    p264Param->i_width   =width;  //set frame width
    p264Param->i_height  =height;  //set frame height
    p264Param->b_cabac =0;
    p264Param->i_bframe =0;
    p264Param->b_interlaced=0;
    p264Param->rc.i_rc_method=X264_RC_ABR;//X264_RC_CQP
    p264Param->i_level_idc=21;
    p264Param->rc.i_bitrate=128;
    p264Param->b_intra_refresh =1;
    p264Param->b_annexb =1;
    p264Param->i_keyint_max=25;
    p264Param->i_fps_num=15;
    p264Param->i_fps_den=1;
    p264Param->b_annexb =1;
    //    p264Param->i_csp = X264_CSP_I420;
    /*      (can be NULL, in which case the function will do nothing)
     *
     *      Does NOT guarantee that the given profile will be used: if the restrictions
     *      of "High" are applied to settings that are already Baseline-compatible, the
     *      stream will remain baseline.  In short, it does not increase settings, only
     *      decrease them.
     *
     *      returns 0 on success, negative on failure (e.g. invalid profile name). */
    x264_param_apply_profile(p264Param,"baseline");
    //get handle to p264Params
    if((p264Handle =x264_encoder_open(p264Param)) ==NULL)
    {
        fprintf(stderr, "x264_encoder_open failed/n" );
        return ;
    }
    /* x264_picture_alloc:
     *  alloc data for a picture. You must call x264_picture_clean on it.
     *  returns 0 on success, or -1 on malloc failure or invalid colorspace. */
    
                           /*format is yuv 4:2:0 planar,get the width and height for every picture */
    x264_picture_alloc(p264Pic,X264_CSP_I420,p264Param->i_width,p264Param->i_height);
    p264Pic->i_type =X264_TYPE_AUTO;
    
}


- (void)initForFilePath{
    NSDate *date = [NSDate date];
    NSString *dateStr = [NSString stringWithFormat:@"%@.h264",date];
    const char *filename = [dateStr UTF8String];
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

//- (void)encode2H264:(uint8_t *)input{
//    
//    x264_param_t param;
//    /* x264_t:
//     *      opaque handler for encoder */
//    x264_t *h = NULL;
//    x264_picture_t pic_in;
//    x264_picture_t pic_out;
//    x264_nal_t *nal;
//    uint8_t *data = NULL;
//    int widthXheight = self.frameHeight * self.frameWidth;
//    int frame_size = widthXheight * 1.5;
//    int read_sum = 0, write_sum = 0;
//    int frames = 0;
//    int i, rnum, i_size;
//    x264_nal_t* pNals = NULL;
//    
//    x264_param_default(&param);
//    param.i_width = self.frameWidth;
//    param.i_height = self.frameHeight;
//    param.i_bframe = 3;
//    param.i_fps_num = 25;
//    param.i_fps_den = 1;
//    param.b_vfr_input = 0;
//    param.i_keyint_max = 250;
//    param.rc.i_bitrate = 1500;
//    param.i_scenecut_threshold = 40;
//    param.i_level_idc = 51;
//    
//    x264_param_apply_profile(&param, "high");
//    
//    h = x264_encoder_open( &param );
//    
//    //    printf("param.rc.i_qp_min=%d, param.rc.i_qp_max=%d, param.rc.i_qp_step=%d param.rc.i_qp_constant=%d param.rc.i_rc_method=%d\n",
//    //            param.rc.i_qp_min, param.rc.i_qp_max, param.rc.i_qp_step, param.rc.i_qp_constant, param.rc.i_rc_method);
//    printf("param:%s\n", x264_param2string(&param, 1));
//    
//    
//    x264_picture_init( &pic_in );
//    x264_picture_alloc(&pic_in, X264_CSP_YV12, param.i_width, param.i_height);
//    pic_in.img.i_csp = X264_CSP_YV12;
//    pic_in.img.i_plane = 3;
//    
//    data = (uint8_t*)malloc(0x400000);
//    
//    FILE* fpr = fopen(FILE ".yuv", "rb");
//    FILE* fpw1 = fopen(FILE".szhu.h264", "wb");
//    //    FILE* fpw2 = fopen(MFILE".h264", "wb");
//    
//    if(!fpr || !fpw1 ) {
//        printf("file open failed\n");
//        return -1;
//    }
//    //没有结束就直接循环
//    while(!feof(fpr)){
//        //吧数据读到data里面
//        rnum = fread(data, 1, frame_size, fpr);
//        if(rnum != frame_size){
//            printf("read file failed\n");
//            break;
//        }
//        //把data的数据移动到pic_in.img的三个plane里面
//        memcpy(pic_in.img.plane[0], data, widthXheight);
//        memcpy(pic_in.img.plane[1], data + widthXheight, widthXheight >> 2);
//        memcpy(pic_in.img.plane[2], data + widthXheight + (widthXheight >> 2), widthXheight >> 2);
//        read_sum += rnum;
//        frames ++;
//        //        printf("read frames=%d %.2fMB write:%.2fMB\n", frames, read_sum * 1.0 / 0x100000, write_sum * 1.0 / 0x100000);
//        int i_nal;
//        int i_frame_size = 0;
//        
//        if(0 && frames % 12 == 0){
//            pic_in.i_type = X264_TYPE_I;
//        }else{
//            pic_in.i_type = X264_TYPE_AUTO;
//        }
//        i_frame_size = x264_encoder_encode( h, &nal, &i_nal, &pic_in, &pic_out );
//        
//        if(i_frame_size <= 0){
//            //printf("\t!!!FAILED encode frame \n");
//        }else{
//            fwrite(nal[0].p_payload, 1, i_frame_size, fpw1);
//            //            printf("\t+++i_frame_size=%d\n", i_frame_size);
//            write_sum += i_frame_size;
//        }
//#if 0
//        for(i = 0; i < i_nal; i ++){
//            i_size = nal[i].i_payload;
//            //            fwrite(nal[i].p_payload, 1, nal[i].i_payload, fpw1);
//            fwrite(nal[i].p_payload, 1, i_frame_size, fpw1);
//            x264_nal_encode(h, data, &nal[i]);
//            if(i_size != nal[i].i_payload){
//                printf("\t\ti_size=%d nal[i].i_payload=%d\n", i_size, nal[i].i_payload);
//            }
//            //
//            fwrite(data, 1, nal[i].i_payload, fpw2);
//        }
//#endif
//    }
//    
//    free(data);
//    x264_picture_clean(&pic_in);
//    x264_picture_clean(&pic_out);
//    if(h){
//        x264_encoder_close(h);
//        h = NULL;
//    }
//    fclose(fpw1);
//    //    fclose(fpw2);
//    fclose(fpr);
//    printf("h=0x%X", h);
//    return 0;
//}


- (void)encodeToH264:(uint8_t *)input{
    
    int i264Nal;
    int widthXheight = self.frameWidth*self.frameHeight;
    //输出的图片
    x264_picture_t pic_out;
    
    memcpy(p264Pic->img.plane[0], input,self.frameWidth*self.frameHeight);
    memcpy(p264Pic->img.plane[1], input + widthXheight, widthXheight >> 2);
    memcpy(p264Pic->img.plane[2], input + widthXheight + (widthXheight >> 2), widthXheight >> 2);
    
//    uint8_t * pDst1 = p264Pic->img.plane[1];
//    uint8_t * pDst2 = p264Pic->img.plane[2];
//    
//    for( int i =0; i < self.frameWidth*self.frameHeight/4; i ++ )
//    {
//        *pDst1++ = *input++;
//        *pDst2++ = *input++;
//    }
    /* x264_encoder_encode:
     *      encode one picture.
     *      *pi_nal is the number of NAL units outputted in pp_nal.
     *      returns the number of bytes in the returned NALs.
     *      returns negative on error and zero if no NAL units returned.
     *      the payloads of all output NALs are guaranteed to be sequential in memory. */
    
    // <0 means error occurred.
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

@end
