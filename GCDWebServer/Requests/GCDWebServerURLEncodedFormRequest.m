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
