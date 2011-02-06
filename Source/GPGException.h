
@class GPGTask;

@interface GPGException : NSException {

}

+ (id)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)gpgTask;
- (id)initWithReason:(NSString *)aReason gpgTask:(GPGTask *)gpgTask;

@end
