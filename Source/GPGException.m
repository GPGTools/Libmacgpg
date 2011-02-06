#import "GPGException.h"
#import "GPGTask.h"

@implementation GPGException


+ (id)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)gpgTask {
	return [[self alloc] initWithReason:aReason gpgTask:gpgTask]; 
}

- (id)initWithReason:(NSString *)aReason gpgTask:(GPGTask *)gpgTask {
	return [self initWithName:@"GPGTaskException" reason:aReason userInfo:[NSDictionary dictionaryWithObject:gpgTask forKey:@"gpgTask"]]; 
}



@end
