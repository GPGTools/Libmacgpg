#import "GPGOptions.h"



@interface GPGConf : NSObject {
	NSString *path;
	NSMutableDictionary *config;
    // Contains either GPGStdSetting instances or strings read from the file;
    // If a GPGStdSetting, then it will be mapped in ->config
    NSMutableArray *contents;
    GPGOptionsDomain optionsDomain;
}
@property (nonatomic, retain, readonly) NSString *path;
@property (nonatomic, readwrite) GPGOptionsDomain optionsDomain;
@property (nonatomic, assign) BOOL sandboxed;

- (BOOL)saveConfig;
- (NSString *)getContents;
+ (id)confWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path andDomain:(GPGOptionsDomain)domain;


@end
