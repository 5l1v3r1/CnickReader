//
//  ViewController.m
//  CnickReader
//
//  Created by Tornike Davitashvili on 6/20/17.
//  Copyright © 2017 Tornike Davitashvili. All rights reserved.
//

#import "ViewController.h"
#import "AJDHex.h"
#import <CommonCrypto/CommonCrypto.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController ()
@property NSData *aesKey;
@property NSData *iksn;
@property NSData *ipek;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _aesKey = [AJDHex byteArrayFromHexString:@"4E 61 74 68 61 6E 2E 4C 69 20 54 65 64 64 79 20"];
    _iksn = [AJDHex byteArrayFromHexString:@"FF FF 98 76 54 32 10 E0 00 00"];
    _ipek = [AJDHex byteArrayFromHexString:@"6A C2 92 FA A1 31 5B 4D 85 8A B3 A3 D7 D5 93 3A"];

    // Initialize ACRAudioJackReader object.
    self.reader = [[ACRAudioJackReader alloc] initWithMute:YES];
    [_reader setDelegate:self];
    // Initialize the DUKPT receiver object.
    _dukptReceiver = [[ACRDukptReceiver alloc] init];
    
    // Set the key serial number.
    [_dukptReceiver setKeySerialNumber:_iksn];
    
    // Load the initial key.
    [_dukptReceiver loadInitialKey:_ipek];
    [_reader reset];
}

