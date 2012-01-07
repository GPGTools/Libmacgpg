#import "GPGWatcher.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"

@interface GPGWatcher ()
@property (retain) NSMutableDictionary *changeDates;
- (void)updateWatcher;
- (void)timerFired:(NSTimer *)timer;
- (void)keysChangedNotification:(NSNotification *)notification;
@end


@implementation GPGWatcher
@synthesize changeDates;
#define TOLERANCE_BEFORE 10.0
#define TOLERANCE_AFTER 5.0



- (void)updateWatcher {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableSet *filesToWatch = [NSMutableSet set];
	NSMutableDictionary *dates = [NSMutableDictionary dictionary];
	
	NSString *gpgHome = [[[GPGOptions sharedOptions] gpgHome] stringByStandardizingPath];
	
	//TODO: Full support for symlinks.
	[filesToWatch addObject:[gpgHome stringByAppendingPathComponent:@"pubring.gpg"]];
	[filesToWatch addObject:[gpgHome stringByAppendingPathComponent:@"secring.gpg"]];
	
	
	
	for (NSString *file in filesToWatch) {
		NSDate *date = [[fileManager attributesOfItemAtPath:file error:nil] fileModificationDate];
		
		if (date) {
			[dates setObject:date forKey:file]; 
		}
	}
	self.changeDates = dates;
	
	
	[dirWatcher removeAllPaths];
	[dirWatcher addPath:gpgHome];
}



- (void)pathsChanged:(NSArray *)paths flags:(const FSEventStreamEventFlags [])flags {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDate *date1, *date2;
	
	for (NSString *file in changeDates) {
		date1 = [changeDates objectForKey:file];
		date2 = [[fileManager attributesOfItemAtPath:file error:nil] fileModificationDate];
		
		if (!date1 || !date2 || ![date1 isEqualToDate:date2]) {
			// Change found.
			[changeDates setObject:date2 forKey:file];
			
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


//TODO: Testen ob Symlinks in der Mitte des Pfades korrekt verarbeitet werden.
- (void)workspaceDidMount:(NSNotification *)notification {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *gpgHome = [[GPGOptions sharedOptions] gpgHome], *resolvedGPGHome = nil, *temp;
	
	// Resolve symlinks.
	do {
		resolvedGPGHome = [fileManager destinationOfSymbolicLinkAtPath:gpgHome error:nil];
		if (!resolvedGPGHome) {
			break;
		} else if (![resolvedGPGHome hasPrefix:@"/"]) {
			resolvedGPGHome = [[[gpgHome stringByDeletingLastPathComponent] stringByAppendingPathComponent:resolvedGPGHome] stringByStandardizingPath];
		}
		
		temp = gpgHome;
		gpgHome = resolvedGPGHome;
	} while (![gpgHome isEqualToString:temp]);
	
	
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	
	if ([gpgHome rangeOfString:devicePath].length > 0) {
		// The (un)mounted volume contains gpgHome.
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeysChangedNotification object:identifier userInfo:nil options:0];
	}
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
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidMount:) name:NSWorkspaceDidMountNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidMount:) name:NSWorkspaceDidUnmountNotification object:[NSWorkspace sharedWorkspace]];

		
		
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
