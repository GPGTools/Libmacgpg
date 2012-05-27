//
//  NSRunLoop+TimeOutAndFlag.h
//
// https://gist.github.com/n-b
//

@interface NSRunLoop (TimeOutAndFlag)

- (void)runUntilTimeout:(NSTimeInterval)delay orFinishedFlag:(BOOL*)finished;

@end