#pragma mark - ACRAudioJackReaderDelegate
-(void)reader:(ACRAudioJackReader *)reader didNotifyResult:(ACRResult *)result{
    NSLog(@"adadasdasd");
}
-(void)readerDidReset:(ACRAudioJackReader *)reader{
    NSLog(@"reader reset");
    BOOL queue = [self.reader getStatus];
}
-(void)reader:(ACRAudioJackReader *)reader didSendStatus:(ACRStatus *)status{
    
}
-(void)reader:(ACRAudioJackReader *)reader didSendTrackData:(ACRTrackData *)trackData{
    ACRTrack1Data *track1Data = [[ACRTrack1Data alloc] init];
    ACRTrack2Data *track2Data = [[ACRTrack2Data alloc] init];
    ACRTrack1Data *track1MaskedData = [[ACRTrack1Data alloc] init];
    ACRTrack2Data *track2MaskedData = [[ACRTrack2Data alloc] init];
    NSString *track1MacString = @"";
    NSString *track2MacString = @"";
    NSString *batteryStatusString = [self AJD_stringFromBatteryStatus:trackData.batteryStatus];
    NSString *keySerialNumberString = @"";
    NSString *errorString = @"";
    
    if ((trackData.track1ErrorCode != ACRTrackErrorSuccess) &&
        (trackData.track2ErrorCode != ACRTrackErrorSuccess)) {
        
        errorString = @"The track 1 and track 2 data";
        
    } else {
        
        if (trackData.track1ErrorCode != ACRTrackErrorSuccess) {
            errorString = @"The track 1 data";
        }
        
        if (trackData.track2ErrorCode != ACRTrackErrorSuccess) {
            errorString = @"The track 2 data";
        }
    }
    
    errorString = [errorString stringByAppendingString:@" may be corrupted. Please swipe the card again!"];
    
    // Show the track error.
    if ((trackData.track1ErrorCode != ACRTrackErrorSuccess) ||
        (trackData.track2ErrorCode != ACRTrackErrorSuccess)) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:errorString message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];
        });
    }
    
    if ([trackData isKindOfClass:[ACRAesTrackData class]]) {
        
        ACRAesTrackData *aesTrackData = (ACRAesTrackData *) trackData;
        uint8_t *buffer = (uint8_t *) [aesTrackData.trackData bytes];
        NSUInteger bufferLength = [aesTrackData.trackData length];
        uint8_t decryptedTrackData[128];
        size_t decryptedTrackDataLength = 0;
        
        // Decrypt the track data.
        if (![self decryptData:buffer dataInLength:bufferLength key:[_aesKey bytes] keyLength:[_aesKey length] dataOut:decryptedTrackData dataOutLength:sizeof(decryptedTrackData) pBytesReturned:&decryptedTrackDataLength]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The track data cannot be decrypted. Please swipe the card again!" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                [alert show];
            });
            
            goto cleanup;
        }
        
        // Verify the track data.
        if (![_reader verifyData:decryptedTrackData length:decryptedTrackDataLength]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The track data contains checksum error. Please swipe the card again!" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                [alert show];
            });
            
            goto cleanup;
        }
        
        // Decode the track data.
        track1Data = [track1Data initWithBytes:decryptedTrackData length:trackData.track1Length];
        track2Data = [track2Data initWithBytes:decryptedTrackData + 79 length:trackData.track2Length];
        
    } else if ([trackData isKindOfClass:[ACRDukptTrackData class]]) {
        
        ACRDukptTrackData *dukptTrackData = (ACRDukptTrackData *) trackData;
        NSUInteger ec = 0;
        NSUInteger ec2 = 0;
        NSData *key = nil;
        NSData *dek = nil;
        NSData *macKey = nil;
        uint8_t dek3des[24];
        
        keySerialNumberString = [AJDHex hexStringFromByteArray:dukptTrackData.keySerialNumber];
        track1MacString = [AJDHex hexStringFromByteArray:dukptTrackData.track1Mac];
        track2MacString = [AJDHex hexStringFromByteArray:dukptTrackData.track2Mac];
        track1MaskedData = [track1MaskedData initWithString:dukptTrackData.track1MaskedData];
        track2MaskedData = [track2MaskedData initWithString:dukptTrackData.track2MaskedData];
        
        // Compare the key serial number.
        if (![ACRDukptReceiver compareKeySerialNumber:_iksn ksn2:dukptTrackData.keySerialNumber]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The key serial number does not match with the settings." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                [alert show];
            });
            
            goto cleanup;
        }
        
        // Get the encryption counter from KSN.
        ec = [ACRDukptReceiver encryptionCounterFromKeySerialNumber:dukptTrackData.keySerialNumber];
        
        // Get the encryption counter from DUKPT receiver.
        ec2 = [_dukptReceiver encryptionCounter];
        
        // Load the initial key if the encryption counter from KSN is less than
        // the encryption counter from DUKPT receiver.
        if (ec < ec2) {
            
            [_dukptReceiver loadInitialKey:_ipek];
            ec2 = [_dukptReceiver encryptionCounter];
        }
        
        // Synchronize the key if the encryption counter from KSN is greater
        // than the encryption counter from DUKPT receiver.
        while (ec > ec2) {
            
            [_dukptReceiver key];
            ec2 = [_dukptReceiver encryptionCounter];
        }
        
        if (ec != ec2) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The encryption counter is invalid." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                [alert show];
            });
            
            goto cleanup;
        }
        
        key = [_dukptReceiver key];
        if (key == nil) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The maximum encryption count had been reached." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                [alert show];
            });
            
            goto cleanup;
        }
        
        dek = [ACRDukptReceiver dataEncryptionRequestKeyFromKey:key];
        macKey = [ACRDukptReceiver macRequestKeyFromKey:key];
        
        // Generate 3DES key (K1 = K3).
        memcpy(dek3des, [dek bytes], [dek length]);
        memcpy(dek3des + [dek length], [dek bytes], 8);
        
        if (dukptTrackData.track1Data != nil) {
            
            uint8_t track1Buffer[80];
            size_t bytesReturned = 0;
            NSString *track1DataString = nil;
            
            // Decrypt the track 1 data.
            if (![self AJD_tripleDesDecryptData:[dukptTrackData.track1Data bytes] dataInLength:[dukptTrackData.track1Data length] key:dek3des keyLength:sizeof(dek3des) dataOut:track1Buffer dataOutLength:sizeof(track1Buffer) bytesReturned:&bytesReturned]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The track 1 data cannot be decrypted. Please swipe the card again!" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [alert show];
                });
                
                goto cleanup;
            }
            
            // Generate the MAC for track 1 data.
            track1MacString = [track1MacString stringByAppendingFormat:@" (%@)", [AJDHex hexStringFromByteArray:[ACRDukptReceiver macFromData:track1Buffer dataLength:sizeof(track1Buffer) key:[macKey bytes] keyLength:[macKey length]]]];
            
            // Get the track 1 data as string.
            track1DataString = [[NSString alloc] initWithBytes:track1Buffer length:dukptTrackData.track1Length encoding:NSASCIIStringEncoding];
            
            // Divide the track 1 data into fields.
            track1Data = [track1Data initWithString:track1DataString];
        }
        
        if (dukptTrackData.track2Data != nil) {
            
            uint8_t track2Buffer[48];
            size_t bytesReturned = 0;
            NSString *track2DataString = nil;
            
            // Decrypt the track 2 data.
            if (![self AJD_tripleDesDecryptData:[dukptTrackData.track2Data bytes] dataInLength:[dukptTrackData.track2Data length] key:dek3des keyLength:sizeof(dek3des) dataOut:track2Buffer dataOutLength:sizeof(track2Buffer) bytesReturned:&bytesReturned]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"The track 2 data cannot be decrypted. Please swipe the card again!" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                    [alert show];
                });
                
                goto cleanup;
            }
            
            // Generate the MAC for track 2 data.
            track2MacString = [track2MacString stringByAppendingFormat:@" (%@)", [AJDHex hexStringFromByteArray:[ACRDukptReceiver macFromData:track2Buffer dataLength:sizeof(track2Buffer) key:[macKey bytes] keyLength:[macKey length]]]];
            
            // Get the track 2 data as string.
            track2DataString = [[NSString alloc] initWithBytes:track2Buffer length:dukptTrackData.track2Length encoding:NSASCIIStringEncoding];
            
            // Divide the track 2 data into fields.
            track2Data = [track2Data initWithString:track2DataString];
        }
    }
    
