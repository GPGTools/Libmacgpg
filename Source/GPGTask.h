#import <Cocoa/Cocoa.h>

@class GPGTask;

@protocol GPGTaskDelegate
@optional
//Should return NSData or NSString, it is passed to GPG.
- (id)gpgTask:(GPGTask *)gpgTask statusCode:(NSInteger)status prompt:(NSString *)prompt;


- (void)gpgTaskWillStart:(GPGTask *)gpgTask;
- (void)gpgTaskDidTerminated:(GPGTask *)gpgTask;


@end


@interface GPGTask : NSObject {
	NSString *gpgPath;
	NSMutableArray *arguments;
	BOOL batchMode;
	NSObject <GPGTaskDelegate> *delegate;
	NSDictionary *userInfo;
	NSInteger exitcode;
	int errorCode;
	BOOL getAttributeData;
	
	NSMutableArray *inDatas;
	NSMutableArray *inFileDescriptors;
	
	NSData *outData;
	NSData *errData;
	NSData *statusData;
	NSData *attributeData;
	
	NSString *outText;
	NSString *errText;
	NSString *statusText;
	
	
	NSDictionary *lastUserIDHint;
	NSDictionary *lastNeedPassphrase;
	
	char passphraseStatus;
	
	int cmdFileDescriptor;
	
	pid_t childPID;
	BOOL canceled;
	BOOL isRunning;
}

@property (readonly) BOOL canceled;
@property (readonly) BOOL isRunning;
@property BOOL batchMode;
@property BOOL getAttributeData;
@property (assign) NSObject <GPGTaskDelegate> *delegate;
@property (retain) NSDictionary *userInfo;
@property (readonly) NSInteger exitcode;
@property (readonly) int errorCode;
@property (retain) NSString *gpgPath;
@property (readonly) NSData *outData;
@property (readonly) NSData *errData;
@property (readonly) NSData *statusData;
@property (readonly) NSData *attributeData;
@property (readonly) NSString *outText;
@property (readonly) NSString *errText;
@property (readonly) NSString *statusText;
@property (readonly) NSArray *arguments;
@property (retain) NSDictionary *lastUserIDHint;
@property (retain) NSDictionary *lastNeedPassphrase;


+ (NSString *)gpgAgentSocket;
+ (NSString *)pinentryPath;
+ (NSString *)findExecutableWithName:(NSString *)executable;
+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths;
+ (NSString *)nameOfStatusCode:(NSInteger)statusCode;

- (void)addArgument:(NSString *)argument;
- (void)addArguments:(NSArray *)args;

- (NSInteger)start;

- (void)cancel;


- (void)addInData:(NSData *)data;
- (void)addInText:(NSString *)string;



+ (id)gpgTaskWithArguments:(NSArray *)args batchMode:(BOOL)batch;
+ (id)gpgTaskWithArguments:(NSArray *)args;
+ (id)gpgTaskWithArgument:(NSString *)arg;
+ (id)gpgTask;


- (id)initWithArguments:(NSArray *)args batchMode:(BOOL)batch;
- (id)initWithArguments:(NSArray *)args;
- (id)initWithArgument:(NSString *)arg;




@end



