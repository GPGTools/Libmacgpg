/*
 Copyright © Roman Zechmeister, 2011
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
 
 Diese Datei basiert auf GPGOptions.m von MacGPGME.
*/


#import "GPGOptions.h"
#import "GPGConf.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "GPGGlobals.h"


@interface GPGOptions ()
@property (readonly) NSMutableDictionary *environment;
@property (readonly) NSMutableDictionary *commonDefaults;
@property (readonly) NSMutableDictionary *standardDefaults;
- (GPGConf *)gpgConf;
- (GPGConf *)gpgAgentConf;
- (void)valueChanged:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;
- (void)valueChangedNotification:(NSNotification *)notification;
@end


@implementation GPGOptions
GPGOptions *_sharedInstance = nil;
NSString *environmentPlistPath;
NSString *environmentPlistDir;
NSString *commonDefaultsDomain = @"org.gpgtools.common";
NSDictionary *domainKeys;
NSMutableDictionary *defaults = nil;


// Methods to configure GPGOptions.
- (BOOL)autoSave {
	return autoSave;
}
- (void)setAutoSave:(BOOL)value {
	autoSave = value;
	self.gpgConf.autoSave = value;
	self.gpgAgentConf.autoSave = value;
}

- (NSString *)standardDomain {
	return [[standardDomain retain] autorelease];
}
- (void)setStandardDomain:(NSString *)value {
	if (value != standardDomain) {
		[standardDefaults release];
		standardDefaults = nil;
		[standardDomain release];
		standardDomain = [value retain];
	}
}

- (void)registerDefaults:(NSDictionary *)dictionary {
	if (!defaults) {
		defaults = [[NSMutableDictionary alloc] initWithDictionary:dictionary];
	} else {
		for (NSString *key in dictionary) {
			[defaults setObject:[dictionary objectForKey:key] forKey:key];
		}
	}
}



// Methods to get and set values.
- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
	[self setValue:[NSNumber numberWithInteger:value] forKey:key];
}
- (NSInteger)integerForKey:(NSString *)key {
	return [[self valueForKey:key] integerValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
	[self setValue:[NSNumber numberWithBool:value] forKey:key];
}
- (BOOL)boolForKey:(NSString *)key {
	return [[self valueForKey:key] boolValue];
}

- (void)setFloat:(float)value forKey:(NSString *)key {
	[self setValue:[NSNumber numberWithFloat:value] forKey:key];
}
- (float)floatForKey:(NSString *)key {
	return [[self valueForKey:key] floatValue];
}

- (NSString *)stringForKey:(NSString *)key {
	NSString *obj = [self valueForKey:key];
	if (obj && [obj isKindOfClass:[NSString class]]) {
		return obj;
	}
	return nil;
}

- (NSArray *)arrayForKey:(NSString *)key {
	NSArray *obj = [self valueForKey:key];
	if (obj && [obj isKindOfClass:[NSArray class]]) {
		return obj;
	}
	return nil;
}


- (id)valueForKey:(NSString *)key {
	key = [[self class] standardizedKey:key];
	id value = [self valueForKey:key inDomain:[self domainForKey:key]];
	if (!value) {
		value = [defaults objectForKey:key];
	}
	return value;
}
- (void)setValue:(id)value forKey:(NSString *)key {
	key = [[self class] standardizedKey:key];
	[self setValue:value forKey:key inDomain:[self domainForKey:key]];
}
- (void)removeValueForKey:(NSString *)key {
	[self setValue:nil forKey:key];
}

- (id)valueForKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	NSObject *value = nil;
	switch (domain) {
		case GPGDomain_gpgConf:
			value = [self valueInGPGConfForKey:key];
			break;
		case GPGDomain_gpgAgentConf:
			value = [self valueInGPGAgentConfForKey:key];
			break;
		case GPGDomain_environment:
			value = [self valueInEnvironmentForKey:key];
			break;
		case GPGDomain_standard:
			value = [self valueInStandardDefaultsForKey:key];
			break;
		case GPGDomain_common:
			value = [self valueInCommonDefaultsForKey:key];
			break;
		case GPGDomain_special:
			value = [self specialValueForKey:key];
			break;
		default:
			[NSException raise:NSInvalidArgumentException format:@"Illegal domain: %i", domain]; 
	}
	return value;
}
- (void)setValue:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	switch (domain) {
		case GPGDomain_gpgConf:
			[self setValueInGPGConf:value forKey:key];
			break;
		case GPGDomain_gpgAgentConf:
			[self setValueInGPGAgentConf:value forKey:key];
			break;
		case GPGDomain_environment:
			[self setValueInEnvironment:value forKey:key];
			break;
		case GPGDomain_standard:
			[self setValueInStandardDefaults:value forKey:key];
			break;
		case GPGDomain_common:
			[self setValueInCommonDefaults:value forKey:key];
			break;
		case GPGDomain_special:
			[self setSpecialValue:value forKey:key];
			break;
		default:
			[NSException raise:NSInvalidArgumentException format:@"Illegal domain: %i", domain]; 
			break;
	}
}


