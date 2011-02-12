
@class GPGTask;

@interface GPGTaskException : NSException {
	GPGTask *gpgTask;
}

@property (readonly) GPGTask *gpgTask;

+ (id)exceptionWithReason:(NSString *)aReason gpgTask:(GPGTask *)gpgTask;
- (id)initWithReason:(NSString *)aReason gpgTask:(GPGTask *)gpgTask;

@end
