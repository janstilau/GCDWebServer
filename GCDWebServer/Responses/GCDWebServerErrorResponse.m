#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

@implementation GCDWebServerErrorResponse

+ (instancetype)responseWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 400) && ((NSInteger)errorCode < 500));
  va_list arguments;
  va_start(arguments, format);
  GCDWebServerErrorResponse* response = [(GCDWebServerErrorResponse*)[self alloc] initWithStatusCode:errorCode underlyingError:nil messageFormat:format arguments:arguments];
  va_end(arguments);
  return response;
}

+ (instancetype)responseWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 500) && ((NSInteger)errorCode < 600));
  va_list arguments;
  va_start(arguments, format);
  GCDWebServerErrorResponse* response = [(GCDWebServerErrorResponse*)[self alloc] initWithStatusCode:errorCode underlyingError:nil messageFormat:format arguments:arguments];
  va_end(arguments);
  return response;
}

+ (instancetype)responseWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 400) && ((NSInteger)errorCode < 500));
  va_list arguments;
  va_start(arguments, format);
  GCDWebServerErrorResponse* response = [(GCDWebServerErrorResponse*)[self alloc] initWithStatusCode:errorCode underlyingError:underlyingError messageFormat:format arguments:arguments];
  va_end(arguments);
  return response;
}

+ (instancetype)responseWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 500) && ((NSInteger)errorCode < 600));
  va_list arguments;
  va_start(arguments, format);
  GCDWebServerErrorResponse* response = [(GCDWebServerErrorResponse*)[self alloc] initWithStatusCode:errorCode underlyingError:underlyingError messageFormat:format arguments:arguments];
  va_end(arguments);
  return response;
}

static inline NSString* _EscapeHTMLString(NSString* string) {
  return [string stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode underlyingError:(NSError*)underlyingError messageFormat:(NSString*)format arguments:(va_list)arguments {
  NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
  NSString* title = [NSString stringWithFormat:@"HTTP Error %i", (int)statusCode];
  NSString* error = underlyingError ? [NSString stringWithFormat:@"[%@] %@ (%li)", underlyingError.domain, _EscapeHTMLString(underlyingError.localizedDescription), (long)underlyingError.code] : @"";
  NSString* html = [NSString stringWithFormat:@"<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>%@</title></head><body><h1>%@: %@</h1><h3>%@</h3></body></html>",
                                              title, title, _EscapeHTMLString(message), error];
  if ((self = [self initWithHTML:html])) {
    self.statusCode = statusCode;
  }
  return self;
}

- (instancetype)initWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 400) && ((NSInteger)errorCode < 500));
  va_list arguments;
  va_start(arguments, format);
  self = [self initWithStatusCode:errorCode underlyingError:nil messageFormat:format arguments:arguments];
  va_end(arguments);
  return self;
}

- (instancetype)initWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 500) && ((NSInteger)errorCode < 600));
  va_list arguments;
  va_start(arguments, format);
  self = [self initWithStatusCode:errorCode underlyingError:nil messageFormat:format arguments:arguments];
  va_end(arguments);
  return self;
}

- (instancetype)initWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 400) && ((NSInteger)errorCode < 500));
  va_list arguments;
  va_start(arguments, format);
  self = [self initWithStatusCode:errorCode underlyingError:underlyingError messageFormat:format arguments:arguments];
  va_end(arguments);
  return self;
}

- (instancetype)initWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(NSError*)underlyingError message:(NSString*)format, ... {
  GWS_DCHECK(((NSInteger)errorCode >= 500) && ((NSInteger)errorCode < 600));
  va_list arguments;
  va_start(arguments, format);
  self = [self initWithStatusCode:errorCode underlyingError:underlyingError messageFormat:format arguments:arguments];
  va_end(arguments);
  return self;
}

@end
