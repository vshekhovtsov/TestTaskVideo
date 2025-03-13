//
//  AVDeviceEnumerator.h
//  TestTaskVideo
//
//  Created by Volodymyr Shekhovtsov on 12.03.2025.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVDeviceEnumerator : NSObject

- (nullable NSArray<AVCaptureDevice*>*)getVideoDeviceList;
- (nullable NSArray<AVCaptureDevice*>*)getAudioDeviceList;


@end

NS_ASSUME_NONNULL_END
