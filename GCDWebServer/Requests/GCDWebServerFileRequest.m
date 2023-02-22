#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

@implementation GCDWebServerFileRequest {
  int _file;
}

- (instancetype)initWithMethod:(NSString*)method url:(NSURL*)url headers:(NSDictionary<NSString*, NSString*>*)headers path:(NSString*)path query:(NSDictionary<NSString*, NSString*>*)query {
  if ((self = [super initWithMethod:method url:url headers:headers path:path query:query])) {
    _temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  }
  return self;
}

- (void)dealloc {
  unlink([_temporaryPath fileSystemRepresentation]);
}

- (BOOL)open:(NSError**)error {
  _file = open([_temporaryPath fileSystemRepresentation], O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
  if (_file <= 0) {
    if (error) {
      *error = GCDWebServerMakePosixError(errno);
    }
    return NO;
  }
  return YES;
}

- (BOOL)writeData:(NSData*)data error:(NSError**)error {
  if (write(_file, data.bytes, data.length) != (ssize_t)data.length) {
    if (error) {
      *error = GCDWebServerMakePosixError(errno);
    }
    return NO;
  }
  return YES;
}

- (BOOL)close:(NSError**)error {
  if (close(_file) < 0) {
    if (error) {
      *error = GCDWebServerMakePosixError(errno);
    }
    return NO;
  }
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
  NSString* creationDateHeader = [self.headers objectForKey:@"X-GCDWebServer-CreationDate"];
  if (creationDateHeader) {
    NSDate* date = GCDWebServerParseISO8601(creationDateHeader);
    if (!date || ![[NSFileManager defaultManager] setAttributes:@{NSFileCreationDate : date} ofItemAtPath:_temporaryPath error:error]) {
      return NO;
    }
  }
  NSString* modifiedDateHeader = [self.headers objectForKey:@"X-GCDWebServer-ModifiedDate"];
  if (modifiedDateHeader) {
    NSDate* date = GCDWebServerParseRFC822(modifiedDateHeader);
    if (!date || ![[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate : date} ofItemAtPath:_temporaryPath error:error]) {
      return NO;
    }
  }
#endif
  return YES;
}

- (NSString*)description {
  NSMutableString* description = [NSMutableString stringWithString:[super description]];
  [description appendFormat:@"\n\n{%@}", _temporaryPath];
  return description;
}

@end
