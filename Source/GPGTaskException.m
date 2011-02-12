#import "GPGTaskException.h"
#import "GPGTask.h"

@implementation GPGTaskException
@synthesize gpgTask;

+ (id)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)task {
	return [[self alloc] initWithReason:aReason gpgTask:task]; 
}

- (id)initWithReason:(NSString *)aReason gpgTask:(GPGTask *)task {
	self = [self initWithName:@"GPGTaskException" reason:aReason userInfo:nil];
	if (self) {
		gpgTask = [task retain];
	}
	return self;
}



@end
