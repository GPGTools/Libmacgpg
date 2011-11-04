
@protocol DirectoryWatcherDelegate
- (void)pathsChanged:(NSArray *)paths flags:(const FSEventStreamEventFlags[])flags;
@end


@interface DirectoryWatcher : NSObject {
	NSObject <DirectoryWatcherDelegate> *delegate;
	FSEventStreamRef eventStream;
	NSMutableSet *pathsToWatch;
	NSUInteger latency;
}

@property (assign) NSObject <DirectoryWatcherDelegate> *delegate;
@property double latency;


+ (id)directoryWatcherWithPath:(NSString *)path;
+ (id)directoryWatcherWithPaths:(NSArray *)paths;
- (id)initWithPath:(NSString *)path;
- (id)initWithPaths:(NSArray *)paths;

- (void)addPath:(NSString *)path;
- (void)addPaths:(NSArray *)paths;
- (void)removePath:(NSString *)path;
- (void)removePaths:(NSArray *)paths;
- (void)removeAllPaths;

@end
