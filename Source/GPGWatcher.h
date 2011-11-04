#import "DirectoryWatcher.h"


@interface GPGWatcher : NSObject <DirectoryWatcherDelegate> {
	DirectoryWatcher *dirWatcher;
	NSTimeInterval lastKnownChange; // Zeitpunkt der letzten Änderung durch eine Libmacgpg instanz.
	NSTimeInterval lastFoundChange; // Zeitpunkt der letzten Änderung an einer Datei.
	NSString *identifier;
	NSDictionary *changeDates;
}
+ (id)sharedInstance;
+ (void)activate;

@end
