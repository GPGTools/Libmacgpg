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
*/

#import <Cocoa/Cocoa.h>

@class GPGConf;

typedef enum {
	GPGDomain_standard,
	GPGDomain_common,
	GPGDomain_environment,
	GPGDomain_gpgConf,
	GPGDomain_gpgAgentConf,
	GPGDomain_special //special is not a real domain.
} GPGOptionsDomain;



@interface GPGOptions : NSObject {
	BOOL initialized;
	NSMutableDictionary *environment;
	NSMutableDictionary *standardDefaults;
	NSMutableDictionary *commonDefaults;
	NSString *httpProxy;
	BOOL autoSave;
	NSString *standardDomain;
	
	
	GPGConf *gpgConf;
	GPGConf *gpgAgentConf;
	NSString *identifier;
	NSUInteger updating;
}

@property (readonly) NSString *httpProxy;
@property (readonly) NSString *gpgHome;
@property (readonly) NSArray *keyservers;
@property BOOL autoSave;
@property (retain) NSString *standardDomain;
@property (readonly) BOOL debugLog;

+ (BOOL)debugLog;

+ (id)sharedOptions;
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;

- (id)valueForKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;
- (void)setValue:(id)value forKey:(NSString *)key inDomain:(GPGOptionsDomain)domain;


- (void)setInteger:(NSInteger) value forKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (void)setBool:(BOOL) value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (void)setFloat:(float)value forKey:(NSString *)key;
- (float)floatForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;


- (id)valueInStandardDefaultsForKey:(NSString *)key;
- (void)setValueInStandardDefaults:(id)value forKey:(NSString *)key;
- (void)saveStandardDefaults;

- (id)valueInCommonDefaultsForKey:(NSString *)key;
- (void)setValueInCommonDefaults:(id)value forKey:(NSString *)key;
- (void)saveCommonDefaults;

- (id)valueInEnvironmentForKey:(NSString *)key;
- (void)setValueInEnvironment:(id)value forKey:(NSString *)key;
- (void)saveEnvironment;

- (id)specialValueForKey:(NSString *)key;
- (void)setSpecialValue:(id)value forKey:(NSString *)key;

- (id)valueInGPGConfForKey:(NSString *)key;
- (void)setValueInGPGConf:(id)value forKey:(NSString *)key;

- (id)valueInGPGAgentConfForKey:(NSString *)key;
- (void)setValueInGPGAgentConf:(id)value forKey:(NSString *)key;


- (void)gpgAgentFlush;
- (void)gpgAgentTerminate;

+ (NSString *)standardizedKey:(NSString *)key;
- (GPGOptionsDomain)domainForKey:(NSString *)key;
- (BOOL) isKnownKey:(NSString *)key domainForKey:(GPGOptionsDomain)domain;



@end