- (id)specialValueForKey:(NSString *)key {
	if ([key isEqualToString:@"TrustAllKeys"]) {
		return [NSNumber numberWithBool:[[self.gpgConf valueForKey:@"trust-model"] isEqualToString:@"always"]];
	} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
		return [self valueInGPGAgentConfForKey:@"default-cache-ttl"];
	} else if ([key isEqualToString:@"httpProxy"]) {
		return self.httpProxy;
	} else if ([key isEqualToString:@"keyservers"]) {
		return self.keyservers;
	}
	return nil;
}
- (void)setSpecialValue:(id)value forKey:(NSString *)key {
	if ([key isEqualToString:@"TrustAllKeys"]) {
		[self.gpgConf setValue:[value intValue] ? @"always" : nil forKey:@"trust-model"];
	} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
		NSString *defaultCacheTtl = nil, *maxCacheTtl = nil;
		if (value) {
			int cacheTime = [value intValue];
			defaultCacheTtl = [NSString stringWithFormat:@"%i", cacheTime];
			maxCacheTtl = [NSString stringWithFormat:@"%i", cacheTime * 12];
		}
		
		BOOL oldAutoSave = self.gpgAgentConf.autoSave;
		[self.gpgAgentConf setAutoSave:NO];
		[self setValueInGPGAgentConf:defaultCacheTtl forKey:@"default-cache-ttl"];
		[self.gpgAgentConf setAutoSave:oldAutoSave];
		[self setValueInGPGAgentConf:maxCacheTtl forKey:@"max-cache-ttl"];
	}
}


- (id)valueInStandardDefaultsForKey:(NSString *)key {
	if (self.standardDefaults) {
		return [self.standardDefaults objectForKey:key];
	} else {
		return [[NSUserDefaults standardUserDefaults] objectForKey:key];
	}
}
- (void)setValueInStandardDefaults:(id)value forKey:(NSString *)key {
	if (self.standardDefaults) {
		NSObject *oldValue = [self.standardDefaults objectForKey:key];
		if(value != oldValue && ![value isEqual:oldValue]) {
			if (!value) {
				[self.standardDefaults removeObjectForKey:key];
			} else {
				[self.standardDefaults setObject:value forKey:key];
			}
			[self autoSaveStandardDefaults];
			[self valueChanged:value forKey:key inDomain:GPGDomain_standard];
		}
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[self valueChanged:value forKey:key inDomain:GPGDomain_standard];
	}
}
- (void)autoSaveStandardDefaults {
	if (autoSave) {
		[self saveStandardDefaults];
	}
}
- (void)saveStandardDefaults {
	if (self.standardDefaults) {
		[[NSUserDefaults standardUserDefaults] setPersistentDomain:self.standardDefaults forName:standardDomain];
	} else {
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}
- (NSMutableDictionary *)standardDefaults {
	if (standardDomain) {
		if (!standardDefaults) {
			standardDefaults = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] persistentDomainForName:standardDomain]];
		}
		return [[standardDefaults retain] autorelease];
	}
	return nil;
}