cleanup:
    
    // Show the data.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Finished");
//        _swipeCount++;
//        self.swipeCountLabel.text = [NSString stringWithFormat:@"%d", _swipeCount];
//        
//        self.batteryStatusLabel.text = batteryStatusString;
//        self.keySerialNumberLabel.text = keySerialNumberString;
//        self.track1MacLabel.text = track1MacString;
//        self.track2MacLabel.text = track2MacString;
//        
//        self.track1Jis2DataLabel.text = track1Data.jis2Data;
//        self.track1PrimaryAccountNumberLabel.text = [NSString stringWithFormat:@"%@\n%@", track1Data.primaryAccountNumber, track1MaskedData.primaryAccountNumber];
//        self.track1NameLabel.text = [NSString stringWithFormat:@"%@\n%@", track1Data.name, track1MaskedData.name];
//        self.track1ExpirationDateLabel.text = [NSString stringWithFormat:@"%@\n%@", track1Data.expirationDate, track1MaskedData.expirationDate];
//        self.track1ServiceCodeLabel.text = [NSString stringWithFormat:@"%@\n%@", track1Data.serviceCode, track1MaskedData.serviceCode];
//        self.track1DiscretionaryDataLabel.text = [NSString stringWithFormat:@"%@\n%@", track1Data.discretionaryData, track1MaskedData.discretionaryData];
//        
//        self.track2PrimaryAccountNumberLabel.text = [NSString stringWithFormat:@"%@\n%@", track2Data.primaryAccountNumber, track2MaskedData.primaryAccountNumber];
//        self.track2ExpirationDateLabel.text = [NSString stringWithFormat:@"%@\n%@", track2Data.expirationDate, track2MaskedData.expirationDate];
//        self.track2ServiceCodeLabel.text = [NSString stringWithFormat:@"%@\n%@", track2Data.serviceCode, track2MaskedData.serviceCode];
//        self.track2DiscretionaryDataLabel.text = [NSString stringWithFormat:@"%@\n%@", track2Data.discretionaryData, track2MaskedData.discretionaryData];
//        
//        [self.tableView reloadData];
    });
}
-(void)reader:(ACRAudioJackReader *)reader didSendRawData:(const uint8_t *)rawData length:(NSUInteger)length{
    
}
-(void)readerDidNotifyTrackData:(ACRAudioJackReader *)reader{
    NSLog(@"track data");
}

#pragma mark - Private Methods

/**
 * Converts the battery status to string.
 * @param batteryStatus the battery status.
 * @return the battery status string.
 */
- (NSString *)AJD_stringFromBatteryStatus:(NSUInteger)batteryStatus {
    
    NSString *batteryStatusString = nil;
    
    switch (batteryStatus) {
            
        case ACRBatteryStatusLow:
            batteryStatusString = @"Low";
            break;
            
        case ACRBatteryStatusFull:
            batteryStatusString = @"Full";
            break;
            
        default:
            batteryStatusString = @"Unknown";
            break;
    }
    
    return batteryStatusString;
}
- (BOOL)decryptData:(const void *)dataIn dataInLength:(size_t)dataInLength key:(const void *)key keyLength:(size_t)keyLength dataOut:(void *)dataOut dataOutLength:(size_t)dataOutLength pBytesReturned:(size_t *)pBytesReturned {
    
    BOOL ret = NO;
    
    // Decrypt the data.
    if (CCCrypt(kCCDecrypt, kCCAlgorithmAES128, 0, key, keyLength, NULL, dataIn, dataInLength, dataOut, dataOutLength, pBytesReturned) == kCCSuccess) {
        ret = YES;
    }
    
    return ret;
}
/**
 * Decrypts the data using Triple DES.
 * @param dataIn           the input buffer.
 * @param dataInLength     the input buffer length.
 * @param key              the key.
 * @param keyLength        the key length.
 * @param dataOut          the output buffer.
 * @param dataOutLength    the output buffer length.
 * @param bytesReturnedPtr the pointer to number of bytes returned.
 * @return <code>YES</code> if the operation completed successfully, otherwise
 *         <code>NO</code>.
 */
- (BOOL)AJD_tripleDesDecryptData:(const void *)dataIn dataInLength:(size_t)dataInLength key:(const void *)key keyLength:(size_t)keyLength dataOut:(void *)dataOut dataOutLength:(size_t)dataOutLength bytesReturned:(size_t *)bytesReturnedPtr {
    
    BOOL ret = NO;
    
    // Decrypt the data.
    if (CCCrypt(kCCDecrypt, kCCAlgorithm3DES, 0, key, keyLength, NULL, dataIn, dataInLength, dataOut, dataOutLength, bytesReturnedPtr) == kCCSuccess) {
        ret = YES;
    }
    
    return ret;
}
@end
