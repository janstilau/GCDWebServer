#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

@implementation GCDWebServerURLEncodedFormRequest

+ (NSString*)mimeType {
  return @"application/x-www-form-urlencoded";
}

- (BOOL)close:(NSError**)error {
  if (![super close:error]) {
    return NO;
  }

  // 在 Close 的时候, 将 Request Body 拼接成为字符串之后, 然后分析数据成为一个 NSDict 对象.
  NSString* charset = GCDWebServerExtractHeaderValueParameter(self.contentType, @"charset");
  NSString* string = [[NSString alloc] initWithData:self.data encoding:GCDWebServerStringEncodingFromCharset(charset)];
  _arguments = GCDWebServerParseURLEncodedForm(string);
  return YES;
}

- (NSString*)description {
  NSMutableString* description = [NSMutableString stringWithString:[super description]];
  [description appendString:@"\n"];
  for (NSString* argument in [[_arguments allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
    [description appendFormat:@"\n%@ = %@", argument, [_arguments objectForKey:argument]];
  }
  return description;
}

@end