- (id)valueInCommonDefaultsForKey:(NSString *)key {
	return [self.commonDefaults objectForKey:key];
}
- (void)setValueInCommonDefaults:(id)value forKey:(NSString *)key {
    NSObject *oldValue = [self.commonDefaults objectForKey:key];
	if(value != oldValue && ![value isEqual:oldValue]) {
		if (!value) {
			[self.commonDefaults removeObjectForKey:key];
		} else {
			[self.commonDefaults setObject:value forKey:key];
		}
		[self autoSaveCommonDefaults];
		[self valueChanged:value forKey:key inDomain:GPGDomain_common];
	}
}
- (void)autoSaveCommonDefaults {
	if (autoSave) {
		[self saveCommonDefaults];
	}
}
- (void)saveCommonDefaults {
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:commonDefaults forName:commonDefaultsDomain];
}
- (NSMutableDictionary *)commonDefaults {
	if (!commonDefaults) {
		commonDefaults = [[NSMutableDictionary alloc] initWithDictionary:[[NSUserDefaults standardUserDefaults] persistentDomainForName:commonDefaultsDomain]];
	}
	return [[commonDefaults retain] autorelease];
}


- (id)valueInEnvironmentForKey:(NSString *)key {
	NSObject *value = [[[NSProcessInfo processInfo] environment] objectForKey:key];
	if (!value) {
		value = [self.environment objectForKey:key];
	}
	return value;
}
- (void)setValueInEnvironment:(id)value forKey:(NSString *)key {
	if (!value) {
		unsetenv([key UTF8String]);
	} else {
		setenv([key UTF8String], [[value description] UTF8String], YES);
	}
	
    NSObject *oldValue = [self.environment objectForKey:key];
	if(value != oldValue && ![value isEqual:oldValue]) {
		if (!value) {
			[self.environment removeObjectForKey:key];
		} else {
			[self.environment setObject:value forKey:key];
		}
		[self autoSaveEnvironment];
		[self valueChanged:value forKey:key inDomain:GPGDomain_environment];
	}
}
- (void)autoSaveEnvironment {
	if (autoSave) {
		[self saveEnvironment];
	}
}
- (void)saveEnvironment {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
	
	if ([fileManager fileExistsAtPath:environmentPlistDir isDirectory:&isDirectory]) {
		if (!isDirectory) {
			NSAssert1(isDirectory, @"'%@' is not a directory.", environmentPlistDir);
		}
	} else {
		NSError *error;
		NSAssert2([fileManager createDirectoryAtPath:environmentPlistDir withIntermediateDirectories:YES attributes:nil error:&error], @"Unable to create directory '%@'. Error: %@", environmentPlistDir, error);
	}
	NSAssert1([self.environment writeToFile:environmentPlistPath atomically:YES], @"Unable to write file '%@'", environmentPlistPath);
}
- (NSMutableDictionary *)environment {
	if (!environment) {
		environment = [[NSMutableDictionary alloc] initWithContentsOfFile:environmentPlistPath];
		if (!environment) {
			environment = [[NSMutableDictionary alloc] init];
		}
	}
	return [[environment retain] autorelease];
}


- (NSArray *)allValuesInGPGConfForKey:(NSString *)key {
    NSArray *lines = [self.gpgConf optionsWithName:key];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[lines count]];
    
    [lines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [values addObject:[obj value]];
    }];
    return values;
}
- (id)valueInGPGConfForKey:(NSString *)key {
	return [self.gpgConf valueForKey:key];
}
- (void)setValueInGPGConf:(id)value forKey:(NSString *)key {
	[self.gpgConf setValue:value forKey:key];
	[self valueChanged:value forKey:key inDomain:GPGDomain_gpgConf];
}

- (NSArray *)allValuesInGPGAgentConfForKey:(NSString *)key {
    NSArray *lines = [self.gpgAgentConf optionsWithName:key];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[lines count]];
    
    [lines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [values addObject:[obj value]];
    }];
    return values;
}
- (id)valueInGPGAgentConfForKey:(NSString *)key {
	return [self.gpgAgentConf valueForKey:key];
}
- (void)setValueInGPGAgentConf:(id)value forKey:(NSString *)key {
	[self.gpgAgentConf setValue:value forKey:key];
	[self valueChanged:value forKey:key inDomain:GPGDomain_gpgAgentConf];
	if (self.gpgAgentConf.autoSave) {
		[self gpgAgentFlush];
	}
}




