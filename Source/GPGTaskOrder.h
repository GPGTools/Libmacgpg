#import <Cocoa/Cocoa.h>


enum {
	NoDefaultAnswer = 0,
	YesToAll,
	NoToAll
};
typedef uint8_t BoolAnswer;

@interface GPGTaskOrder : NSObject {
	uint8_t defaultBoolAnswer;
	
	NSMutableArray *items;
	NSUInteger index;
}

@property uint8_t defaultBoolAnswer;


- (void)addCmd:(NSString *)cmd prompt:(NSString *)prompt;
- (void)addInt:(int)cmd prompt:(NSString *)prompt;
- (void)addOptionalCmd:(NSString *)cmd prompt:(NSString *)prompt;
- (void)addOptionalInt:(int)cmd prompt:(NSString *)prompt;
- (void)addCmd:(NSString *)cmd prompt:(NSString *)prompt optional:(BOOL)optional;
- (void)addInt:(int)cmd prompt:(NSString *)prompt optional:(BOOL)optional;
- (NSString *)cmdForPrompt:(NSString *)prompt statusCode:(NSInteger)statusCode;

+ (id)order;
+ (id)orderWithYesToAll;
+ (id)orderWithNoToAll;
- (id)initWithYesToAll;
- (id)initWithNoToAll;

@end
