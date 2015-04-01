

@interface GPGKeyManager : NSObject {
	NSSet *_allKeys;
	NSSet *_allKeysAndSubkeys;
	
	NSMutableSet *_mutableAllKeys;
	NSDictionary *_keysByKeyID;
	
	dispatch_once_t _once_keysByKeyID;
	
	BOOL _keysNeedToBeReloaded;
	
	NSLock *_keyLoadingCheckLock;
	dispatch_queue_t _keyLoadingQueue;
	dispatch_queue_t _keyChangeNotificationQueue;
	
	NSSet *_secretKeys;
	
	dispatch_queue_t _completionQueue;
	
	//For loadKeys
	
	NSSet *_secKeyFingerprints;
	NSDictionary *_secKeyInfos;
	NSArray *_keyLines;
	NSData *_attributeData;
	NSMutableDictionary *_attributeInfos; // A dict of arrays of dict with: location, length, type, index, count.
	NSUInteger _attributeDataLocation;
	BOOL _fetchUserAttributes;
	BOOL _fetchSignatures;
	BOOL _allowWeakDigestAlgos;

	
	dispatch_semaphore_t _allKeysAndSubkeysOnce;
}
@property (nonatomic) BOOL allowWeakDigestAlgos;

@property (nonatomic, readonly) NSSet *allKeys;
@property (nonatomic, readonly) NSSet *allKeysAndSubkeys;
@property (nonatomic, readonly) NSDictionary *keysByKeyID;

/* Subset of allKeys including only secret keys. */
@property (nonatomic, readonly) NSSet *secretKeys;

/* retain is not allow on dispatch_queues, but the implementation will
 * retain this queue.
 * If no queue is set the main queue will be used.
 */
@property (nonatomic, assign) dispatch_queue_t completionQueue;

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

/* Load signatures for the specified keys.
 * completionHandler will be called once the signatures are loaded, and pass
 * the loaded keys as argument.
 */
- (void)loadSignaturesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler;

/* Load attributes (photo) for the specified keys.
 * completionHandler will be called once the attributes are loaded, and pass
 * the loaded keys as argument.
 */
- (void)loadAttributesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler;

/* Load both signatures and attributes for the specified keys.
 * completionHandler will be called once the signatures and attributes are loaded, and pass
 * the loaded keys as argument.
 */
- (void)loadSignaturesAndAttributesForKeys:(NSSet *)keys completionHandler:(void(^)(NSSet *))completionHandler;

@end

/* Register to this notification to received notifications when keys were modified. */
extern NSString * const GPGKeyManagerKeysDidChangeNotification;