// Propertys.
- (GPGConf *)gpgConf {
	if (!gpgConf) {
		gpgConf = [[GPGConf alloc] initWithPath:[[self gpgHome] stringByAppendingPathComponent:@"gpg.conf"]];
	}
	return [[gpgConf retain] autorelease];
}
- (GPGConf *)gpgAgentConf {
	if (!gpgAgentConf) {
		gpgAgentConf = [[GPGConf alloc] initWithPath:[[self gpgHome] stringByAppendingPathComponent:@"gpg-agent.conf"]];
	}
	return [[gpgAgentConf retain] autorelease];
}

- (NSString *)gpgHome {
	NSString *path = [self valueInEnvironmentForKey:@"GNUPGHOME"];
	if (!path) {
		path = [NSHomeDirectory() stringByAppendingPathComponent:@".gnupg"];
	}
	return path;
}

- (NSArray *)keyservers { // Returns a list of possible keyservers.
    GPGOptions *options = [GPGOptions sharedOptions];
    
    NSURL *keyserversPlistURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Keyservers" withExtension:@"plist"];
    NSMutableSet *keyservers = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfURL:keyserversPlistURL]];
    [keyservers addObjectsFromArray:[options allValuesInGPGConfForKey:@"keyserver"]];
    return [keyservers allObjects];
}

- (NSString *)httpProxy {
	if (!httpProxy) {
		NSDictionary *proxyConfig = [(NSDictionary *)SCDynamicStoreCopyProxies(nil) autorelease];
		if ([[proxyConfig objectForKey:@"HTTPEnable"] intValue]) {
			httpProxy = [[NSString alloc] initWithFormat:@"%@:%@", [proxyConfig objectForKey:@"HTTPProxy"], [proxyConfig objectForKey:@"HTTPPort"]];
		} else {
			httpProxy = @"";
		}
	}
	return [[httpProxy retain] autorelease];
}



// Helper methods.
- (GPGOptionsDomain)domainForKey:(NSString *)key {
	NSString *searchString = [NSString stringWithFormat:@"|%@|", key];
	for (NSNumber *key in domainKeys) {
		NSString *keys = [domainKeys objectForKey:key];
		if ([keys rangeOfString:searchString].length > 0) {
			return [key intValue];
		}
	}
	return GPGDomain_standard;
}

+ (NSString *)standardizedKey:(NSString *)key {
	if ([key rangeOfString:@"_"].length > 0) {
		return [key stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
	}
	return key;
}

- (void)gpgAgentFlush {
	system("killall -HUP gpg-agent");
}



// Notification handling.
void SystemConfigurationDidChange(SCPreferencesRef prefs, SCPreferencesNotification notificationType, void *info) {
	if (notificationType & kSCPreferencesNotificationApply) {
		[((GPGOptions *)info)->httpProxy release];
		((GPGOptions *)info)->httpProxy = nil;
	}
}
- (void)initSystemConfigurationWatch {
	SCPreferencesContext context = {0, self, nil, nil, nil};
    SCPreferencesRef preferences = SCPreferencesCreate(nil, (CFStringRef)[[NSProcessInfo processInfo] processName], nil);
    SCPreferencesSetCallback(preferences, SystemConfigurationDidChange, &context);
    SCPreferencesScheduleWithRunLoop(preferences, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	CFRelease(preferences);
}	

- (void)valueChanged:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	if (!updating) {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:key, @"key", value, @"value", [NSNumber numberWithInt:domain], @"domain", (domain == GPGDomain_standard && standardDomain) ? standardDomain : nil, @"domainName", nil];
		NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
		[center postNotificationName:GPGOptionsChangedNotification object:identifier userInfo:userInfo options:NSNotificationPostToAllSessions];		
		[self willChangeValueForKey:key];
		[self didChangeValueForKey:key];
	}
}
- (void)valueChangedNotification:(NSNotification *)notification {
	if (self != notification.object && ![identifier isEqualTo:notification.object]) {
		NSDictionary *userInfo = notification.userInfo;
		NSString *key = [userInfo objectForKey:@"key"];
		GPGOptionsDomain domain = [[userInfo objectForKey:@"domain"] intValue];
		
		if (domain == GPGDomain_standard && (!standardDomain || ![[userInfo objectForKey:@"domainName"] isEqualToString:standardDomain])) {
			if (![userInfo objectForKey:@"domainName"] && !standardDomain) {
				// Hack for [NSUserDefaults standardUserDefaults]
				[self willChangeValueForKey:key];
				[self didChangeValueForKey:key];
			}
			return;
		}
		
		BOOL oldAutoSave = self.autoSave;
		self.autoSave = NO;
		updating++;
		[self willChangeValueForKey:key];
		[self setValue:[userInfo objectForKey:@"value"] forKey:key inDomain:domain];
		[self didChangeValueForKey:key];
		updating--;
		self.autoSave = oldAutoSave;
	}
}



