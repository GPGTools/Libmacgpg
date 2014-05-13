/*
 Copyright © Roman Zechmeister und Lukas Pitschl (@lukele), 2014
 
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

#import <Libmacgpg/GPGGlobals.h>

@class GPGKey, NSImage;


@protocol GPGUserIDProtocol <NSObject>
@property (copy, nonatomic, readonly) NSString *userIDDescription;
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *email;
@property (copy, nonatomic, readonly) NSString *comment;
@property (copy, nonatomic, readonly) NSImage *image;
@end


@interface GPGUserID : NSObject <GPGUserIDProtocol> {}

- (instancetype)init;
- (instancetype)initWithUserIDDescription:(NSString *)userIDDescription;

@property (copy, nonatomic, readonly) NSString *userIDDescription;
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *email;
@property (copy, nonatomic, readonly) NSString *comment;
@property (copy, nonatomic, readonly) NSString *hashID;
@property (copy, nonatomic, readonly) NSImage *image;
@property (copy, nonatomic, readonly) NSDate *creationDate;
@property (copy, nonatomic, readonly) NSDate *expirationDate;
@property (nonatomic, readonly) GPGValidity validity;

@property (copy, nonatomic, readonly) NSArray *signatures;
@property (unsafe_unretained, nonatomic, readonly) GPGKey *primaryKey;

@end

