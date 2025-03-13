//
//  AVDeviceEnumerator.m
//  TestTaskVideo
//
//  Created by Volodymyr Shekhovtsov on 12.03.2025.
//


#import "AVDeviceEnumerator.h"

@implementation AVDeviceEnumerator: NSObject

- (nullable NSArray<AVCaptureDevice*>*)getVideoDeviceList {
    NSArray<AVCaptureDevice*>* videoDevices = [self getDeviceList:AVMediaTypeVideo deviceType:@[AVCaptureDeviceTypeExternalUnknown]];
    for (AVCaptureDevice* device in videoDevices) {
        NSLog(@"Audio device name: %@", device.localizedName );
    }
    return videoDevices;
}

- (nullable NSArray<AVCaptureDevice*>*)getAudioDeviceList {
    NSArray<AVCaptureDevice*>* audioDevices = [self getDeviceList:AVMediaTypeAudio deviceType:@[AVCaptureDeviceTypeBuiltInMicrophone]];
    for (AVCaptureDevice* device in audioDevices) {
        NSLog(@"Audio device name: %@", device.localizedName );
    }
    return audioDevices;
}

- (nullable NSArray<AVCaptureDevice*>*)getDeviceList:(nullable AVMediaType)mediaType deviceType:(NSArray<AVCaptureDeviceType> *)deviceType  {

    NSArray<AVCaptureDevice*>* devices = nil;
    if (@available(macOS 13.0, *)) {
            AVCaptureDeviceDiscoverySession* session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:mediaType position:AVCaptureDevicePositionUnspecified];
            devices = session.devices;
    }
    
    return devices;
}

@end
