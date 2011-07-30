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

#import "GPGConfLine.h"


@implementation GPGConfLine




- (NSString *)description {
	if (edited) {
		description = [[NSString alloc] initWithFormat:[self.value length] > 0 ? @"%s%s%@ %@" : @"%s%s%@", self.enabled ? "" : "#", self.isComment ? " " : "", self.name, self.value];
	}
	return [[description retain] autorelease];
}
- (NSUInteger)hash {
	if (edited || !hash) {
		hash = [self.name hash];
	}
	return hash;
}
- (BOOL)isEqual:(id)anObject {
	if ([anObject isKindOfClass:[self class]]) {
		return [self.description isEqualToString:[anObject description]];
	} else {
		return [self.name isEqualToString:[anObject description]];
	}
}





- (NSString *)name {
	return [[name retain] autorelease];
}
- (void)setName:(NSString *)newValue {
	if (newValue != name) {
		edited = YES;
		[name release];
		name = [newValue retain];
	}
}
- (BOOL)enabled {
	return enabled;
}
- (void)setEnabled:(BOOL)newValue {
	if (newValue != enabled) {
		edited = YES;
		enabled = newValue;
	}
}
- (BOOL)isComment {
	return isComment;
}
- (void)setIsComment:(BOOL)newValue {
	if (newValue != isComment) {
		edited = YES;
		isComment = newValue;
	}
}
- (NSString *)value {
	if (!value) {
		value = [[subOptions componentsJoinedByString:@" "] retain];
	}
	return [[value retain] autorelease];
}
- (void)setValue:(NSString *)newValue {
	if ([newValue hasPrefix:@"\""] && [newValue hasSuffix:@"\""]) {
		newValue = [newValue substringWithRange:NSMakeRange(1, [newValue length] - 2)];
	}
	
	self.subOptions = [newValue componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,"]];
}
- (NSArray *)subOptions {
	return [[subOptions retain] autorelease];
}
- (void)setSubOptions:(NSArray *)newOptions {
	if (newOptions != subOptions) {
		edited = YES;
		[value release];
		value = nil;
		[subOptions removeAllObjects];
		for (NSString *option in newOptions) {
			if ([option length] > 0) {
				[subOptions addObject:option];
			}
		}
	}
}
- (NSUInteger)subOptionsCount {
	return subOptions.count;
}



+ (id)confLine {
	return [[[self alloc] initWithLine:nil] autorelease];
}

+ (id)confLineWithLine:(NSString *)line {
	return [[[self alloc] initWithLine:line] autorelease];
}

- (id)initWithLine:(NSString *)line {
	if ((self = [super init]) == nil) {
		return nil;
	}
	self.name = @"";
	subOptions = [[NSMutableArray alloc] init];
	
	NSRange range;
	NSCharacterSet *whitespaces = [NSCharacterSet whitespaceCharacterSet];
	line = [line stringByTrimmingCharactersInSet:whitespaces];
	NSUInteger length = [line length];
	
	
	
	if ([line hasPrefix:@"#"]) {		
		if (length == 1) {
			self.isComment = YES;
			return self;
		} else if ([whitespaces characterIsMember:[line characterAtIndex:1]]) {
			self.isComment = YES;
			self.name = [line substringFromIndex:2];
			return self;
		}
		line = [[line substringFromIndex:1] stringByTrimmingCharactersInSet:whitespaces];
		length = [line length];
	} else {
		self.enabled = YES;
	}
	
	if (length == 0) {
		return self;
	}
	
	range = [line rangeOfCharacterFromSet:whitespaces];
	if (range.length > 0) {
		self.name = [line substringToIndex:range.location];
		self.value = [line substringFromIndex:range.location + 1];
	} else {
		self.name = line;
	}	
	
	return self;
}


- (id)init {
	return [self initWithLine:nil];
}

- (void)dealloc {
	self.name = nil;
	[value release];
	[subOptions release];
	[description release];
	[super dealloc];
}
	
@end
