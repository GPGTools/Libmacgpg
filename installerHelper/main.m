#import <Foundation/Foundation.h>
#import <Security/Security.h>

int checkPackage(NSString *pkgPath);
int installPackage(NSString *pkgPath, NSString *xmlPath);

const char *helpText = "This tool checks the signature of an pkg file and installs it.\nYou can specify a xml-file to override the standard choices.";




int main(int argc, const char *argv[]) {
	@autoreleasepool {
	    
	    if (argc < 2 || argc > 3) {
			printf("Usage: installerHelper pkg-file [xml-file]\n%s\n", helpText);
			return 1;
		}
		
		NSString *pkgPath = [NSString stringWithUTF8String:argv[1]], *xmlPath = nil;
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:pkgPath]) {
			printf("Can't find '%s'\n", [pkgPath UTF8String]);
			return 2;
		}
		
		if (argc > 2) {
			xmlPath = [NSString stringWithUTF8String:argv[2]];
			
			if (![[NSFileManager defaultManager] fileExistsAtPath:xmlPath]) {
				printf("Can't find '%s'\n", [xmlPath UTF8String]);
				return 2;
			}
		}
		
		
		int result = checkPackage(pkgPath);
		if (result != 0) {
			return result;
		}
		
		result = installPackage(pkgPath, xmlPath);
		if (result != 0) {
			return result;
		}

	}
	return 0;
}



int checkPackage(NSString *pkgPath) {
	//Check package validity
	NSTask *task = [[NSTask new] autorelease];
	NSPipe *pipe = [NSPipe pipe];
	task.launchPath = @"/usr/sbin/pkgutil";
	task.arguments = [NSArray arrayWithObjects:@"--check-signature", pkgPath, nil];
	task.standardOutput = pipe;
	[task launch];
	
	NSData *output = [[pipe fileHandleForReading] readDataToEndOfFile];
	NSString *text = [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
	
	
	// Search certificate fingerprint.
	NSRange range = [text rangeOfString:@"\n       SHA1 fingerprint: "];
	if (range.location == 0 || range.location == NSNotFound) {
		printf("The package isn't valid signed!\n");
		return 3;
	}
	
	
	// Get SHA1 fingerprint.
	range.location += 26;
	range.length = 59;
	
	NSString *sha1;
	@try {
		sha1 = [text substringWithRange:range];
	}
	@catch (NSException *exception) {
		printf("Can't get cerificate from package!\n");
		return 3;
	}
	
	sha1 = [sha1 stringByReplacingOccurrencesOfString:@" " withString:@""];
	printf("SHA1 certificate fingerprint: %s\n", [sha1 UTF8String]);
	
	
	// Check certificate.
	NSSet *validCertificates = [NSSet setWithObjects:@"D9D5FD439C9516EFC73A0E4AD0F2C5DB9EA0E310", nil];
	if (![validCertificates member:sha1]) {
		printf("Certificate isn't in the list of valid certificates!\n");
		return 4;
	}

	return 0;
}


int installPackage(NSString *pkgPath, NSString *xmlPath) {
	// Run the installer command.
	NSString *commandString;
	if (xmlPath) {
		commandString = [NSString stringWithFormat:@"/usr/sbin/installer -applyChoiceChangesXML \"%@\" -pkg \"%@\" -target /", xmlPath, pkgPath];
	}
	else {
		commandString = [NSString stringWithFormat:@"/usr/sbin/installer -pkg \"%@\" -target /", pkgPath];
	}
	
	const char *command = [commandString UTF8String];
	
	uid_t uid = getuid();
	int result = setuid(0);
	if (result == 0) {
		//Run only this command with root privileges.
		result = system(command);
		setuid(uid);
	} else {
		printf("This tool needs the setuid-bit to be set and the owner must be root!\n");
	}
	
	
	return result;
}










