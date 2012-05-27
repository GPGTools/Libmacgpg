#import "DirectoryWatcher.h"


@interface GPGWatcher : NSObject <DirectoryWatcherDelegate> {
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
}

// default is 1.0
@property (assign, nonatomic) NSTimeInterval toleranceBefore;
// default is 1.0
@property (assign, nonatomic) NSTimeInterval toleranceAfter;

+ (id)sharedInstance;
+ (void)activate;

// really for unit testing. Use sharedInstance normally!
- (id)initWithGpgHome:(NSString *)directoryPath;

@end
