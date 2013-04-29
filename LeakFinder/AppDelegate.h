//
//  AppDelegate.h
//  LeakFinder
//
//  Created by Lukas Pitschl on 23.04.13.
//
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)doEncrypt:(id)sender;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *encryptButton;

@end
