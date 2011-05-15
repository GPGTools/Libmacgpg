


@interface GPGConf : NSObject {
	NSString *path;
	NSStringEncoding encoding;
	NSMutableArray *confLines;
	BOOL autoSave;
}

@property (retain) NSString *path;
@property NSStringEncoding encoding;
@property BOOL autoSave;


+ (id)confWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;
- (void)loadConfig;
- (void)saveConfig;


- (NSArray *)optionsWithName:(NSString *)name;
- (NSArray *)enabledOptionsWithName:(NSString *)name;
- (NSArray *)disabledOptionsWithName:(NSString *)name;
- (NSArray *)optionsWithName:(NSString *)name state:(int)state;



- (void)addOptionWithName:(NSString *)name;
- (void)removeOptionWithName:(NSString *)name;
- (int)stateOfOptionWithName:(NSString *)name;
- (void)setValue:(NSString *)value forOptionWithName:(NSString *)name;
- (void)addOptionWithName:(NSString *)name andValue:(NSString *)value;
- (void)removeOptionWithName:(NSString *)name andValue:(NSString *)value;
- (void)setAllOptionsWithName:(NSString *)name values:(NSArray *)values;


@end
