#import "GPGWatcher.h"
#import "GPGGlobals.h"
#import "GPGOptions.h"

@interface GPGWatcher ()
@property (retain) NSMutableDictionary *changeDates;
- (NSString *)gpgCurrentHome;
- (void)updateWatcher;
- (void)timerFired:(NSTimer *)timer;
- (void)keysChangedNotification:(NSNotification *)notification;
@end


@implementation GPGWatcher
@synthesize changeDates;
@synthesize toleranceBefore;
@synthesize toleranceAfter;

#define TOLERANCE_BEFORE 10.0
#define TOLERANCE_AFTER 10.0
#define DW_LATENCY 5.0

static NSString * const kWatcherLastFoundChange = @"lastFoundChange";
static NSString * const kWatchedFileName = @"watchedFileName";

- (void)dealloc 
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];    
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

    [dirWatcher release];
    [identifier release];
    [changeDates release];
    [filesToWatch release];
    [gpgSpecifiedHome release];
    [super dealloc];
}

- (void)setToleranceBefore:(NSTimeInterval)interval {
    if (interval < 0)
        interval = 0;
    toleranceBefore = interval;
}

- (void)setToleranceAfter:(NSTimeInterval)interval {
    if (interval < 0)
        interval = 0;
    toleranceAfter = interval;
}

- (NSString *)gpgCurrentHome {
    if (gpgSpecifiedHome)
        return gpgSpecifiedHome;
    return [[[GPGOptions sharedOptions] gpgHome] stringByStandardizingPath];
}

- (void)updateWatcher {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableDictionary *dates = [NSMutableDictionary dictionary];
	
	NSString *gpgHome = [self gpgCurrentHome];
	
	//TODO: Full support for symlinks.
	for (NSString *file in [filesToWatch allKeys]) {
        NSString *pathToFile = [gpgHome stringByAppendingPathComponent:file];
		NSDate *date = [[fileManager attributesOfItemAtPath:pathToFile error:nil] fileModificationDate];		
        // when nil, set to something old so that we can detect file creation
		if (!date) 
            date = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        [dates setObject:date forKey:file]; // note: not full path; just name
	}
	self.changeDates = dates;
	
	[dirWatcher removeAllPaths];
	[dirWatcher addPath:gpgHome];
}


- (void)pathsChanged:(NSArray *)paths flags:(const FSEventStreamEventFlags [])flags {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDate *date1, *date2;
	NSString *gpgHome = [self gpgCurrentHome];
	
	for (NSString *file in changeDates) {
        NSString *pathToFile = [gpgHome stringByAppendingPathComponent:file];
		date1 = [changeDates objectForKey:file];
		date2 = [[fileManager attributesOfItemAtPath:pathToFile error:nil] fileModificationDate];
        if (!date2)
            date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
		
		if (![date1 isEqualToDate:date2]) {
            [changeDates setObject:date2 forKey:file];

            NSTimeInterval eventLastKnownChange;
            NSString *eventName = [filesToWatch objectForKey:file];
            if ([GPGKeysChangedNotification isEqualToString:eventName]) {
                eventLastKnownChange = lastKnownChange;
            }
            else if ([GPGConfigurationModifiedNotification isEqualToString:eventName]) {
                eventLastKnownChange = lastConfKnownChange;
            }
            else {
                // unexpected!
                continue;
            }

			NSTimeInterval lastFoundChange = [NSDate timeIntervalSinceReferenceDate];
			if (eventLastKnownChange + toleranceBefore < lastFoundChange) {
                NSDictionary *timerInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:lastFoundChange], kWatcherLastFoundChange, 
                                           file, kWatchedFileName,
                                           nil];
				[NSTimer scheduledTimerWithTimeInterval:toleranceAfter target:self selector:@selector(timerFired:) userInfo:timerInfo repeats:NO];
			}
			break;
		}
	}
}
- (void)timerFired:(NSTimer *)timer {
    NSDictionary *timerInfo = [timer userInfo];
	NSTimeInterval foundChange = [[timerInfo objectForKey:kWatcherLastFoundChange] doubleValue];
    NSString *watchedFile = [timerInfo objectForKey:kWatchedFileName];

    NSString *eventName = [filesToWatch objectForKey:watchedFile];
    if ([GPGKeysChangedNotification isEqualToString:eventName]) {
        // for this event type, lastKnownChange is set by watching the event itself!
        // (see keysChangedNotification:)

        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGKeysChangedNotification object:identifier userInfo:nil options:0];
    }
    else if ([GPGConfigurationModifiedNotification isEqualToString:eventName]) {
        // for this event type, we track lastConfKnownChange ourself
        lastConfKnownChange = foundChange;

        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:GPGConfigurationModifiedNotification object:identifier userInfo:nil options:0];
    }
}
- (void)keysChangedNotification:(NSNotification *)notification {
	lastKnownChange = [NSDate timeIntervalSinceReferenceDate];
}


//TODO: Testen ob Symlinks in der Mitte des Pfades korrekt verarbeitet werden.
- (void)workspaceDidMount:(NSNotification *)notification {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *gpgHome = [self gpgCurrentHome];
	NSString *resolvedGPGHome = nil, *temp;
	
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

static id syncRoot = nil;

+ (void)initialize {
    if (!syncRoot)
        syncRoot = [[NSObject alloc] init];
}

+ (void)activate {
	[self sharedInstance];
}

+ (id)sharedInstance {
    // Normally might just setup the singleton in initialize and not worry
    // about locking; but for unit testing, we don't want spurious events,
    // as no one will have called sharedInstance.
    static id sharedInstance = nil;
    @synchronized(syncRoot) {
        if (!sharedInstance)
            sharedInstance = [[self alloc] init];
    }
    return [[sharedInstance retain] autorelease];	
}

- (id)init {
    return [self initWithGpgHome:nil];
}

- (id)initWithGpgHome:(NSString *)directoryPath
{
    if (self = [super init]) {
        gpgSpecifiedHome = [directoryPath retain];
        filesToWatch = [[NSDictionary alloc] initWithObjectsAndKeys:
                        GPGKeysChangedNotification, @"pubring.gpg", 
                        GPGKeysChangedNotification, @"secring.gpg",
                        GPGConfigurationModifiedNotification, @"gpg.conf",
                        GPGConfigurationModifiedNotification, @"gpg-agent.conf",
                        nil];

		identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];

		self.toleranceBefore = TOLERANCE_BEFORE;
        self.toleranceAfter = TOLERANCE_AFTER;

		dirWatcher = [[DirectoryWatcher alloc] init];
		dirWatcher.delegate = self;
		dirWatcher.latency = DW_LATENCY;
		[self updateWatcher];
		
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(keysChangedNotification:) name:GPGKeysChangedNotification object:nil];
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidMount:) name:NSWorkspaceDidMountNotification object:[NSWorkspace sharedWorkspace]];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidMount:) name:NSWorkspaceDidUnmountNotification object:[NSWorkspace sharedWorkspace]];

		
		
		[[NSGarbageCollector defaultCollector] disableCollectorForPointer:self];
	}
	return self;
}

@end
