#import "JailfreeTask.h"
#import "DirectoryWatcher.h"

extern NSString * const GPGKeysChangedNotification;

@interface GPGWatcher : NSObject <DirectoryWatcherDelegate
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
, Jail
#endif
> {
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
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
    NSXPCConnection *jailfree;
#endif
    BOOL _checkForSandbox;
}

// default is 1.0
@property (assign, nonatomic) NSTimeInterval toleranceBefore;
// default is 1.0
@property (assign, nonatomic) NSTimeInterval toleranceAfter;
#if defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1080
@property (assign, nonatomic) NSXPCConnection *jailfree;
#endif
+ (id)sharedInstance;
+ (void)activate;

// really for unit testing. Use sharedInstance normally!
- (id)initWithGpgHome:(NSString *)directoryPath;

@property (nonatomic, assign) BOOL checkForSandbox;

+ (void)activateWithXPCConnection:(id)connection;

@end
