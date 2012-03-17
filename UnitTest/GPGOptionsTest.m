#import <SenTestingKit/SenTestingKit.h>
#import "GPGOptions.h"

@interface GPGOptionsTest : SenTestCase

@end

@implementation GPGOptionsTest

- (void)testDomainForKey1 {

    GPGOptions *options = [GPGOptions sharedOptions];
    GPGOptionsDomain domain = [options domainForKey:@"marginals-needed"];
    STAssertEquals(domain, GPGDomain_gpgConf, @"unexpected domain");
}

- (void)testDomainForKey2 {
    
    GPGOptions *options = [GPGOptions sharedOptions];
    GPGOptionsDomain domain = [options domainForKey:@"min-passphrase-nonalpha"];
    STAssertEquals(domain, GPGDomain_gpgAgentConf, @"unexpected domain");
}

- (void)testDomainForKey3 {
    
    GPGOptions *options = [GPGOptions sharedOptions];
    GPGOptionsDomain domain = [options domainForKey:@"ShowPassphrase"];
    STAssertEquals(domain, GPGDomain_common, @"unexpected domain");
}

@end
