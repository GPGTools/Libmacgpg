#import <Foundation/Foundation.h>


@interface GPGKeyManager : NSObject <GPGTaskDelegate> {
	NSSet *_allKeys;
	NSMutableSet *_mutableAllKeys;
	NSDictionary *_keysByKeyID;
	NSMutableArray *_attributeLines;
	
	dispatch_once_t _once_keysByKeyID;
}
@property (nonatomic, readonly) NSSet *allKeys;
@property (nonatomic, readonly) NSDictionary *keysByKeyID;


/*
 GPGKeyManager is a singleton.
 */
+ (GPGKeyManager *)sharedInstance;

/*
 Load the specified keys from gpg, pass nil to load all.
 keys: A set of GPGKeys.
 sigs: Also load signatures?
 uat: Also load user attributes (e.g. PhotoID)
 */
- (void)loadKeys:(NSSet *)keys sigs:(BOOL)sigs uat:(BOOL)uat;

- (void)loadAllKeys;


@end
