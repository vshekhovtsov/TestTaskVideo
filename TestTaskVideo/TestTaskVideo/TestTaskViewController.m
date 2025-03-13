//
//  TestTaskViewController.m
//  TestTaskVideo
//
//  Created by Volodymyr Shekhovtsov on 12.03.2025.
//

#import <AVFoundation/AVFoundation.h>
#import "AppKit/NSComboBox.h"

#import "TestTaskViewController.h"
#import "AVDeviceEnumerator.h"
#import "AVCameraCapture.h"

@interface TestTaskViewController ()

@property (weak) IBOutlet NSComboBox *comboBoxVideoDeviceList;
@property (weak) IBOutlet NSView *viewPreview;
@property (weak) IBOutlet NSButton *buttonStart;
@property (weak) IBOutlet NSButton *buttonStop;
@property (weak) IBOutlet NSButton *checkGrayscale;
@property (weak) IBOutlet NSButton *checkRecordStream;
@property (weak) IBOutlet NSButton *buttonIconStatus;

@property (nonatomic, strong) NSArray<AVCaptureDevice*>* videoDevices;
@property (nonatomic, strong) AVCameraCapture* cameraCapture;
@property (nonatomic, strong) NSURL* pathRecordStream;

@end

// Default device value if there is no one in the system
NSString const *NoDeviceFound = @"None";
// File name for saving video stream.
NSString const *TestRecordStream = @"TestRecordStream.mov";

@implementation TestTaskViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self getDeviceList];
    
    [self fillComboBoxVideoDeviceList];
    if (self.comboBoxVideoDeviceList.numberOfItems > 0) {
        // choose the first one camera
        [self.comboBoxVideoDeviceList selectItemWithObjectValue:[self.comboBoxVideoDeviceList itemObjectValueAtIndex:0]];
        self.buttonIconStatus.image = [NSImage imageNamed:@"iconYellow"];
    }
    
    [self addObservers];
}

- (void)dealloc {
    [self removeObservers];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)getDeviceList {
    AVDeviceEnumerator* deviceEnumerator = [AVDeviceEnumerator new];
    
    // Get all available video devices
    self.videoDevices = [deviceEnumerator getVideoDeviceList];
}

- (void)fillComboBoxVideoDeviceList {
    if (self.videoDevices == NULL) {
        // any video devices was found
        self.comboBoxVideoDeviceList.enabled = NO;
        [self.comboBoxVideoDeviceList addItemWithObjectValue:NoDeviceFound];
        [self.comboBoxVideoDeviceList selectItemWithObjectValue:NoDeviceFound];
        
        NSLog(@"Camera devices were not found");
        
        return;
    }
    
    // Clean previous values
    [self.comboBoxVideoDeviceList removeAllItems];
    
    // Fill in with discovered video devices if any found
    for (AVCaptureDevice* device in self.videoDevices) {
        [self.comboBoxVideoDeviceList addItemWithObjectValue:device.localizedName];
    }
}

- (IBAction)startCamera:(id)sender {
    NSLog(@"start");
    
    if (self.comboBoxVideoDeviceList.numberOfItems <= 0) {
        // combobox is empty. Something wrong happened.
        
        NSLog(@"Camera list failed. Can't start a stream");
        return;
    }
    
    NSString* cameraName = [self.comboBoxVideoDeviceList objectValueOfSelectedItem];
    if ([NoDeviceFound isEqualToString:cameraName]) {
        // absense of cameras
        NSLog(@"Camera devices were not found. Can't start a stream");
        return;
    }
    
    NSString* deviceId = nil;
    for (AVCaptureDevice* device in self.videoDevices) {
        if ([device.localizedName isEqualToString:cameraName]) {
            deviceId = [NSString stringWithString:device.uniqueID];
            break;
        }
    }
    
    if (deviceId == nil) {
        NSLog(@"Camera wasn't found in the device list. Can't start a stream");
        return;
    }
    
    self.cameraCapture = [[AVCameraCapture alloc] initWithCameraId:deviceId filePathForStreamRecord:self.pathRecordStream previewFrame:self.viewPreview.bounds];
    
    // setup session for the current camera
    BOOL sessionStarted = NO;
    if (self.cameraCapture != nil) {
        sessionStarted = [self.cameraCapture setupCaptureSession];
    }
    
    // start the stream
    if (sessionStarted) {
        [self.cameraCapture startCapture:self.checkGrayscale.state];
    }
    
    CALayer* preview = [self.cameraCapture getPreviewLayer];
    preview.frame = self.viewPreview.bounds;
    self.viewPreview.layer.backgroundColor = CGColorCreateGenericGray(1.0, 1.0);
    preview.contentsGravity = kCAGravityResizeAspect;
    [self.viewPreview.layer addSublayer:preview];
    self.viewPreview.wantsLayer = YES;
    
    self.comboBoxVideoDeviceList.enabled = NO;
    self.checkGrayscale.enabled = NO;
    self.checkRecordStream.enabled = NO;
    
    self.buttonIconStatus.image = [NSImage imageNamed:@"iconGreen"];
}