// Whatever…
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSString *affectingKey = nil;
	if ([key rangeOfString:@"_"].length > 0) {
		NSCharacterSet *set = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz_"] invertedSet];
		if ([key rangeOfCharacterFromSet:set].length == 0) {
			affectingKey = [self standardizedKey:key];
		}
	}
	if (!affectingKey) {
		if ([key isEqualToString:@"TrustAllKeys"]) {
			affectingKey = @"trust-model";
		} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
			affectingKey = @"default-cache-ttl";
		}
	}
	if (affectingKey) {
		return [NSSet setWithObject:affectingKey];
	} else {
		return [super keyPathsForValuesAffectingValueForKey:key];
	}
}



// Alloc, init etc.
+ (void)initialize {
	environmentPlistDir = [[NSHomeDirectory() stringByAppendingPathComponent:@".MacOSX"] retain];
	environmentPlistPath = [[environmentPlistDir stringByAppendingPathComponent:@"environment.plist"] retain];

	NSString *gpgConfKeys = @"|agent-program|allow-freeform-uid|allow-multiple-messages|allow-multisig-verification|allow-non-selfsigned-uid|allow-secret-key-import|always-trust|armor|"
	"armour|ask-cert-expire|ask-cert-level|ask-sig-expire|attribute-fd|attribute-file|auto-check-trustdb|auto-key-locate|auto-key-retrieve|bzip2-compress-level|bzip2-decompress-lowmem|"
	"cert-digest-algo|cert-notation|cert-policy-url|charset|check-sig|cipher-algo|command-fd|command-file|comment|completes-needed|compress-algo|compress-keys|compress-level|"
	"compress-sigs|compression-algo|debug-quick-random|default-cert-check-level|default-cert-expire|default-cert-level|default-comment|default-key|default-keyserver-url|"
	"default-preference-list|default-recipient|default-recipient-self|default-sig-expire|digest-algo|disable-cipher-algo|disable-dsa2|disable-mdc|disable-pubkey-algo|display-charset|"
	"dry-run|emit-version|enable-dsa2|enable-progress-filter|enable-special-filenames|encrypt-to|escape-from-lines|exec-path|exit-on-status-write-error|expert|export-options|"
	"fast-list-mode|fixed-list-mode|for-your-eyes-only|force-mdc|force-ownertrust|force-v3-sigs|force-v4-certs|gnupg|gpg-agent-info|group|hidden-encrypt-to|hidden-recipient|"
	"honor-http-proxy|ignore-crc-error|ignore-mdc-error|ignore-time-conflict|ignore-valid-from|import-options|interactive|keyid-format|keyring|keyserver|keyserver-options|"
	"limit-card-insert-tries|list-key|list-only|list-options|list-sig|load-extension|local-user|lock-multiple|lock-never|lock-once|logger-fd|logger-file|mangle-dos-filenames|"
	"marginals-needed|max-cert-depth|max-output|merge-only|min-cert-level|multifile|no|no-allow-freeform-uid|no-allow-multiple-messages|no-allow-non-selfsigned-uid|no-armor|no-armour|"
	"no-ask-cert-expire|no-ask-cert-level|no-ask-sig-expire|no-auto-check-trustdb|no-auto-key-locate|no-auto-key-retrieve|no-batch|no-comments|no-default-keyring|no-default-recipient|"
	"no-disable-mdc|no-emit-version|no-encrypt-to|no-escape-from-lines|no-expensive-trust-checks|no-expert|no-for-your-eyes-only|no-force-mdc|no-force-v3-sigs|no-force-v4-certs|"
	"no-greeting|no-groups|no-literal|no-mangle-dos-filenames|no-mdc-warning|no-options|no-permission-warning|no-pgp2|no-pgp6|no-pgp7|no-pgp8|no-random-seed-file|no-require-backsigs|"
	"no-require-cross-certification|no-require-secmem|no-rfc2440-text|no-secmem-warning|no-show-notation|no-show-photos|no-show-policy-url|no-sig-cache|no-sig-create-check|"
	"no-sk-comments|no-skip-hidden-recipients|no-strict|no-textmode|no-throw-keyid|no-throw-keyids|no-tty|no-use-agent|no-use-embedded-filename|no-utf8-strings|no-verbose|no-version|"
	"not-dash-escaped|notation-data|openpgp|output|override-session-key|passphrase|passphrase-fd|passphrase-file|passphrase-repeat|personal-cipher-preferences|personal-cipher-prefs|"
	"personal-compress-preferences|personal-compress-prefs|personal-digest-preferences|personal-digest-prefs|pgp2|pgp6|pgp7|pgp8|photo-viewer|preserve-permissions|primary-keyring|"
	"recipient|remote-user|require-backsigs|require-cross-certification|require-secmem|rfc1991|rfc2440|rfc2440-text|rfc4880|s2k-cipher-algo|s2k-count|s2k-digest-algo|s2k-mode|"
	"secret-keyring|set-filename|set-filesize|set-notation|set-policy-url|show-keyring|show-notation|show-photos|show-policy-url|show-session-key|sig-keyserver-url|sig-notation|"
	"sig-policy-url|sign-with|simple-sk-checksum|sk-comments|skip-hidden-recipients|skip-verify|status-fd|status-file|strict|temp-directory|textmode|throw-keyid|throw-keyids|"
	"trust-model|trustdb-name|trusted-key|try-all-secrets|ungroup|use-agent|use-embedded-filename|user|utf8-strings|verify-options|with-colons|with-fingerprint|with-key-data|"
	"with-sig-check|with-sig-list|yes|";
	NSString *gpgAgentConfKeys = @"|allow-mark-trusted|allow-preset-passphrase|check-passphrase-pattern|csh|daemon|debug-wait|default-cache-ttl|default-cache-ttl-ssh|disable-scdaemon|"
	"enable-passphrase-history|enable-ssh-support|enforce-passphrase-constraints|faked-system-time|ignore-cache-for-signing|keep-display|keep-tty|max-cache-ttl|max-cache-ttl-ssh|"
	"max-passphrase-days|min-passphrase-len|min-passphrase-nonalpha|no-detach|no-grab|no-use-standard-socket|pinentry-program|pinentry-touch-file|scdaemon-program|server|sh|"
	"use-standard-socket|write-env-file|";
	NSString *environmentKeys = @"|GNUPGHOME|GPG_AGENT_INFO|";
	NSString *commonKeys = @"|UseKeychain|ShowPassphrase|PathToGPG|";
	NSString *specialKeys = @"|TrustAllKeys|PassphraseCacheTime|httpProxy|keyservers|";
	
					
	domainKeys = [[NSDictionary alloc] initWithObjectsAndKeys:
				  gpgConfKeys, [NSNumber numberWithInt:GPGDomain_gpgConf], 
				  gpgAgentConfKeys, [NSNumber numberWithInt:GPGDomain_gpgAgentConf],
				  environmentKeys, [NSNumber numberWithInt:GPGDomain_environment],
				  commonKeys, [NSNumber numberWithInt:GPGDomain_common],
				  specialKeys, [NSNumber numberWithInt:GPGDomain_special],				  
				  nil];
}
+ (id)sharedOptions {
    if (!_sharedInstance) {
        _sharedInstance = [[super allocWithZone:nil] init];
    }
    return _sharedInstance;	
}
- (id)init {
	if (!initialized) {
		initialized = YES;
		autoSave = YES;
		identifier = [[NSString alloc] initWithFormat:@"%i%p", [[NSProcessInfo processInfo] processIdentifier], self];
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(valueChangedNotification:) name:GPGOptionsChangedNotification object:nil];
		[self initSystemConfigurationWatch];
	}
	return self;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedOptions] retain];	
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
