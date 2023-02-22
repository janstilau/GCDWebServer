#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

@implementation GCDWebServerDataResponse {
  NSData* _data;
  BOOL _done;
}

@dynamic contentType;

+ (instancetype)responseWithData:(NSData*)data contentType:(NSString*)type {
  return [(GCDWebServerDataResponse*)[[self class] alloc] initWithData:data contentType:type];
}

- (instancetype)initWithData:(NSData*)data contentType:(NSString*)type {
  if ((self = [super init])) {
    _data = data;

    self.contentType = type;
    self.contentLength = data.length;
  }
  return self;
}

- (NSData*)readData:(NSError**)error {
  NSData* data;
  if (_done) {
    data = [NSData data];
  } else {
    data = _data;
    _done = YES;
  }
  return data;
}

- (NSString*)description {
  NSMutableString* description = [NSMutableString stringWithString:[super description]];
  [description appendString:@"\n\n"];
  [description appendString:GCDWebServerDescribeData(_data, self.contentType)];
  return description;
}

@end

@implementation GCDWebServerDataResponse (Extensions)

+ (instancetype)responseWithText:(NSString*)text {
  return [(GCDWebServerDataResponse*)[self alloc] initWithText:text];
}

+ (instancetype)responseWithHTML:(NSString*)html {
  return [(GCDWebServerDataResponse*)[self alloc] initWithHTML:html];
}

+ (instancetype)responseWithHTMLTemplate:(NSString*)path variables:(NSDictionary<NSString*, NSString*>*)variables {
  return [(GCDWebServerDataResponse*)[self alloc] initWithHTMLTemplate:path variables:variables];
}

+ (instancetype)responseWithJSONObject:(id)object {
  return [(GCDWebServerDataResponse*)[self alloc] initWithJSONObject:object];
}

+ (instancetype)responseWithJSONObject:(id)object contentType:(NSString*)type {
  return [(GCDWebServerDataResponse*)[self alloc] initWithJSONObject:object contentType:type];
}

- (instancetype)initWithText:(NSString*)text {
  NSData* data = [text dataUsingEncoding:NSUTF8StringEncoding];
  if (data == nil) {
    GWS_DNOT_REACHED();
    return nil;
  }
  return [self initWithData:data contentType:@"text/plain; charset=utf-8"];
}

- (instancetype)initWithHTML:(NSString*)html {
  NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
  if (data == nil) {
    GWS_DNOT_REACHED();
    return nil;
  }
  return [self initWithData:data contentType:@"text/html; charset=utf-8"];
}

- (instancetype)initWithHTMLTemplate:(NSString*)path variables:(NSDictionary<NSString*, NSString*>*)variables {
  NSMutableString* html = [[NSMutableString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
  [variables enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* value, BOOL* stop) {
    [html replaceOccurrencesOfString:[NSString stringWithFormat:@"%%%@%%", key] withString:value options:0 range:NSMakeRange(0, html.length)];
  }];
  return [self initWithHTML:html];
}

- (instancetype)initWithJSONObject:(id)object {
  return [self initWithJSONObject:object contentType:@"application/json"];
}

- (instancetype)initWithJSONObject:(id)object contentType:(NSString*)type {
  NSData* data = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
  if (data == nil) {
    GWS_DNOT_REACHED();
    return nil;
  }
  return [self initWithData:data contentType:type];
}

@end
