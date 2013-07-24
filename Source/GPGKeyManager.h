#import <Foundation/Foundation.h>

@interface GPGKeyManager : NSObject <GPGTaskDelegate> {
	NSSet *_allKeys;
	
	NSMutableSet *_mutableAllKeys;
	NSDictionary *_keysByKeyID;
	NSMutableArray *_attributeLines;
	
	dispatch_once_t _once_keysByKeyID;
	
	BOOL _keysNeedToBeReloaded;
	
	NSLock *_keyLoadingCheckLock;
	dispatch_queue_t _keyLoadingQueue;
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
 fetchSignatures: Also load signatures?
 fetchUserAttributes: Also load user attributes (e.g. PhotoID)
 */
- (void)loadKeys:(NSSet *)keys fetchSignatures:(BOOL)fetchSignatures fetchUserAttributes:(BOOL)fetchUserAttributes;

- (void)loadAllKeys;

@end

/* Register to this notification to received notifications when keys were modified. */
extern NSString * const GPGKeyManagerKeysDidChangeNotification;
