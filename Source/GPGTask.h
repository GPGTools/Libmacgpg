/*
 Copyright © Roman Zechmeister, 2013
 
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
#import "GPGTaskHelper.h"

@class GPGTask;
@class GPGTaskHelper;
@class GPGStream;

@protocol GPGTaskDelegate
@optional
//Should return NSData or NSString, it is passed to GPG.
- (id)gpgTask:(GPGTask *)gpgTask statusCode:(NSInteger)status prompt:(NSString *)prompt;

- (void)gpgTask:(GPGTask *)gpgTask progressed:(NSInteger)progressed total:(NSInteger)total;
- (void)gpgTaskWillStart:(GPGTask *)gpgTask;
- (void)gpgTaskDidTerminate:(GPGTask *)gpgTask;


@end


@interface GPGTask : NSObject {
	NSMutableArray *arguments;
	BOOL batchMode;
	NSObject <GPGTaskDelegate> *delegate;
	NSDictionary *userInfo;
	NSInteger exitcode;
	int errorCode;
	NSMutableArray *errorCodes;
	BOOL getAttributeData;
	
	NSMutableArray *inDatas;
	
    GPGTaskHelper *taskHelper;
    
    GPGStream *outStream;
	NSData *errData;
	NSData *statusData;
	NSData *attributeData;
	
	NSString *outText;
	NSString *errText;
	NSString *statusText;
	
	BOOL cancelled;
	BOOL isRunning;
	
	BOOL progressInfo;
	
	NSMutableDictionary *statusDict;
	NSUInteger timeout;
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
// if not set before starting, GPGTask will use a GPGMemoryStream
@property (retain) GPGStream *outStream;
@property (readonly, retain) NSData *errData;
@property (readonly, retain) NSData *statusData;
@property (readonly, retain) NSData *attributeData;
@property (readonly) NSString *outText;
@property (readonly) NSString *errText;
@property (readonly) NSString *statusText;
@property (readonly) NSArray *arguments;
@property (readonly) GPGTaskHelper *taskHelper; 
@property (assign, nonatomic) NSUInteger timeout;

+ (NSString *)gpgAgentSocket;
+ (NSString *)nameOfStatusCode:(NSInteger)statusCode;

- (void)addArgument:(NSString *)argument;
- (void)addArguments:(NSArray *)args;

- (NSInteger)start;

- (NSData *)outData;
- (void)addInput:(GPGStream *)stream;
- (void)addInData:(NSData *)data;
- (void)addInText:(NSString *)string;

- (void)cancel;

+ (id)gpgTaskWithArguments:(NSArray *)args batchMode:(BOOL)batch;
+ (id)gpgTaskWithArguments:(NSArray *)args;
+ (id)gpgTaskWithArgument:(NSString *)arg;
+ (id)gpgTask;


- (id)initWithArguments:(NSArray *)args batchMode:(BOOL)batch;
- (id)initWithArguments:(NSArray *)args;
- (id)initWithArgument:(NSString *)arg;

- (void)logDataContent:(NSData *)data message:(NSString *)message;

@end
