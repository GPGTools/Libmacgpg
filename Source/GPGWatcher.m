#import "GPGWatcher.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"

@interface GPGWatcher ()
@property (retain) NSDictionary *changeDates;
- (void)updateWatcher;
- (void)timerFired:(NSTimer *)timer;
- (void)keysChangedNotification:(NSNotification *)notification;
@end


@implementation GPGWatcher
@synthesize changeDates;
#define TOLERANCE_BEFORE 10.0
#define TOLERANCE_AFTER 5.0

//TODO: Timings anpassen.
//TODO: Mount and unmount?


- (void)updateWatcher {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableSet *filesToWatch = [NSMutableSet set], *dirsToWatch = [NSMutableSet set];
	NSMutableDictionary *dates = [NSMutableDictionary dictionary];
	NSString *path;
	
	NSString *gpgHome = [[GPGOptions sharedOptions] gpgHome];
	
	//TODO: Full support for symlinks.
	path = [[gpgHome stringByAppendingPathComponent:@"pubring.gpg"] stringByStandardizingPath];
	if (path) {
		[filesToWatch addObject:path];
	}
	path = [[gpgHome stringByAppendingPathComponent:@"secring.gpg"] stringByStandardizingPath];
	if (path) {
		[filesToWatch addObject:path];
	}
	
	
	
	for (NSString *file in filesToWatch) {
		NSDate *date = [[fileManager attributesOfItemAtPath:file error:nil] fileModificationDate];
		
		if (date) {
			[dates setObject:date forKey:file]; 
		}
		[dirsToWatch addObject:[file stringByDeletingLastPathComponent]];
	}
	self.changeDates = dates;
	
	
	[dirWatcher removeAllPaths];
	[dirWatcher addPaths:[dirsToWatch allObjects]];
}



- (void)pathsChanged:(NSArray *)paths flags:(const FSEventStreamEventFlags [])flags {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDate *date1, *date2;
	
	for (NSString *file in changeDates) {
		date1 = [changeDates objectForKey:file];
		date2 = [[fileManager attributesOfItemAtPath:file error:nil] fileModificationDate];
		
		if (!date1 || !date2 || ![date1 isEqualToDate:date2]) {
			// Change found.
			
			lastFoundChange = [NSDate timeIntervalSinceReferenceDate];
			if (lastKnownChange + TOLERANCE_BEFORE < lastFoundChange) {
				[NSTimer scheduledTimerWithTimeInterval:TOLERANCE_AFTER target:self selector:@selector(timerFired:) userInfo:[NSNumber numberWithDouble:lastFoundChange] repeats:NO];
			}
			break;
		}
	}
}
- (void)timerFired:(NSTimer *)timer {
	NSTimeInterval foundChange = [[timer userInfo] doubleValue];
	if (lastKnownChange + TOLERANCE_BEFORE < foundChange) {
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeysChangedNotification object:identifier userInfo:nil options:0];
	}
}
- (void)keysChangedNotification:(NSNotification *)notification {
	lastKnownChange = [NSDate timeIntervalSinceReferenceDate];
}



// Singleton: alloc, init etc.
+ (void)activate {
	[self sharedInstance];
}
+ (id)sharedInstance {
	static id sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[super allocWithZone:nil] init];
    }
    return sharedInstance;	
}
- (id)init {
	static BOOL initialized = NO;
	if (!initialized) {
		initialized = YES;
		self = [super init];
		
		identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];
		
		dirWatcher = [[DirectoryWatcher alloc] init];
		dirWatcher.delegate = self;
		dirWatcher.latency = 5.0;
		[self updateWatcher];
		
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysChangedNotification:) name:GPGKeysChangedNotification object:nil];
		
		[[NSGarbageCollector defaultCollector] disableCollectorForPointer:self];
	}
	return self;
}
+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];	
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}
- (id)retain {
    return self;
}
- (NSUInteger)retainCount {
    return NSUIntegerMax;
}
- (oneway void)release {
}
- (id)autorelease {
    return self;
}


@end
