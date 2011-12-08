



@interface GPGConf : NSObject {
	NSString *path;
	NSMutableDictionary *config;
}
@property (retain, readonly) NSString *path;

- (BOOL)saveConfig;
+ (id)confWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;


@end
