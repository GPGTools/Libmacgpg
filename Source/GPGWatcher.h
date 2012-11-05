#import "JailfreeTask.h"
#import "DirectoryWatcher.h"

extern NSString * const GPGKeysChangedNotification;

@interface GPGWatcher : NSObject <DirectoryWatcherDelegate, Jail> {
	DirectoryWatcher *dirWatcher;
    // for pubring and secring
	NSTimeInterval lastKnownChange; // Zeitpunkt der letzten Änderung durch eine Libmacgpg instanz.
    // for .conf
	NSTimeInterval lastConfKnownChange;
    
	NSString *identifier;
	NSMutableDictionary *changeDates;
    NSDictionary *filesToWatch;
    NSString *gpgSpecifiedHome;
    
    NSTimeInterval toleranceBefore;
    NSTimeInterval toleranceAfter;
    NSXPCConnection *jailfree;
    BOOL _checkForSandbox;
}

// default is 1.0
@property (assign, nonatomic) NSTimeInterval toleranceBefore;
// default is 1.0
@property (assign, nonatomic) NSTimeInterval toleranceAfter;
@property (assign, nonatomic) NSXPCConnection *jailfree;

+ (id)sharedInstance;
+ (void)activate;

// really for unit testing. Use sharedInstance normally!
- (id)initWithGpgHome:(NSString *)directoryPath;

@property (nonatomic, assign) BOOL checkForSandbox;

@end
