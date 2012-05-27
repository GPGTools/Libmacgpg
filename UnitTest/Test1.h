#import <SenTestingKit/SenTestingKit.h>

@class GPGController;

@interface Test1 : SenTestCase {
	GPGController *gpgc;
	NSString *tempDir;
    NSUInteger confTouches;
}
- (void)logDataContent:(NSData *)data message:(NSString *)message;
@end
