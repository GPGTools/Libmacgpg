
@class GPGConf;

typedef enum {
	GPGDomain_standard,
	GPGDomain_common,
	GPGDomain_environment,
	GPGDomain_gpgConf,
	GPGDomain_gpgAgentConf,
	GPGDomain_special //special is not a domain.
} GPGOptionsDomain;



@interface GPGOptions : NSObject {
	BOOL initialized;
	NSMutableDictionary *environment;
	NSMutableDictionary *commonDefaults;
	NSString *httpProxy;
	BOOL autoSave;
	
	
	GPGConf *gpgConf;
	GPGConf *gpgAgentConf;
	NSString *identifier;
	NSUInteger updating;
}

@property (readonly) NSString *httpProxy;
@property BOOL autoSave;


+ (id)sharedOptions;
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;
- (id)valueForKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;
- (void)setValue:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;


- (id)valueInStandardDefaultsForKey:(NSString *)key;
- (void)setValueInStandardDefaults:(id)value forKey:(NSString *)key;

- (id)valueInCommonDefaultsForKey:(NSString *)key;
- (void)setValueInCommonDefaults:(id)value forKey:(NSString *)key;
- (void)autoSaveCommonDefaults;
- (void)saveCommonDefaults;
- (void)loadCommonDefaults;
- (NSMutableDictionary *)commonDefaults;

- (id)valueInEnvironmentForKey:(NSString *)key;
- (void)setValueInEnvironment:(id)value forKey:(NSString *)key;
- (void)autoSaveEnvironment;
- (void)saveEnvironment;
- (void)loadEnvironment;

- (id)specialValueForKey:(NSString *)key;
- (void)setSpecialValue:(id)value forKey:(NSString *)key;


+ (NSString *)standardizedKey:(NSString *)key;
- (GPGOptionsDomain)domainForKey:(NSString *)key;

- (NSString *)gpgHome;


@end
