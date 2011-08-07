#import "GPGException.h"
#import "GPGTask.h"

@interface GPGException ()
@property (retain) GPGTask *gpgTask;
@property GPGErrorCode errorCode;
@end


@implementation GPGException
@synthesize gpgTask, errorCode;

NSString *GPGExceptionName = @"GPGException";

- (id)initWithName:(NSString *)aName reason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask {
	if (!(self = [super initWithName:aName reason:aReason userInfo:aUserInfo])) {
		return nil;
	}
	
	if (aGPGTask) {
		self.gpgTask = aGPGTask;
		if (aGPGTask.exitcode == GPGErrorCancelled) {
			aErrorCode = GPGErrorCancelled;
		} else if (aErrorCode == 0 && gpgTask.errorCode) {
			aErrorCode = gpgTask.errorCode;
		}
	}
	
	self.errorCode = aErrorCode;
	
	
	return self;
}

- (id)initWithName:(NSString *)aName reason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo {
	return [self initWithName:aName reason:aReason userInfo:aUserInfo errorCode:0 gpgTask:nil];
}

+ (GPGException *)exceptionWithReason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:aUserInfo errorCode:aErrorCode gpgTask:aGPGTask] autorelease];
}
+ (GPGException *)exceptionWithReason:(NSString *)aReason errorCode:(GPGErrorCode)aErrorCode gpgTask:(GPGTask *)aGPGTask {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:nil errorCode:aErrorCode gpgTask:aGPGTask] autorelease];
}
+ (GPGException *)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)aGPGTask {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:nil errorCode:0 gpgTask:aGPGTask] autorelease];
}
+ (GPGException *)exceptionWithReason:(NSString *)aReason errorCode:(GPGErrorCode)aErrorCode {
	return [[[self alloc] initWithName:GPGExceptionName reason:aReason userInfo:nil errorCode:aErrorCode gpgTask:nil] autorelease];
}

@end

