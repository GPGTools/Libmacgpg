
@interface GPGConfLine : NSObject {
	NSString *name;
	NSString *value;
	NSMutableArray *subOptions;
	BOOL enabled;
	BOOL isComment;
	BOOL edited;
	NSString *description;
	NSUInteger hash;
}

@property (retain) NSString *name;
@property (retain) NSString *value;
@property (retain) NSArray *subOptions;
@property (readonly) NSUInteger subOptionsCount;
@property BOOL enabled;
@property BOOL isComment;


- (id)initWithLine:(NSString *)line;
+ (id)confLineWithLine:(NSString *)line;
+ (id)confLine;

@end
