#import <Foundation/Foundation.h>
#import <Libmacgpg/GPGGlobals.h>

@class GPGTask;

@interface GPGException : NSException {
	GPGTask *gpgTask;
	GPGErrorCode errorCode;
}

@property (readonly, retain) GPGTask *gpgTask;
@property (readonly) GPGErrorCode errorCode;

extern NSString *GPGExceptionName;

- (id)initWithName:(NSString *)aName reason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask;

+ (GPGException *)exceptionWithReason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask;
+ (GPGException *)exceptionWithReason:(NSString *)aReason errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask;
+ (GPGException *)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)aGPGTask;
+ (GPGException *)exceptionWithReason:(NSString *)aReason errorCode:(GPGErrorCode)aErrorCode;

@end
