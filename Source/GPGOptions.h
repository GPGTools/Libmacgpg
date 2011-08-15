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

- (NSArray *)allValuesInGPGConfForKey:(NSString *)key;
- (id)valueInGPGConfForKey:(NSString *)key;
- (void)setValueInGPGConf:(id)value forKey:(NSString *)key;
- (NSArray *)allValuesInGPGAgentConfForKey:(NSString *)key;
- (id)valueInGPGAgentConfForKey:(NSString *)key;
- (void)setValueInGPGAgentConf:(id)value forKey:(NSString *)key;

- (void)gpgAgentFlush;

+ (NSString *)standardizedKey:(NSString *)key;
- (GPGOptionsDomain)domainForKey:(NSString *)key;

- (NSString *)gpgHome;


@end