- (IBAction)stopCamera:(id)sender {
    NSLog(@"stop");
    
    [self.cameraCapture stopCapture];
    self.cameraCapture = nil;
    
    self.comboBoxVideoDeviceList.enabled = YES;
    self.checkGrayscale.enabled = YES;
    self.checkRecordStream.enabled = YES;
    
    self.buttonIconStatus.image = [NSImage imageNamed:@"iconYellow"];
}

- (IBAction)onClick:(id)sender {
    [self stopCamera:nil];
}

- (void)addObservers {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onCameraAttached:) name:AVCaptureDeviceWasConnectedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onCameraDetached:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
}

- (void)removeObservers {
    [NSNotificationCenter.defaultCenter removeObserver:self name:AVCaptureDeviceWasConnectedNotification object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:AVCaptureDeviceWasDisconnectedNotification object:nil];
}

- (void)onCameraAttached:(NSNotification *)notification {
    NSLog(@"Camera was arrived");
    
    AVCaptureDevice* device = (AVCaptureDevice*)notification.object;
    [self alertDialogWithMessage:@"New camera arrived" info:device.localizedName];
    
    [self getDeviceList];
    [self fillComboBoxVideoDeviceList];
}

- (void)onCameraDetached:(NSNotification *)notification {
    NSLog(@"Camera was detached");
    
    NSString* cameraName = [self.comboBoxVideoDeviceList objectValueOfSelectedItem];
    
    AVCaptureDevice* device = (AVCaptureDevice*)notification.object;
    [self alertDialogWithMessage:@"Camera was detached" info:device.localizedName];
    
    if ([device.localizedName isEqualToString:cameraName]) {
        // the active camera was detached. Needs to stop session
        [self stopCamera:nil];
    }
    
    [self getDeviceList];
    [self fillComboBoxVideoDeviceList];
    
    if (self.cameraCapture == nil && self.comboBoxVideoDeviceList.numberOfItems > 0) {
        [self.comboBoxVideoDeviceList selectItemWithObjectValue:[self.comboBoxVideoDeviceList itemObjectValueAtIndex:0]];
    }
    
    if ([self.cameraCapture isSessionRunning]) {
        self.comboBoxVideoDeviceList.enabled = NO;
        // the camera is still working and should represent the same name in the ComboBox
        [self.comboBoxVideoDeviceList objectValueOfSelectedItem];
    } else {
        self.comboBoxVideoDeviceList.enabled = YES;
    }
}

- (IBAction)onCheckRecordStreamClick:(id)sender {
    [self openFileDialog];
}

- (void)openFileDialog {
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];

    // Disable the selection of files in the dialog.
    [openDlg setCanChooseFiles:NO];

    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];

    // Can't select a directory
    [openDlg setCanChooseDirectories:YES];

    // Display the dialog. If the OK button was pressed, process the files.
    if ( [openDlg runModal] == NSModalResponseOK ) {
        // Get an array containing the full filenames of all files and directories selected.
        NSArray* urls = openDlg.URLs;

        if (urls.count > 0) {
            // Choose the only one directory for file save.
            self.pathRecordStream = [urls objectAtIndex:0];
            
            self.pathRecordStream = [self.pathRecordStream URLByAppendingPathComponent:TestRecordStream];
            
            NSLog(@"Directory URL: %@", self.pathRecordStream.absoluteString);
        }
    }
}

- (void)alertDialogWithMessage:(NSString*)message info:(NSString*)info {
    NSAlert* alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = message;
    alert.informativeText = info;
    [alert runModal];
}

@end
