#import "GPGConf.h"
#import "GPGConfLine.h"
#import "GPGGlobals.h"


@implementation GPGConf
@synthesize path, encoding, autoSave;


+ (id)confWithPath:(NSString *)aPath {
	return [[[[self class] alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString *)aPath {
	if ((self = [super init]) == nil) {
		return nil;
	}
	autoSave = YES;
	self.path = aPath;
	[self loadConfig];
	
	return self;
}





- (id)valueForKey:(NSString *)key {
	NSArray *options = [self enabledOptionsWithName:key];
	NSUInteger count = [options count];
	GPGConfLine *option;
	NSObject *returnValue;
	
	
	if (count == 0) {
		returnValue = nil;
	} else if (count == 1) {
		option = [options objectAtIndex:0];
		
		if ([option subOptionsCount] > 0) {
			returnValue = [option value];
		} else {
			returnValue = [NSNumber numberWithBool:![[option name] hasPrefix:@"no-"]];
		}
	} else {
		NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:count];
		for (option in options) {
			NSString *value = [option value];
			if ([value length] > 0) {
				[returnArray addObject:value];
			}
		}
		returnValue = returnArray;
	}

	return returnValue;
}
- (void)setValue:(id)value forKey:(NSString *)key {
	//NSNumber: YES="key", NO="no-key"
	//NSString: "key value"
	//NSArray: 'for suboption in value {"key suboption"}'
	//nil: Remove the option.
	
	NSAssert([key length] > 0, @"invalid key");
	
	if (!value) {
		[self removeOptionWithName:key];
	} else if ([value isKindOfClass:[NSNumber class]]) {
		if ([key hasPrefix:@"no-"]) {
			NSAssert([key length] > 3, @"invalid key");
			key = [key substringFromIndex:3];
		}
		if ([value boolValue] == NO) {
			key = [@"no-" stringByAppendingString:key];
		}
		[self addOptionWithName:key];
	} else if ([value isKindOfClass:[NSString class]]) {
		[self setValue:value forOptionWithName:key];
	} else if ([value isKindOfClass:[NSArray class]]) {
		[self setAllOptionsWithName:key values:value];
	} else {
		NSAssert1([key length] > 0, @"invalid value: %@", value);
	}

}





- (void)loadConfig {
	NSStringEncoding fileEncoding;
	NSError *error = nil;
	NSString *content = [NSString stringWithContentsOfFile:path usedEncoding:&fileEncoding error:&error];
	if (!content) {
		if ([error code] == 260) {
			content = @"";
			fileEncoding = NSUTF8StringEncoding;
		} else {
			@throw [NSException exceptionWithName:[error domain]  reason:[error localizedFailureReason] userInfo:[error userInfo]];
		}
	}
	
	self.encoding = fileEncoding;
	NSArray *lines = [content componentsSeparatedByString:@"\n"];
	confLines = [[NSMutableArray alloc] initWithCapacity:lines.count];
	
	for (NSString *line in lines) {
		GPGConfLine *confLine = [GPGConfLine confLineWithLine:line];
		if (confLine) {
			[confLines addObject:confLine];
		} else {
			@throw gpgException(GPGException, @"Can not load the config", GPGErrorGeneralError);
		}
	}
}
- (void)saveConfig {
	NSString *content = [confLines componentsJoinedByString:@"\n"];
	NSError *error = nil;	
	if (![content writeToFile:path atomically:YES encoding:encoding error:&error]) {
		//TODO: Better exception handling.
		@throw [NSException exceptionWithName:[error domain]  reason:[error localizedFailureReason] userInfo:[error userInfo]];
	}
}
- (void)autoSaveConfig {
	if (autoSave) {
		[self saveConfig];
	}
}


- (NSArray *)optionsWithName:(NSString *)name {
	return [self optionsWithName:name state:-1];
}
- (NSArray *)enabledOptionsWithName:(NSString *)name {
	return [self optionsWithName:name state:1];
}
- (NSArray *)disabledOptionsWithName:(NSString *)name {
	return [self optionsWithName:name state:0];
}
- (NSArray *)optionsWithName:(NSString *)name state:(int)state {
	NSPredicate *predicate; 
	switch (state) {
		case 0: //Disabled only.
			predicate = [NSPredicate predicateWithFormat:@"(name = %@) AND (enabled = NO) AND (comment = NO)", name];
			break;
		case 1: //Enabled only.
			predicate = [NSPredicate predicateWithFormat:@"(name = %@) AND (enabled = YES)", name];
			break;
		default:
			predicate = [NSPredicate predicateWithFormat:@"name = %@", name];
			break;
	}
	return [confLines filteredArrayUsingPredicate:predicate];
}



- (void)addOptionWithName:(NSString *)name { //For simple options without suboptions.
	NSString *antiName;
	if ([name hasPrefix:@"no-"]) {
		NSAssert([name length] > 3, @"invalid name");
		antiName = [name substringFromIndex:3];
	} else {
		antiName = [@"no-" stringByAppendingString:name];
	}
	
	GPGConfLine *line;
	NSUInteger index;
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSUInteger count = [confLines count];
	
	NSRange range;
	range.location = 0;
	range.length = count;
	
	
	while ((index = [confLines indexOfObject:antiName inRange:range]) != NSNotFound) {
		if ([[confLines objectAtIndex:index] enabled]) {
			[indexSet addIndex:index];
		}
		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	[confLines removeObjectsAtIndexes:indexSet];
	
	
	index = [confLines indexOfObject:name];
	if (index == NSNotFound) {
		line = [GPGConfLine confLine];
		line.name = name;
		[confLines addObject:line];
	} else {
		line = [confLines objectAtIndex:index];
		line.enabled = YES;
		line.value = @"";
	}
	[self autoSaveConfig];
}
- (void)removeOptionWithName:(NSString *)name { //For simple options without suboptions.
	NSUInteger index;
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSUInteger count = [confLines count];
	
	NSRange range;
	range.location = 0;
	range.length = count;

	while ((index = [confLines indexOfObject:name inRange:range]) != NSNotFound) {
		if ([[confLines objectAtIndex:index] enabled]) {
			[indexSet addIndex:index];
		}
		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	[confLines removeObjectsAtIndexes:indexSet];
	[self autoSaveConfig];
}
- (int)stateOfOptionWithName:(NSString *)name { //For simple options without suboptions.
	// -1 = No option found; 0 = Disabled; 1 = Enabled
	int state = -1;
	NSUInteger index;
	NSUInteger count = [confLines count];
	
	NSRange range;
	range.location = 0;
	range.length = count;
	
	
	while ((index = [confLines indexOfObject:name inRange:range]) != NSNotFound) {
		if ([[confLines objectAtIndex:index] enabled]) {
			state = 1;
			break;
		} else {
			state = 0;
		}

		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	
	return state;
}



- (void)setValue:(NSString *)value forOptionWithName:(NSString *)name { //For one-line options. (e.g. list-options)
	GPGConfLine *line;
	NSUInteger index, foundIndex = NSNotFound;
	BOOL found = NO, enabled;
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSUInteger count = [confLines count];
	
	NSRange range;
	range.location = 0;
	range.length = count;
	
	
	while ((index = [confLines indexOfObject:name inRange:range]) != NSNotFound) {
		enabled = [[confLines objectAtIndex:index] enabled];
		
		if (!found && (foundIndex == NSNotFound || enabled)) {
			foundIndex = index;
			found = enabled;
		} else {
			[indexSet addIndex:index];
		}
		
		
		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	
	if (foundIndex != NSNotFound) {
		line = [confLines objectAtIndex:foundIndex];
		line.enabled = YES;
		line.value = value;
	} else {
		line = [GPGConfLine confLine];
		line.name = name;
		line.value = value;
		[confLines addObject:line];
	}
	[confLines removeObjectsAtIndexes:indexSet];
	
	[self autoSaveConfig];
}


- (void)addOptionWithName:(NSString *)name andValue:(NSString *)value { //For options with only one suboption.
	GPGConfLine *line, *disabledLine = nil;
	NSUInteger index;
	NSUInteger count = [confLines count];
	
	NSRange range;
	range.location = 0;
	range.length = count;
	
	
	while ((index = [confLines indexOfObject:name inRange:range]) != NSNotFound) {
		line = [confLines objectAtIndex:index];
		
		if (line.subOptionsCount == 1 && [value isEqualToString:[line.subOptions objectAtIndex:0]]) {
			if (line.enabled) {
				return;
			} else {
				disabledLine = line;
				break;
			}
		}
		
		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	
	if (disabledLine) {
		disabledLine.enabled = YES;
	} else {
		line = [GPGConfLine confLine];
		line.name = name;
		line.value = value;
		[confLines addObject:line];
	}
	[self autoSaveConfig];
}
- (void)removeOptionWithName:(NSString *)name andValue:(NSString *)value { //For options with only one suboption.
	GPGConfLine *line;
	NSUInteger index;
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSUInteger count = [confLines count];
	
	NSRange range;
	range.location = 0;
	range.length = count;
	
	while ((index = [confLines indexOfObject:name inRange:range]) != NSNotFound) {
		line = [confLines objectAtIndex:index];
		if (line.enabled && line.subOptionsCount == 1 && [value isEqualToString:[line.subOptions objectAtIndex:0]]) {
			[indexSet addIndex:index];
		}
		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	[confLines removeObjectsAtIndexes:indexSet];
	[self autoSaveConfig];
}


- (void)setAllOptionsWithName:(NSString *)name values:(NSArray *)values {
	NSMutableIndexSet *indexesToKeep = [NSMutableIndexSet indexSet];
	NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
	NSMutableArray *linesToDo = [NSMutableArray arrayWithCapacity:[values count]];
	NSUInteger index;
	GPGConfLine *line;
	NSRange range;
	NSUInteger count = [confLines count];
	
	for (NSString *value in values) {
		line = [GPGConfLine confLine];
		line.name = name;
		line.value = value;
		
		if ((index = [confLines indexOfObject:line]) != NSNotFound) {
			[indexesToKeep addIndex:index];
		} else {
			[linesToDo addObject:line];
		}
	}
	
	
	while ((index = [confLines indexOfObject:name inRange:range]) != NSNotFound) {
		if (![indexesToKeep containsIndex:index]) {
			[indexesToRemove addIndex:index];
		}
		
		range.location = index + 1;
		if (range.location >= count) {
			break;
		}
		range.length = count - range.location - 1;
	}
	
	
	
	for (line in linesToDo) {
		if ((index = [indexesToRemove firstIndex]) != NSNotFound) {
			[confLines replaceObjectAtIndex:index withObject:line];
			[indexesToKeep addIndex:index];
			[indexesToRemove removeIndex:index];
		} else {
			[confLines addObject:line];
		}
	}
	
	if ([indexesToRemove firstIndex] != NSNotFound) {
		[confLines removeObjectsAtIndexes:indexesToRemove];
	}
}






- (id)init {
	return [self initWithPath:nil];
}

- (void)dealloc {
	self.path = nil;
	[confLines release];
	[super dealloc];
}


@end
