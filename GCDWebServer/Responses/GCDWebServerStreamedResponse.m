#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

@implementation GCDWebServerStreamedResponse {
  GCDWebServerAsyncStreamBlock _block;
}

@dynamic contentType;

+ (instancetype)responseWithContentType:(NSString*)type streamBlock:(GCDWebServerStreamBlock)block {
  return [(GCDWebServerStreamedResponse*)[[self class] alloc] initWithContentType:type streamBlock:block];
}

+ (instancetype)responseWithContentType:(NSString*)type asyncStreamBlock:(GCDWebServerAsyncStreamBlock)block {
  return [(GCDWebServerStreamedResponse*)[[self class] alloc] initWithContentType:type asyncStreamBlock:block];
}

- (instancetype)initWithContentType:(NSString*)type streamBlock:(GCDWebServerStreamBlock)block {
  return [self initWithContentType:type
                  asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock completionBlock) {
    NSError* error = nil;
    NSData* data = block(&error);
    completionBlock(data, error);
  }];
}

- (instancetype)initWithContentType:(NSString*)type asyncStreamBlock:(GCDWebServerAsyncStreamBlock)block {
  if ((self = [super init])) {
    _block = [block copy];
    
    self.contentType = type;
  }
  return self;
}

- (void)asyncReadDataWithCompletion:(GCDWebServerBodyReaderCompletionBlock)block {
  _block(block);
}

- (NSString*)description {
  NSMutableString* description = [NSMutableString stringWithString:[super description]];
  [description appendString:@"\n\n<STREAM>"];
  return description;
}

@end
