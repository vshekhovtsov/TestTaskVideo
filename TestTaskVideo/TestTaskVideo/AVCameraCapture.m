//
//  AVCameraCapture.m
//  TestTaskVideo
//
//  Created by Volodymyr Shekhovtsov on 12.03.2025.
//

#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CIImage.h>
#import <CoreImage/CIFilter.h>
#import <CoreImage/CIContext.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreMedia/CMTime.h>

#import "AVCameraCapture.h"

#define FRAME_CAPTURE_QUEUE             "com.airlab.queue.frame.capture.test"

@interface AVCameraCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) NSString                  *videoDeviceId;
@property (nonatomic, strong) AVCaptureDeviceInput      *videoInput;
@property (nonatomic, strong) AVCaptureSession          *session;
@property (nonatomic, strong) AVCaptureMovieFileOutput  *recordedFile;
@property (nonatomic, strong) NSURL                     *pathRecordStream;
@property (nonatomic) ColorProcessingType               colorProcessingType;

@property (nonatomic, strong) CALayer                   *videoPreview;
@property (nonatomic, strong) CIContext                 *ciContext;

@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *videoWriterInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property (assign, nonatomic) BOOL isRecording;
@property (assign, nonatomic) CMTime startTime;

@end

@implementation AVCameraCapture

- (instancetype) initWithCameraId:(NSString*)camId  filePathForStreamRecord:(nullable NSURL*)recordStreamWithPath previewFrame:(CGRect)previewFrame {
    self = [super init];
    
    if (self) {
        self.videoDeviceId = camId;
        self.colorProcessingType = Normal;
        
        self.ciContext = [CIContext contextWithOptions:nil];
        
        self.videoPreview = [CALayer layer];
        [self.videoPreview setFrame:previewFrame];
        
        self.recordedFile = [AVCaptureMovieFileOutput new];
        self.pathRecordStream = recordStreamWithPath;
    }
    
    return self;
}

- (BOOL) setupCaptureSession {
    
    self.session = [AVCaptureSession new];
    
    AVCaptureDevice* videoDevice = [AVCaptureDevice deviceWithUniqueID:self.videoDeviceId];
    if (!videoDevice)
        assert(0);
    
    self.videoInput = nil;
    
    // add the device to the session.
    NSError* error;
    self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (error) {
        NSLog(@"Add device to the capture session failed. NSError: %@", error.localizedDescription);
        return NO;
    }
    
    [self.session beginConfiguration];
    if ([self.videoInput.device lockForConfiguration:&error]) {
        [self.session addInput:self.videoInput];
        
        [self prepareDataOutput];
        
        [self.videoInput.device unlockForConfiguration];
    } else {
        NSLog(@"Can't lock video device. NSError: %@", error.localizedDescription);
    }
    [self.session commitConfiguration];
    
    if (error != nil) {
        return NO;
    }
    
    return YES;
}

- (void)startCapture:(ColorProcessingType)colorProcessingType {
    if (self.session == nil)
        return;
    
    self.colorProcessingType = colorProcessingType;
    
    if (!self.session.running) {
        NSError* error = nil;
        if ([self.videoInput.device lockForConfiguration:&error]) {
            [self.session startRunning];
            [self.videoInput.device unlockForConfiguration];
        }
    } else {
        NSLog(@"Session is already running");
    }
    
    if (self.pathRecordStream != nil) {
        AVCaptureInput* input = [self.session.inputs objectAtIndex:0]; // maybe search the input in array
        AVCaptureInputPort * port = [input.ports objectAtIndex:0];
        CMFormatDescriptionRef formatDescription = port.formatDescription;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
        
        [self setupAssetWriter:dimensions.width height:dimensions.height];
        self.isRecording = YES;
    }
}

- (void) stopCapture {
    if (self.session.running)
        [self.session stopRunning];
    
    self.session = nil;
    
    [self stopRecording];
}

