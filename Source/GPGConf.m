#import "GPGConf.h"



@interface GPGConf ()
@property (retain) NSString *path;
@end

@implementation GPGConf
@synthesize path;

- (id)valueForKey:(NSString *)key {
	return [config objectForKey:key];
}
- (void)setValue:(id)value forKey:(NSString *)key {
	if (value) {
		if ([key isEqualToString:@"group"]) {
			if (![value isKindOfClass:[NSDictionary class]]) {
				NSLog(@"GPGConf setValue:forKey: Illegal class for key \"group\"!");
				return;
			}
		} else if ([key isEqualToString:@"comment"] || [key hasSuffix:@"-options"]) {
			if (![value isKindOfClass:[NSArray class]]) {
				NSLog(@"GPGConf setValue:forKey: Illegal class for key \"%@\"!", key);
				return;
			}
		} else if (![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNumber class]]) {
			NSLog(@"GPGConf setValue:forKey: Illegal class for key \"%@\"!", key);
			return;
		}
		
		[config setObject:value forKey:key];
	} else { //value == nil
		[config removeObjectForKey:key];
	}
}


- (BOOL)saveConfig {
	NSMutableString *lines = [NSMutableString string];
	
	for (NSString *name in config) {
		id value = [config objectForKey:name];
		
		
		if ([name isEqualToString:@"group"]) {
			//value is NSDictionary.
			for (NSString *group in value) {
				[lines appendFormat:@"group %@ = %@\n", group, [[value objectForKey:group] componentsJoinedByString:@" "]];
			}
		} else if ([name isEqualToString:@"comment"]) {
			//value is NSArray.
			for (NSString *comment in value) {
				[lines appendFormat:@"comment %@\n", comment];
			}
		} else if ([name hasSuffix:@"-options"]) {
			//value is NSArray.
			[lines appendFormat:@"%@ %@\n", name, [value componentsJoinedByString:@" "]];
		} else {
			//value is NSNumber or NSString.
			if ([value isKindOfClass:[NSNumber class]]) {
				if ([value boolValue]) {
					[lines appendFormat:@"%@\n", name];
				} else {
					[lines appendFormat:@"no-%@\n", name];
				}
			} else {
				[lines appendFormat:@"%@ %@\n", name, value];
			}
		}
	}

	NSError *error = nil;
	[lines writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
	if (error) {
		return NO;
	}
	return YES;
}

- (BOOL)loadConfig {
	NSError *error = nil;
	NSString *configFile = [NSString stringWithContentsOfFile:path usedEncoding:nil error:&error];
	if (!configFile) {
		NSLog(@"Can't load config (%@): %@", path, error);
		return  NO;
	}
	
	if (config == nil) {
		config = [NSMutableDictionary dictionary];
	} else {
		[config removeAllObjects];
	}
	
	NSRange range;
	NSPredicate *notEmptyPredicate = [NSPredicate predicateWithFormat:@"length > 0"];
	NSCharacterSet *whitespaces = [NSCharacterSet whitespaceCharacterSet];

	
	NSArray *lines = [configFile componentsSeparatedByString:@"\n"];
	
	for (NSString *line in lines) {
		line = [line stringByTrimmingCharactersInSet:whitespaces];
		if ([line hasPrefix:@"#"] || [line length] == 0) {
			continue; //Ignore comments and empty lines.
		}
		
		NSArray *parts = [line componentsSeparatedByCharactersInSet:whitespaces];
		NSString *name = [parts objectAtIndex:0];
		id value;
		
		
		parts = [parts subarrayWithRange:NSMakeRange(1, parts.count - 1)]; // Remove the name from parts.
		line = [parts componentsJoinedByString:@" "]; // Set line to all parts without name. Needed to preserve spaces in the value for the comment-option.
		parts = [parts filteredArrayUsingPredicate:notEmptyPredicate]; // Remove empty parts.

		
		if ([name isEqualToString:@"group"]) {
			NSLog(@"Group Line '%@'", line);
			//NSMutableDictionary *value 
			range = [line rangeOfString:@"="];
			if (range.length == 0 || range.location == 0 || range.location >= [line length] - 1) {
				//TODO: Log the error.
				continue; //Illegal config line.
			}
			
			NSString *group = [[line substringToIndex:range.location] stringByTrimmingCharactersInSet:whitespaces];
			NSArray *members = [[line substringFromIndex:range.location + 1] componentsSeparatedByCharactersInSet:whitespaces];
			members = [members filteredArrayUsingPredicate:notEmptyPredicate];
			
			value = [config objectForKey:name];
			if (value) {
				NSArray *oldMembers = [value objectForKey:group];
				if (oldMembers) {
					members = [oldMembers arrayByAddingObjectsFromArray:members];
				}
				[value setObject:members forKey:group];
			} else {
				value = [NSMutableDictionary dictionaryWithObject:members forKey:group];
			}
		} else if ([name isEqualToString:@"comment"]) {
			NSLog(@"comment Line '%@'", line);
			value = [config objectForKey:name];
			if (value) {
				value = [value arrayByAddingObject:line];
			} else {
				value = [NSArray arrayWithObject:line];;
			}
		} else if ([name hasSuffix:@"-options"]) {
			NSLog(@"options Line '%@'", line);
			value = [config objectForKey:name];
			if (value) {
				NSMutableSet *newValue = [NSMutableSet setWithArray:value];
				[newValue addObjectsFromArray:parts];
				value = [newValue allObjects];
			} else {
				value = parts;
			}
		} else {
			NSLog(@"normal Line '%@'", line);
			//Option die nur einen Wert hat (bzw. haben darf).
			if ([parts count] == 0) {
				if ([name hasPrefix:@"no-"]) {
					name = [name substringFromIndex:3];
					value = [NSNumber numberWithBool:NO];
				} else {
					value = [NSNumber numberWithBool:YES];		 
				}
			} else {
				value = line;
			}
		}
		
		[config setObject:value forKey:name];
	}
	
	return YES;
}

+ (id)confWithPath:(NSString *)aPath {
	return [[[[self class] alloc] initWithPath:aPath] autorelease];
}
- (id)initWithPath:(NSString *)aPath {
	if ((self = [super init]) == nil) {
		return nil;
	}

	self.path = aPath;
	
	if (![self loadConfig]) {
		[self release];
		return nil;
	}
	
	return self;
}
- (id)init {
    return [self initWithPath:nil];
}

@end

/*
 config	is a NSMutableDictionary, it can contain NSNumber(BOOL), NSString, NSArray and NSDictionary.
 
 Samples:
 
 keyserver pgp.mit.edu						NSstring		@"pgp.mit.edu"
 ask-cert-level								NSNumber		YES
 no-version									NSNumber		NO	(The key in config is "version"!)
 list-options show-photos show-keyring		NSArray			@"show-photos", @"show-keyring"
 group xyz=00D026C4 FB3B1734				NSDictionary	xyz = NSArray(@"00D026C4", @"FB3B1734")
 comment Comment Line 1						NSArray			(@"Comment Line 1")
 

*/








