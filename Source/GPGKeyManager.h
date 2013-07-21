#import <Foundation/Foundation.h>


@interface GPGKeyManager : NSObject <GPGTaskDelegate> {
	NSSet *allKeys;
	NSMutableSet *mutableAllKeys;
	NSMutableArray *attributeLines;
}
@property (readonly) NSSet *allKeys;

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
