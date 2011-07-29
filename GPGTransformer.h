#import <Cocoa/Cocoa.h>


@interface GPGKeyAlgorithmNameTransformer : NSValueTransformer {}
@end

@interface GPGKeyStatusDescriptionTransformer : NSValueTransformer {}
@end

@interface SplitFormatter : NSFormatter {
	NSInteger blockSize;
}
@property NSInteger blockSize;
@end
