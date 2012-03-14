/*
 Copyright © Roman Zechmeister, 2011
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
*/

#import <Cocoa/Cocoa.h>
#import "LPXTTask.h"

@class GPGTask;

@protocol GPGTaskDelegate
@optional
//Should return NSData or NSString, it is passed to GPG.
- (id)gpgTask:(GPGTask *)gpgTask statusCode:(NSInteger)status prompt:(NSString *)prompt;

- (void)gpgTask:(GPGTask *)gpgTask progressed:(NSInteger)progressed total:(NSInteger)total;
- (void)gpgTaskWillStart:(GPGTask *)gpgTask;
- (void)gpgTaskDidTerminate:(GPGTask *)gpgTask;


@end


@interface GPGTask : NSObject {
	NSString *gpgPath;
	NSMutableArray *arguments;
	BOOL batchMode;
	NSObject <GPGTaskDelegate> *delegate;
	NSDictionary *userInfo;
	NSInteger exitcode;
	int errorCode;
	NSMutableArray *errorCodes;
	BOOL getAttributeData;
	BOOL inputDataWritten;
	
    LPXTTask *gpgTask;
    
	NSMutableArray *inDatas;
	
	NSData *outData;
	NSData *errData;
	NSData *statusData;
	NSData *attributeData;
	
	NSString *outText;
	NSString *errText;
	NSString *statusText;
	NSPipe *cmdPipe;
    
	NSDictionary *lastUserIDHint;
	NSDictionary *lastNeedPassphrase;
	
	char passphraseStatus;
	
	pid_t childPID;
	BOOL cancelled;
	BOOL isRunning;
	
	dispatch_group_t collectorGroup;
	dispatch_queue_t queue;
	NSInteger inDataLength;
	NSInteger progressedLength;
	NSMutableDictionary *progressedLengths;
	BOOL progressInfo;
	
	NSMutableDictionary *statusDict;
}

@property (readonly) BOOL cancelled;
@property (readonly) BOOL isRunning;
@property (readonly) NSDictionary *statusDict;
@property BOOL progressInfo;
@property BOOL batchMode;
@property BOOL getAttributeData;
@property (assign) NSObject <GPGTaskDelegate> *delegate;
@property (retain) NSDictionary *userInfo;
@property (readonly) NSInteger exitcode;
@property (readonly) int errorCode;
@property (retain) NSString *gpgPath;
@property (readonly, retain) NSData *outData;
@property (readonly, retain) NSData *errData;
@property (readonly, retain) NSData *statusData;
@property (readonly, retain) NSData *attributeData;
@property (readonly) NSString *outText;
@property (readonly) NSString *errText;
@property (readonly) NSString *statusText;
@property (readonly) NSArray *arguments;
@property (retain) NSDictionary *lastUserIDHint;
@property (retain) NSDictionary *lastNeedPassphrase;
@property (readonly) LPXTTask *gpgTask;


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

- (void)processStatusLine:(NSString *)line;
- (void)logDataContent:(NSData *)data message:(NSString *)message;

@end
