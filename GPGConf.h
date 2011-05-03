


@interface GPGConf : NSObject {
	NSString *path;
	NSStringEncoding encoding;
	NSMutableArray *confLines;
	BOOL autoSave;
}

@property (retain) NSString *path;
@property NSStringEncoding encoding;
@property BOOL autoSave;


- (id)initWithPath:(NSString *)aPath;
- (void)loadConfig;
- (void)saveConfig;


- (NSArray *)optionsWithName:(NSString *)name;
- (NSArray *)enabledOptionsWithName:(NSString *)name;
- (NSArray *)disabledOptionsWithName:(NSString *)name;
- (NSArray *)optionsWithName:(NSString *)name state:(int)state;

@end
