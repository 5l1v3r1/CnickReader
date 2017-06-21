# Flomio Software Development Kit

A turn-key middleware layer for Flomio's line of NFC, BLE, and UHF RFID readers.

**Contributors**: grundyoso, bpolania, jchuck627, jdisser, scottire
**Tags**: FloJackBzr, FloJackMsr, FloBle, FloMat, NFC, BLE, RFID  
**Requires at least**: iOS 9.0  
**Tested up to**: iOS 9.0
**Stable tag**: 2.1 (1)

## Description

Flomio builds hardware and software solutions in the proximity ID space. With a focus on mobile platforms, Flomio makes it easy to integrate our readers into Apps for iOS, Android, and WindowsPhone.

## Installation

1. Unzip FlomioSDK.zip.
2. Create new or open your iOS project in Xcode and select the root project file from the navigator.
3. Unzip FlomioSDK folder Drag+drop the "iOS" folder on project in Xcode navigator. Make sure the "Copy items if needed" option is selected and click "Create groups" and "Finish" in dialog.
4. In Targets -> YourAppTarget -> Build Settings -> Linking -> Other Linker Flags add ‘-lc++’ and ’-ObjC’
   In Targets -> YourAppTarget -> Build Options -> Enable Bitcode set to ‘No’
   (optional) In Target-> Build Settings-> Apple LLVM 7.0-Preprocessing -> Preprocessor Macros add ‘DEBUGLOG’
   In Targets -> YourAppTarget -> General -> Link Binary with Libraries, add MediaPlayer.Framework
5. Include the FlomioSDK header files in your view controller and implement the delegate protocols.

   ```objectivec
   #import "FmSessionManager.h"
   @interface ViewController : UIViewController <FmSessionManagerDelegate> {  
     FmSessionManager *readerManager;
   }   

   @end
   ```
  

6.  Instantiate the `FmSessionManager` in `viewDidLoad:`

   ```objectivec
  
   // Set SDK configuration and reader settings
    
    readerManager = [FmSessionManager sharedManager];
    readerManager.selectedDeviceType = kFloBlePlus; // For FloBLE Plus
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

    ```

7. Observe notifications to manage reader for background/foreground in `viewDidLoad:`

   ```objectivec
   // Stop reader scan when the app becomes inactive
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inactive) name:UIApplicationDidEnterBackgroundNotification object:nil];
   // Start reader scan when the app becomes active
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(active) name:UIApplicationDidBecomeActiveNotification object:nil];


   ```

8. Create ReaderManagerDelegate methods to catch reader events

   ```objectivec

- (void)active {
  NSLog(@"App Activated");
}

- (void)inactive {
  NSLog(@"App Inactive");
}

- (void)didFindTagWithUuid:(NSString *)Uuid fromDevice:(NSString *)deviceId withAtr:(NSString *)Atr withError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        //Use the main queue if the UI must be updated with the tag UUID or the deviceId
        NSLog(@"Found tag UUID: %@ from device:%@",Uuid,deviceId);
    });
}

- (void)didFindTagWithData:(NSDictionary *)payload fromDevice:(NSString *)deviceId withAtr:(NSString *)Atr withError:(NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        //Use the main queue if the UI must be updated with the tag data or the deviceId
        if (payload[@"Raw Data"]){
            NSLog(@"Found raw data: %@ from device:%@",payload[@"Raw Data"] ,deviceId);
        } else if (payload[@"Ndef"]) {
            NSLog(@"Found Ndef Message: %@ from device:%@",payload[@"Ndef"] ,deviceId);
        }
    });
}

- (void)didReceiveReaderError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{ // Second dispatch message to log tag and restore screen
       NSLog(@"%@",error); //Reader error
    });
}

- (void)didUpdateConnectedDevices:(NSArray *)connectedDevices {
    //The list of connected devices was updated
}

- (void)didChangeCardStatus:(CardStatus)status fromDevice:(NSString *)deviceId {
     //The card status has entered or left the scan range of the reader
    // Cardstatus:
    // 0:kNotPresent
    // 1:kPresent
    // 2:kReadingData
}
   ```

9. To send APDU command, use FmSessionManager
e.g:
[readerManager sendApdu:@"FF CA 00 00 00" toDevice: deviceId];

10. For FloBLE Plus v1.16.03 firmware, to control power modes
    Use Power Operation to control how
      [readerManager startReader: deviceId];
    and
      [readerManager stopReader: deviceId];
    control your reader.
    use kAutoPollingControl to toggle NFC
    use kBluetoothConnectionControl to toggle Bluetooth connection

11. That's it. Now build, run, and observe scans in the console!

## Future Plans

Need to add management for reading of extensive data blocks. Currently limited to 16 bytes read at a time. Data throughput limitation may have an impact on user experience.

## Frequently Asked Questions

**Q**: Can the SDK run in the background?  
**A**: We don't expect Apps to ever be able operate FloJacks in the background. The FloJack requires a heartbeat handshake in order to prevent it from going into sleep mode and it's not possible to handle from background. The active/inactive methods in the ViewController are meant to wake/sleep the reader during foregounding/backgrounding. The FloBLE products are able to operate from a backgrounded app state. Also several of the same FloBLE products can connect to the iOS device at once (max 7 connected FloBLEs at a time).

**Q**: I get `*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '*** -[NSURL initFileURLWithPath:]: nil string parameter'` when running my app. What's the problem?  
**A**: You seem to have only partially imported the FlomioSDK. There are needed resources in the SDK package that will not allow the it to run otherwise. These include, but limmited to, ScanSound.caf, FloJackConnected150x150.png, and FloJackDisconnected150x150.png. Check to make sure those resources are in your project and added to your Build Bundle (look in Target->Build Phases->Copy Bundle Resources).

