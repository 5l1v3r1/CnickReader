//
//  ViewController.h
//  CnickReader
//
//  Created by Tornike Davitashvili on 6/20/17.
//  Copyright © 2017 Tornike Davitashvili. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioJack.h"

@interface ViewController : UIViewController<ACRAudioJackReaderDelegate>

@property ACRAudioJackReader *reader;
@property ACRDukptReceiver *dukptReceiver;

@end