-(void)prepareDataOutput {
    // create the output for the capture session.
    AVCaptureVideoDataOutput * dataOutput = [AVCaptureVideoDataOutput new];
    dataOutput.alwaysDiscardsLateVideoFrames = YES;
    
    
    // YUV420.
    NSNumber* format = [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSArray<NSNumber*>* supportedFormats = [dataOutput availableVideoCVPixelFormatTypes];
    
    if (![supportedFormats containsObject:format]) {
        NSLog(@"output doesn't support required video format");
        return;
    }
    
    NSDictionary* settings = @{(id)kCVPixelBufferPixelFormatTypeKey:format};
    [dataOutput setVideoSettings:settings];
    
    dispatch_queue_t videoCaptureQueue = dispatch_queue_create(FRAME_CAPTURE_QUEUE, DISPATCH_QUEUE_SERIAL);
    [dataOutput setSampleBufferDelegate:self queue:videoCaptureQueue];
    
    if ([self.session canAddOutput:dataOutput]) {
        [self.session addOutput:dataOutput];
    } else {
        NSLog(@"Can't add video data output");
    }
    
    if ([self.session canAddOutput:self.recordedFile]){
        [self.session addOutput:self.recordedFile];
        NSLog(@"Added file video output");
    } else {
        NSLog(@"Couldn't file video output");
    }
}

- (CALayer*) getPreviewLayer {
    return self.videoPreview;
}

- (BOOL)isSessionRunning {
    return self.session != nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (!self.session.running)
        return;
    
    // Convert sample buffer to pixel buffer
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // Create a CIImage from the CVPixelBuffer
    CIImage* ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    if (self.colorProcessingType == Grayscale) {
        // Convert the pixel buffer to grayscale
        ciImage = [self convertToGrayscale:ciImage];
    }
    
    __block CGImageRef cgImage = [self.ciContext createCGImage:ciImage fromRect:ciImage.extent];
    
    // Draw on CALayer
    dispatch_async(dispatch_get_main_queue(), ^{
        self.videoPreview.contents = (__bridge id)cgImage;
        CGImageRelease(cgImage);
    });
    
    // recording
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        [self.assetWriter startWriting];
        [self.assetWriter startSessionAtSourceTime:timestamp];
        self.startTime = timestamp;
    }

    if (self.videoWriterInput.isReadyForMoreMediaData) {
        CMTime frameTime = CMTimeSubtract(timestamp, self.startTime);
        
        size_t width = CGImageGetWidth(cgImage);
        size_t height = CGImageGetHeight(cgImage);

        // Needs to create specific pixel buffer after conversion.
        CVPixelBufferRef pixelBufferToFile = NULL;
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer);
        if (status != kCVReturnSuccess) {
            NSLog(@"Couldn't create pixel buffer.");
            return;
        }
        
        // needs to be done for recording after conversion to grayscale
        pixelBufferToFile = [self convertCGImageToPixelBuffer:cgImage pixelBuffer:(CVPixelBufferRef)pixelBuffer];
        
        [self.pixelBufferAdaptor appendPixelBuffer:pixelBufferToFile withPresentationTime:frameTime];
        
        CFRelease(pixelBufferToFile);
    }
    //end of recording

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (CIImage*)convertToGrayscale:(CIImage*)ciImage {
    // Create a grayscale filter
    CIFilter* grayscaleFilter = [CIFilter filterWithName:@"CIPhotoEffectMono"];

    [grayscaleFilter setValue:ciImage forKey:kCIInputImageKey];
    
    // Get the output image
    return [grayscaleFilter outputImage];
}

- (void)setupAssetWriter:(int32_t)width height:(int32_t)height {
    NSError *error = nil;
    
    // trying to find and remove file from previous session
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.pathRecordStream.path]) {
        [fileManager removeItemAtURL:self.pathRecordStream error:&error];
    }
    if (error) {
        NSLog(@"Error while removing existing file: %@", error.description);
    }
    
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.pathRecordStream fileType:AVFileTypeMPEG4 error:&error];

    if (error) {
        NSLog(@"Error creating AVAssetWriter: %@", error.localizedDescription);
        return;
    }

    NSDictionary* videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height)
    };

    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.videoWriterInput.expectsMediaDataInRealTime = YES;

    NSDictionary* attributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height)
    };

    self.pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.videoWriterInput sourcePixelBufferAttributes:attributes];

    if ([self.assetWriter canAddInput:self.videoWriterInput]) {
        [self.assetWriter addInput:self.videoWriterInput];
    }
}

- (void)stopRecording {
    self.isRecording = NO;
    [self.videoWriterInput markAsFinished];

    [self.assetWriter finishWritingWithCompletionHandler:^{
        NSLog(@"Recording finished, file saved at: %@", self.assetWriter.outputURL);
    }];
}

- (CVPixelBufferRef)convertCGImageToPixelBuffer:(CGImageRef)cgiImage  pixelBuffer:(CVPixelBufferRef)pixelBuffer {

    const size_t width = CVPixelBufferGetWidth(pixelBuffer);
    const size_t height = CVPixelBufferGetHeight(pixelBuffer);

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    void* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace, (CGBitmapInfo) kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgiImage);

    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

@end

