#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import "GCDWebServerPrivate.h"

// Data Request, 就是将数据存储到内存里面的 NSMutableData 里面.
@interface GCDWebServerDataRequest ()

@property(nonatomic) NSMutableData* data;

@end

@implementation GCDWebServerDataRequest {
  NSString* _text;
  id _jsonObject;
}

- (BOOL)open:(NSError**)error {
  if (self.contentLength != NSUIntegerMax) {
    // 使用 self.contentLength 可以使得 NSMutableData 的建立更加的高效.
    // _data 的创建, 延缓到了真正业务调用的地方.
    _data = [[NSMutableData alloc] initWithCapacity:self.contentLength];
  } else {
    _data = [[NSMutableData alloc] init];
  }
  if (_data == nil) {
    if (error) {
      *error = [NSError errorWithDomain:kGCDWebServerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Failed allocating memory"}];
    }
    return NO;
  }
  return YES;
}

// Write 就是拼接 data 到内存里面.
- (BOOL)writeData:(NSData*)data error:(NSError**)error {
  [_data appendData:data];
  return YES;
}

- (BOOL)close:(NSError**)error {
  return YES;
}

- (NSString*)description {
  NSMutableString* description = [NSMutableString stringWithString:[super description]];
  if (_data) {
    [description appendString:@"\n\n"];
    [description appendString:GCDWebServerDescribeData(_data, (NSString*)self.contentType)];
  }
  return description;
}

@end

@implementation GCDWebServerDataRequest (Extensions)

// 其实当做计算属性可能更加好一点, 专门找一个成员变量存储, 会让效率更加高一点. 
- (NSString*)text {
  if (_text == nil) {
    if ([self.contentType hasPrefix:@"text/"]) {
      NSString* charset = GCDWebServerExtractHeaderValueParameter(self.contentType, @"charset");
      _text = [[NSString alloc] initWithData:self.data encoding:GCDWebServerStringEncodingFromCharset(charset)];
    } else {
      GWS_DNOT_REACHED();
    }
  }
  return _text;
}

- (id)jsonObject {
  if (_jsonObject == nil) {
    NSString* mimeType = GCDWebServerTruncateHeaderValue(self.contentType);
    if ([mimeType isEqualToString:@"application/json"] ||
        [mimeType isEqualToString:@"text/json"] ||
        [mimeType isEqualToString:@"text/javascript"]) {
      _jsonObject = [NSJSONSerialization JSONObjectWithData:_data options:0 error:NULL];
    } else {
      GWS_DNOT_REACHED();
    }
  }
  return _jsonObject;
}

@end
