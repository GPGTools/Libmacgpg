#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <openssl/x509.h>
#import <xar/xar.h>

BOOL checkPackage(NSString *pkgPath);
BOOL installPackage(NSString *pkgPath, NSString *xmlPath);

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
		
		
		if (!checkPackage(pkgPath)) {
			return 3;
		}
		
		if (!installPackage(pkgPath, xmlPath)) {
			return 4;
		}

	}
	return 0;
}



BOOL checkPackage(NSString *pkgPath) {
	xar_t pkg;
	xar_signature_t signature;
	const char *signatureType;
	const uint8_t *data;
	uint32_t length, plainLength, signLength;
	X509 *certificate;
	uint8_t *plainData, *signData;
	EVP_PKEY *pubkey;
	uint8_t hash[20];
	// This is the hash of the GPGTools installer certificate.
	uint8_t goodHash[] = {0xD9, 0xD5, 0xFD, 0x43, 0x9C, 0x95, 0x16, 0xEF, 0xC7, 0x3A, 0x0E, 0x4A, 0xD0, 0xF2, 0xC5, 0xDB, 0x9E, 0xA0, 0xE3, 0x10};
	
	
	if ((pkg = xar_open([pkgPath UTF8String], READ)) == nil) {
		return NO; // Unable to open the pkg.
	}
	
	signature = xar_signature_first(pkg);
	
	signatureType = xar_signature_type(signature);
	if (!signatureType || strncmp(signatureType, "RSA", 3)) {
		return NO; // Not a RSA signature.
	}
	
	if (xar_signature_get_x509certificate_count(signature) < 1) {
		return NO; // No certificate found.
	}
	
	if (xar_signature_get_x509certificate_data(signature, 0, &data, &length) == -1) {
		return NO; // Unable to extract the certificate data.
	}
	
	SHA1(data, length, (uint8_t *)&hash);
	
	if (memcmp(hash, goodHash, 20) != 0) {
		return NO; // Not the GPGTools certificate!
	}
	
	certificate = d2i_X509(nil, &data, length);
	if (xar_signature_copy_signed_data(signature, &plainData, &plainLength, &signData, &signLength, nil) != 0 || plainLength != 20) {
		return NO; // Unable to copy signed data || not SHA1.
	}
	
	pubkey = X509_get_pubkey(certificate);
	if (!pubkey || pubkey->type != EVP_PKEY_RSA || !pubkey->pkey.rsa) {
		return NO; // No pubkey || not RSA || no RSA.
	}
	
	// The verfication.
	if (RSA_verify(NID_sha1, plainData, plainLength, signData, signLength, pubkey->pkey.rsa) != 1) {
		return NO; // Verification failed!
	}
	
	return YES;
}


BOOL installPackage(NSString *pkgPath, NSString *xmlPath) {
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
		printf("This tool needs the setuid-bit to be set and the owner must be root!\nStart a normal installation using the GUI.\n");
		
		commandString = [NSString stringWithFormat:@"/usr/bin/open -Wnb com.apple.installer \"%@\"", pkgPath];
		command = [commandString UTF8String];
		
		result = system(command);
	}
	
	
	return !!result;
}










