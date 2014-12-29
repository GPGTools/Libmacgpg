#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <openssl/x509.h>
#import <xar/xar.h>

BOOL checkPackage(NSString *pkgPath);
BOOL installPackage(NSString *pkgPath, NSString *xmlPath);

const char *helpText = "This tool checks the signature of a pkg-file and installs it.\nYou can provide a pkg-file.xml to override the standard choices.";



int main(int argc, const char *argv[]) {
	@autoreleasepool {
		if (argc != 2) {
			printf("Usage: installerHelper pkg-file\n%s\n", helpText);
			return 1;
		}
		NSString *pkgPath = [NSString stringWithUTF8String:argv[1]];
		
		if (![[pkgPath substringFromIndex:pkgPath.length - 4] isEqualToString:@".pkg"]) {
			printf("Not a pkg-file: '%s'!\n", [pkgPath UTF8String]);
			return 2;
		}
		
		BOOL isDir;
		if (![[NSFileManager defaultManager] fileExistsAtPath:pkgPath isDirectory:&isDir] || isDir) {
			printf("Can't find '%s'!\n", [pkgPath UTF8String]);
			return 3;
		}
		
		
		NSString *xmlPath = [pkgPath stringByAppendingString:@".xml"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:xmlPath isDirectory:&isDir] || isDir) {
			xmlPath = nil;
		}
		
		
		if (!checkPackage(pkgPath)) {
			printf("The pkg-file isn't signed correctly!\n");
			return 4;
		}
		
		if (!installPackage(pkgPath, xmlPath)) {
			printf("Installation failed!\n");
			return 5;
		}

	}
	return 0;
}

BOOL installerCertificateIsTrustworthy(NSString *pkgPath) {
	OSStatus error = noErr;
	NSMutableArray *certificates = nil;
	SecPolicyRef policy = NULL;
	SecTrustRef trust = NULL;
	SecTrustResultType trustResult;
	CSSM_OID oid = CSSMOID_APPLE_X509_BASIC;

	xar_t pkg = NULL;
	xar_signature_t signature = NULL;
	const uint8_t *certificateData = NULL;
	uint32_t certificateLength = 0;
	SecCertificateRef currentCertificateRef = NULL;

	// Open the pkg.
	if ((pkg = xar_open([pkgPath UTF8String], READ)) == nil) {
		return NO; // Unable to open the pkg.
	}

	// Retrieve the first signature.
	signature = xar_signature_first(pkg);
	if(signature == NULL) {
		xar_close(pkg);
		return NO;
	}

	int32_t nrOfCerts = xar_signature_get_x509certificate_count(signature);
	certificates = [[NSMutableArray alloc] init];
	for(int32_t i = 0; i < nrOfCerts; i++) {
		if(xar_signature_get_x509certificate_data(signature, i, &certificateData, &certificateLength) != 0) {
			[certificates release];
			xar_close(pkg);
			return NO;
		}
		const CSSM_DATA cert = { (CSSM_SIZE) certificateLength, (uint8_t *) certificateData };
		error = SecCertificateCreateFromData(&cert, CSSM_CERT_X_509v3, CSSM_CERT_ENCODING_DER, &currentCertificateRef);
		if(error != errSecSuccess) {
			[certificates release];
			xar_close(pkg);
			return NO;
		}
		[certificates addObject:(id)currentCertificateRef];
	}

	policy = SecPolicyCreateBasicX509();
	error = SecTrustCreateWithCertificates((CFArrayRef)certificates, policy, &trust);
	if(error != noErr) {
		[certificates release];
		if(policy)
			CFRelease(policy);
		if(trust)
			CFRelease(trust);
		xar_close(pkg);
		return NO;
	}

	// Check if the certificate can be trusted.
	error = SecTrustEvaluate(trust, &trustResult);
	if(error != noErr) {
		[certificates release];
		if(policy)
			CFRelease(policy);
		if(trust)
			CFRelease(trust);
		xar_close(pkg);
		return NO;
	}

	if(trustResult == kSecTrustResultProceed || trustResult == kSecTrustResultConfirm ||
	   trustResult == kSecTrustResultUnspecified) {
		// Clean up and return that the certificate can be trusted.
		[certificates release];
		if(policy)
			CFRelease(policy);
		if(trust)
			CFRelease(trust);
		xar_close(pkg);
		return YES;
	}

	return NO;
}

