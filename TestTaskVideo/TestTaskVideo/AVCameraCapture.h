//
//  AVCameraCapture.h
//  TestTaskVideo
//
//  Created by Volodymyr Shekhovtsov on 12.03.2025.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ColorProcessingType) {
    Normal = 0,
    Grayscale
};


@interface AVCameraCapture : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

- (instancetype) initWithCameraId:(NSString*)camId filePathForStreamRecord:(nullable NSURL*)recordStreamWithPath previewFrame:(CGRect)previewFrame;
- (BOOL) setupCaptureSession;
- (void) startCapture:(ColorProcessingType)colorProcessingType;
- (void) stopCapture;
- (CALayer*) getPreviewLayer;
- (BOOL)isSessionRunning;


@end

NS_ASSUME_NONNULL_END
