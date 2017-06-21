//
//  ViewController.m
//  CnickReader
//
//  Created by Tornike Davitashvili on 6/20/17.
//  Copyright © 2017 Tornike Davitashvili. All rights reserved.
//

#import "ViewController.h"
#import "FmSessionManager.h"

@interface ViewController ()<FmSessionManagerDelegate>{
    FmSessionManager *readerManager;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self configureReader];
}
-(void)configureReader{
    readerManager = [FmSessionManager sharedManager];
    readerManager.selectedDeviceType = kFlojackBzr; // For FloBLE Plus
    //kFlojackMsr, kFlojackBzr for audiojack readers
    readerManager.delegate = self;
    readerManager.specificDeviceId = nil;
    //@"RR330-000120" use device id from back of device to only connect to specific device
    // only for use when "Allow Multiconnect" = @0
    
    NSDictionary *configurationDictionary = @{
                                              @"Scan Sound" : @1,
                                              @"Scan Period" : @1000,
                                              @"Reader State" : [NSNumber numberWithInt:kReadUuid], //kReadData for NDEF
                                              @"Power Operation" : [NSNumber numberWithInt:kAutoPollingControl], //kBluetoothConnectionControl low power usage
                                              @"Transmit Power" : [NSNumber numberWithInt: kHighPower],
                                              @"Allow Multiconnect" : @0, //control whether multiple FloBLE devices can connect
                                              };
    
    [readerManager setConfiguration: configurationDictionary];
    [readerManager createReaders];
}

- (void)active {
    NSLog(@"App Activated");
    [readerManager startReaders];
}

- (void)inactive {
    NSLog(@"App Inactive");
    [readerManager stopReaders];
}
-(void)shwoAlertController:(NSString*)message{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}
#pragma mark - FmSessionManagerDelegate

- (void)didFindTagWithUuid:(NSString *)Uuid fromDevice:(NSString *)deviceId withAtr:(NSString *)Atr withError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        //Use the main queue if the UI must be updated with the tag UUID or the deviceId
        NSString *Udid = [NSString stringWithFormat:@"Found tag UUID: %@ from device:%@",Uuid,deviceId];
        [self shwoAlertController:Udid];
        NSLog(@"Found tag UUID: %@ from device:%@",Uuid,deviceId);
    });
}

- (void)didFindTagWithData:(NSDictionary *)payload fromDevice:(NSString *)deviceId withAtr:(NSString *)Atr withError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        //Use the main queue if the UI must be updated with the tag data or the deviceId
        if (payload[@"Raw Data"]){
            NSLog(@"Found raw data: %@ from device:%@",payload[@"Raw Data"] ,deviceId);
            NSString *Udid = [NSString stringWithFormat:@"Found raw data: %@ from device:%@",payload[@"Raw Data"] ,deviceId];
            [self shwoAlertController:Udid];
        } else if (payload[@"Ndef"]) {
            NSLog(@"Found Ndef Message: %@ from device:%@",payload[@"Ndef"] ,deviceId);
            NSString *Udid = [NSString stringWithFormat:@"Found Ndef Message: %@ from device:%@",payload[@"Ndef"] ,deviceId];
            [self shwoAlertController:Udid];
        }
    });
}

- (void)didReceiveReaderError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{ // Second dispatch message to log tag and restore screen
        NSLog(@"%@",error); //Reader error
        NSString *Udid = [NSString stringWithFormat:@"%@",error];
        [self shwoAlertController:Udid];

    });
}
-(void)didFindATagUuid:(NSString *)UUID fromDevice:(NSString *)serialNumber withATR:(NSString *)detectedATR withError:(NSError *)error{
    
}
-(void)didFindADataBlockWithNdef:(NdefMessage *)ndef fromDevice:(NSString *)serialNumber withError:(NSError *)error{
    
}
-(void)didRespondToApduCommand:(NSString *)response fromDevice:(NSString *)serialNumber withError:(NSError *)error{
    
}
- (void)didUpdateConnectedDevices:(NSArray *)connectedDevices {
    if (connectedDevices.count > 0) {
        FmDevice *device = connectedDevices[0];

    }
    //The list of connected devices was updated
}

- (void)didChangeCardStatus:(CardStatus)status fromDevice:(NSString *)deviceId {
    //The card status has entered or left the scan range of the reader
    // Cardstatus:
    // 0:kNotPresent
    // 1:kPresent
    // 2:kReadingData
}

#pragma mark - IBAction

- (IBAction)startReading:(UIButton *)sender {
    [self active];
}


@end