**Q**: My FloJack is not responding when I start the Demo App, I see a red communication indicator and no battery level.
**A**: To troubleshoot this first check that the FloJack is fully seated in the mobile device. Push the reader into the jack firmly. Next be sure you have selected FloJack on the start menu. Next check for a green light on the reader. If 10 seconds after you've started the app there is still no green light and the communications indicator is still red try plugging the charging cable connected to a USB port into the flojack. You should see the light turn amber and the communication indicator turn green along with a battery level of 100% (indicating charging) within 45 seconds, indicating the app is running normally and communicating with the FloJack.

**Q**: I selected FloBLE Plus and tags are not detected. What am I doing wrong?
**A**: We recently added support for FloBLE readers and need to update the SDK interface to account for starting the scan engine for them. For now you can just add `[sharedManager.reader startScan];` to your `viewDidLoad:` routine.

## Changelog

### 2.1 (beta)

* Improved support for NDEF tags
* Added parsing of Smart Poster formatted NDEF tags
* Added manual configuration for each reader to either read data or UUID
* Added dedicated NdefMessage & NdefRecord objects
* Added options for configuring power usage with FloBLE Plus

### 2.0

* Refactored SDK.
* Simplified delegate methods.
* Improved support for multiconnectivity
* Added error management for developers
* Added ability to send APDUs with BZR

### 1.9
* Added Flojack BZR support.
* Communication Status report. Query to SDK provides communication status to FloJack reader.
* Battery Level report. Query to SDK provides FloJack battery level. This is most often 100% given that Lithium polymer batteries fail rapidly once the reach their capacity limits. Full charge will provide 5.25hrs (6,345 scans) while 20secs of charge will provide 4.5mins (108 scans). It's a nonlinear relationship.
* We ensured that the new Communication Status and Battery Level Events were being reported as delegate methods that are called when the events occur. These are now required for the SDK consumer to implement even if not being used:
  * - (void)ReaderManager:(Reader *)reader didSendBatteryLevel:(int)level
  * - (void)ReaderManager:(Reader *)reader isConnected:(BOOL)connected
* Read/Write Data Blocks now working as in v1.6. didFindDataBlocks API changed to return NSData vs NSString:
  * - (void)didFindDataBlocks:(NSData *)data fromDevice:(NSString *)deviceId
* Auto-reestablishment of communication between Host device and Reader
* Removes excessive debug info from console log. To regain SDK debug output add "DEBUGLOG" to preprocessor macros (step 4)

### 1.8
* Corrected device UUID retrieved from FloBLE Plus and EMV deviced
* UI fixes for the Flomio SDK Sample app, navigation "Back" removed and SDK cleanup implemented (invalidate timers, etc)
* SDK delegate refactoring to expose deviceID. Requires update to new delegate signature:
  * - (void)didFindATag:(Tag *)tag withOperationState:(ReaderStateType)operationState fromDevice:(NSString *)deviceId withError:(NSError *)error {

### 1.7
* Adds in support for FloBLE Plus and EMV readers.
* Support for multiconnect to FloBLE devices add for Plus and EMV types. These are not interchangeable, can only connect to groups of the same type.

### 1.6

* Adds multi-connect FloBLE Mini functionality such that many iOS to FloBLE connections can be made (max is 1:7)
* Adds FloBLE Mini device UUID support so that each NFC tag can be associated to a particular reader (supported in FloJack)

### 1.5

* Added FloBLE functionality
* Some unused frameworks (most notably Parse) were removed
* UUID Delegate method enabled
* Switches for FloJack and FloBLE ON/OFF

### 1.4

* Added missing Parse libraries and support frameworks
* Removed i386 libraries as I couldn't archive all Parse supporting libraries (no i386 support)
* Cleaned up the README.md to clean up some bugs introduced in last version.

### 1.3

* Adds instructions to properly suspend and reset the Reader from within your App.
* Inlcudes i386 and ARM libraries in the SDK bundle in order to support building for emulator.
* Note: FloJack operations won't function in the emulator.

### 1.2

* Fixes several bugs, most notably the issue of the app crashing after backgrounding.
* Moves all the error codes into the library and issues a standard NSError object.
* Adds device ID check for SDK licensing.
* Adds NTAG203 support to the NDEF parser.
* Some minor refactoring of the SDK APIs to make more understandable.

### 1.1

* Added tag type filtering
* Added Start Block configuration to Read operation state.

### 1.0

* Created README.md to explain how to install and build the Flomio SDK
* Cleaned up code, bundled the headers and archived source into library
* Support for NDEF messages and records.
* Adds scanPeriod support to the SDK app.

### 0.5

* Adds start block and block count to getNfcData method.
* Adds code to init settings from ViewController
* Adds default scan sound. Fixes Ultralight read data blocks bug.

### 0.2

* Support for Mifare Ultralight along with Mifare Mini, Topaz, and Felica
* Updates to add read and write capability through hard coded strings.
* SDK test app includes Settings screen with all configuration entries: scanPeriod, scanSound, readUUID, readDataBlocks, and writeDataBlocks.

### 0.1

* Support for Mifare Classic uuid, authenticate, and read data blocks.
* SDK and test app to work with FloJack reader. audio routing, visual notifications, and UUID read all functional


## Screenshots

[Check out our videos on YouTube](https://www.youtube.com/watch?v=_fuDfONfIOo)
