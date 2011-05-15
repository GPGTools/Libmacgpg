/* Copyright © 2002-2006 Mac GPG Project. */
#import "GPGOptions.h"
#import "GPGConf.h"


@interface GPGOptions (Private)
@property (readonly) NSMutableDictionary *environment;
@property (readonly) NSMutableDictionary *commonDefaults;
@end


@implementation GPGOptions

NSString *_sharedInstance = nil;
NSString *environmentPlistPath;
NSString *environmentPlistDir;
NSString *commonDefaultsDomain = @"org.gpgtools.commmon";
NSDictionary *domainKeys;




- (id)valueForKey:(NSString *)key {
	return [self valueForKey:key inDomain:[self domainForKey:key]];
}
- (void)setValue:(id)value forKey:(NSString *)key {
	[self setValue:value forKey:key inDomain:[self domainForKey:key]];
}

- (id)valueForKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	NSObject *value = nil;
	switch (domain) {
		case GPGDomain_gpgConf:
			value = [self.gpgConf valueForKey:key];
			break;
		case GPGDomain_gpgAgentConf:
			value = [self.gpgAgentConf valueForKey:key];
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
			break;
		default:
			break;
	}
	return value;
}
- (void)setValue:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain {
	
	switch (domain) {
		case GPGDomain_gpgConf:
			[self.gpgConf setValue:value forKey:key];
			break;
		case GPGDomain_gpgAgentConf:
			[self.gpgAgentConf setValue:value forKey:key];
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
			break;
		default:
			break;
	}
}





- (id)specialValueForKey:(NSString *)key {
	if ([key isEqualToString:@"TrustAllKeys"]) {
		return [NSNumber numberWithBool:[[self.gpgConf valueForKey:@"trust-model"] isEqualToString:@"always"]];
	} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
		return [self.gpgAgentConf valueForKey:@"default-cache-ttl"];
	}
	return nil;
}
- (void)setSpecialValue:(id)value forKey:(NSString *)key {
	if ([key isEqualToString:@"TrustAllKeys"]) {
		[self.gpgConf setValue:[value intValue] ? @"always" : nil forKey:@"trust-model"];
	} else if ([key isEqualToString:@"PassphraseCacheTime"]) {
		int cacheTime = [value intValue];
		
		[self.gpgAgentConf setAutoSave:NO];
		[self.gpgAgentConf setValue:[NSNumber numberWithInt:cacheTime] forKey:@"default-cache-ttl"];
		[self.gpgAgentConf setValue:[NSNumber numberWithInt:cacheTime * 12] forKey:@"max-cache-ttl"];		
		[self.gpgAgentConf setAutoSave:YES];
	}
}


- (id)valueInStandardDefaultsForKey:(NSString *)key {
	return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}
- (void)setValueInStandardDefaults:(id)value forKey:(NSString *)key {
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
}


- (id)valueInCommonDefaultsForKey:(NSString *)key {
	return [self.commonDefaults objectForKey:key];
}
- (void)setValueInCommonDefaults:(id)value forKey:(NSString *)key {
    NSObject *oldValue = [self.commonDefaults objectForKey:key];
	if(value != oldValue && ![value isEqual:oldValue]) {
		[self.commonDefaults setObject:value forKey:key];
		[self saveCommonDefaults];
	}
}
- (void)saveCommonDefaults {
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:commonDefaults forName:commonDefaultsDomain];
}
- (void)loadCommonDefaults {
	commonDefaults = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] persistentDomainForName:commonDefaultsDomain]]; 
}
- (NSMutableDictionary *)commonDefaults {
	if (!commonDefaults) {
		[self loadCommonDefaults];
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
	setenv([key UTF8String], [[value description] UTF8String], YES);
	
    NSObject *oldValue = [self.environment objectForKey:key];
	if(value != oldValue && ![value isEqual:oldValue]) {
		[self.environment setObject:value forKey:key];
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
		NSAssert1([fileManager createDirectoryAtPath:environmentPlistDir attributes:nil], @"Unable to create directory '%@'", environmentPlistDir);
	}
	NSAssert1([self.environment writeToFile:environmentPlistPath atomically:YES], @"Unable to write file '%@'", environmentPlistPath);
}
- (void)loadEnvironment {
	environment = [NSMutableDictionary dictionaryWithContentsOfFile:environmentPlistPath];
	if (!environment) {
		environment = [NSMutableDictionary dictionary];
	}
}
- (NSMutableDictionary *)environment {
	if (!environment) {
		[self loadEnvironment];
	}
	return [[environment retain] autorelease];
}



- (GPGConf *)gpgConf {
	if (!gpgConf) {
		gpgConf = [GPGConf confWithPath:[[self gpgHome] stringByAppendingPathComponent:@"gpg.conf"]];
	}
	return [[gpgConf retain] autorelease];
}
- (GPGConf *)gpgAgentConf {
	if (!gpgAgentConf) {
		gpgAgentConf = [GPGConf confWithPath:[[self gpgHome] stringByAppendingPathComponent:@"gpg-agent.conf"]];
	}
	return [[gpgAgentConf retain] autorelease];
}



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


- (NSString *)gpgHome {
	NSString *path = [self valueInEnvironmentForKey:@"GNUPGHOME"];
	if (!path) {
		path = [NSHomeDirectory() stringByAppendingPathComponent:@".gnupg"];
	}
	return path;
}




+ (void)initialize {
	environmentPlistDir = [NSHomeDirectory() stringByAppendingPathComponent:@".MacOSX"];
	environmentPlistPath = [environmentPlistDir stringByAppendingPathComponent:@"environment.plist"];

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
	NSString *environmentKeys = @"|GNUPGHOME|";
	NSString *commonKeys = @"|UseKeychain|ShowPassphrase|PathToGPG|";
	NSString *specialKeys = @"|TrustAllKeys|PassphraseCacheTime|";
	
	domainKeys = [NSDictionary dictionaryWithObjectsAndKeys:
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
- (void)release {
}
- (id)autorelease {
    return self;
}

@end