BOOL checkPackage(NSString *pkgPath) {
	xar_t pkg = NULL;
	xar_signature_t signature = NULL;
	const char *signatureType = NULL;
	const uint8_t *data = NULL;
	uint32_t length = 0, plainLength = 0, signLength = 0;
	X509 *certificate = NULL;
	uint8_t *plainData = NULL, *signData = NULL;
	EVP_PKEY *pubkey = NULL;
	RSA *rsa = NULL;
	uint8_t hash[20];
	int verificiationSuccess = 0;
	// This is the hash of the GPGTools installer certificate.
	uint8_t goodHash[] = {0x56, 0x16, 0x98, 0xDA, 0x21, 0xAF, 0xA4, 0xFB, 0x04, 0xDF, 0x54, 0x17, 0x01, 0x0B, 0x59, 0x00, 0x5D, 0x5B, 0x3A, 0xDF};
	
	
	if ((pkg = xar_open([pkgPath UTF8String], READ)) == nil) {
		return NO; // Unable to open the pkg.
	}
	
	signature = xar_signature_first(pkg);
	// No signature, bail out.
	if(signature == NULL) {
		xar_close(pkg);
		return NO;
	}
	
	signatureType = xar_signature_type(signature);
	// No signature type available, bail out.
	if(signatureType == NULL) {
		xar_close(pkg);
		return NO;
	}
	
	// Signature type has to be RSA.
	if(strlen(signatureType) != 3) {
		xar_close(pkg);
		return NO;
	}
	if(strncmp(signatureType, "RSA", 3)) {
		xar_close(pkg);
		return NO;
	}

	if (xar_signature_get_x509certificate_count(signature) < 1) {
		xar_close(pkg);
		return NO; // No certificate found.
	}
	
	if (xar_signature_get_x509certificate_data(signature, 0, &data, &length) != 0) {
		xar_close(pkg);
		return NO; // Unable to extract the certificate data.
	}
	
	SHA1(data, length, (uint8_t *)&hash);

	if (memcmp(hash, goodHash, 20) != 0) {
		xar_close(pkg);
		return NO; // Not the GPGTools certificate!
	}
	
	certificate = d2i_X509(nil, &data, length);
	if(certificate == NULL) {
		xar_close(pkg);
		return NO;
	}
	if (xar_signature_copy_signed_data(signature, &plainData, &plainLength, &signData, &signLength, nil) != 0) {
		X509_free(certificate);
		xar_close(pkg);
		return NO; // Unable to copy signed data || not SHA1.
	}
	// Not SHA-1
	if(plainLength != 20) {
		X509_free(certificate);
		free(plainData);
		free(signData);
		xar_close(pkg);
		return NO;
	}
	
	pubkey = X509_get_pubkey(certificate);
	// No public key available.
		if(!pubkey) {
		X509_free(certificate);
		free(plainData);
		free(signData);
		xar_close(pkg);
		return NO;
	}
	// The public key is not RSA.
	if(pubkey->type != EVP_PKEY_RSA) {
		X509_free(certificate);
		free(plainData);
		free(signData);
		xar_close(pkg);
		return NO;
	}
	// RSA is not set.
	rsa = pubkey->pkey.rsa;
	if(!rsa) {
		X509_free(certificate);
		free(plainData);
		free(signData);
		xar_close(pkg);
		return NO;
	}
	
	// The verfication.
	verificiationSuccess = RSA_verify(NID_sha1, plainData, plainLength, signData, signLength, rsa);
	if (verificiationSuccess != 1) {
		X509_free(certificate);
		free(plainData);
		free(signData);
		xar_close(pkg);
		return NO; // Verification failed!
	}
	
	// Cleanup.
	X509_free(certificate);
	free(plainData);
	free(signData);
	xar_close(pkg);

	return installerCertificateIsTrustworthy(pkgPath);
}

BOOL installPackage(NSString *pkgPath, NSString *xmlPath) {
	// Run the installer command.
	
	NSArray *arguments;
	if (xmlPath) {
		arguments = @[@"-applyChoiceChangesXML", xmlPath, @"-pkg", pkgPath, @"-target", @"/"];
	} else {
		arguments = @[@"-pkg", pkgPath, @"-target", @"/"];
	}
		
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = @"/usr/sbin/installer";
	task.arguments = arguments;
	
	
	uid_t uid = getuid();
	int result = setuid(0);
	if (result == 0) {
		//Run only this command with root privileges.
		[task launch];
		[task waitUntilExit];
		result = task.terminationStatus;
		setuid(uid);
	} else {
		printf("This tool needs the setuid-bit to be set and the owner must be root!\nStarting a normal installation using the GUI.\n");
		
		task.launchPath = @"/usr/bin/open";
		task.arguments = @[@"-Wnb", @"com.apple.installer", pkgPath];

		[task launch];
		[task waitUntilExit];
		result = task.terminationStatus;
	}
	
	
	return result == 0;
}










