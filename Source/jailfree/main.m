//
//  main.m
//  jailfree-service
//
//  Created by Lukas Pitschl on 28.09.12.
//
//

#include <Foundation/Foundation.h>
#include "GPGGlobals.h"
#include "JailfreeTask.h"

@interface JailfreeService : NSObject <NSXPCListenerDelegate>
@end

@implementation JailfreeService

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jailfree)];
    
    
    JailfreeTask *exportedObject = [[JailfreeTask alloc] init];
    newConnection.exportedObject = exportedObject;
    
    // We'll take advantage of the bi-directional nature of NSXPCConnections to send progress back to the caller. The remote side of this connection should implement the FetchProgress protocol.
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Jail)];
    
    // Let the fetcher know what connection object it should use to send back progress to the caller.
    // Note that this is a zeroing weak refernece, because the connection retains the exported object and we do not want to create a retain cycle.
    exportedObject.xpcConnection = newConnection;
    
    [newConnection resume];
    return YES;
}

@end

int main(int argc, const char *argv[])
{
	NSXPCListener *serviceListener = [[NSXPCListener alloc] initWithMachServiceName:JAILFREE_XPC_MACH_NAME];
    
    JailfreeService *delegate = [[JailfreeService alloc] init];
    serviceListener.delegate = delegate;
    
    [serviceListener resume];
    
    dispatch_main();
    
    return 0;
}
