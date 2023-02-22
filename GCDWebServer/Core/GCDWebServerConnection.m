#if !__has_feature(objc_arc)
#error GCDWebServer requires ARC
#endif

#import <TargetConditionals.h>
#import <netdb.h>
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
#import <libkern/OSAtomic.h>
#endif

#import "GCDWebServerPrivate.h"

#define kHeadersReadCapacity (1 * 1024)
#define kBodyReadCapacity (256 * 1024)

typedef void (^ReadDataCompletionBlock)(BOOL success);
typedef void (^ReadHeadersCompletionBlock)(NSData* extraData);
typedef void (^ReadBodyCompletionBlock)(BOOL success);

typedef void (^WriteDataCompletionBlock)(BOOL success);
typedef void (^WriteHeadersCompletionBlock)(BOOL success);
typedef void (^WriteBodyCompletionBlock)(BOOL success);

static NSData* _CRLFData = nil;
static NSData* _CRLFCRLFData = nil;
static NSData* _continueData = nil;
static NSData* _lastChunkData = nil;
static NSString* _digestAuthenticationNonce = nil;
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
static int32_t _connectionCounter = 0;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface GCDWebServerConnection (Read)
- (void)readData:(NSMutableData*)data withLength:(NSUInteger)length completionBlock:(ReadDataCompletionBlock)block;
- (void)readHeaders:(NSMutableData*)headersData withCompletionBlock:(ReadHeadersCompletionBlock)block;
- (void)readBodyWithRemainingLength:(NSUInteger)length completionBlock:(ReadBodyCompletionBlock)block;
- (void)readNextBodyChunk:(NSMutableData*)chunkData completionBlock:(ReadBodyCompletionBlock)block;
@end

@interface GCDWebServerConnection (Write)
- (void)writeData:(NSData*)data withCompletionBlock:(WriteDataCompletionBlock)block;
- (void)writeHeadersWithCompletionBlock:(WriteHeadersCompletionBlock)block;
- (void)writeBodyWithCompletionBlock:(WriteBodyCompletionBlock)block;
@end

NS_ASSUME_NONNULL_END

@implementation GCDWebServerConnection {
  CFSocketNativeHandle _socket;
  BOOL _virtualHEAD;
  
  CFHTTPMessageRef _requestMessage;
  GCDWebServerRequest* _request;
  GCDWebServerHandler* _handler;
  CFHTTPMessageRef _responseMessage;
  GCDWebServerResponse* _response;
  NSInteger _statusCode;
  
  BOOL _opened;
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
  NSUInteger _connectionIndex;
  NSString* _requestPath;
  int _requestFD;
  NSString* _responsePath;
  int _responseFD;
#endif
}

+ (void)initialize {
  if (_CRLFData == nil) {
    _CRLFData = [[NSData alloc] initWithBytes:"\r\n" length:2];
    GWS_DCHECK(_CRLFData);
  }
  if (_CRLFCRLFData == nil) {
    _CRLFCRLFData = [[NSData alloc] initWithBytes:"\r\n\r\n" length:4];
    GWS_DCHECK(_CRLFCRLFData);
  }
  if (_continueData == nil) {
    CFHTTPMessageRef message = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 100, NULL, kCFHTTPVersion1_1);
    _continueData = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    CFRelease(message);
    GWS_DCHECK(_continueData);
  }
  if (_lastChunkData == nil) {
    _lastChunkData = [[NSData alloc] initWithBytes:"0\r\n\r\n" length:5];
  }
  if (_digestAuthenticationNonce == nil) {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    _digestAuthenticationNonce = GCDWebServerComputeMD5Digest(@"%@", CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid)));
    CFRelease(uuid);
  }
}

- (BOOL)isUsingIPv6 {
  const struct sockaddr* localSockAddr = _localAddressData.bytes;
  return (localSockAddr->sa_family == AF_INET6);
}

- (void)_initializeResponseHeadersWithStatusCode:(NSInteger)statusCode {
  _statusCode = statusCode;
  // 在这里, 进行了响应值的创建.
  _responseMessage = CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, NULL, kCFHTTPVersion1_1);
  CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Connection"), CFSTR("Close"));
  CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Server"), (__bridge CFStringRef)_server.serverName);
  CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Date"), (__bridge CFStringRef)GCDWebServerFormatRFC822([NSDate date]));
}

- (void)_startProcessingRequest {
  GWS_DCHECK(_responseMessage == NULL);
  
  GCDWebServerResponse* preflightResponse = [self preflightRequest:_request];
  if (preflightResponse) {
    // request 里面有着关于安全验证的信息. 直接返回相应的 response.
    [self _finishProcessingRequest:preflightResponse];
  } else {
    [self processRequest:_request
              completion:^(GCDWebServerResponse* processResponse) {
      [self _finishProcessingRequest:processResponse];
    }];
  }
}

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
// 这就是, 构建出对应的 Resposne, 然后回传给请求的逻辑.
- (void)_finishProcessingRequest:(GCDWebServerResponse*)response {
  GWS_DCHECK(_responseMessage == NULL);
  BOOL hasBody = NO;
  
  if (response) {
    response = [self overrideResponse:response forRequest:_request];
  }
  if (response) {
    if ([response hasBody]) {
      [response prepareForReading];
      hasBody = !_virtualHEAD;
    }
    NSError* error = nil;
    if (hasBody && ![response performOpen:&error]) {
      GWS_LOG_ERROR(@"Failed opening response body for socket %i: %@", _socket, error);
    } else {
      _response = response;
    }
  }
  
  if (_response) {
    [self _initializeResponseHeadersWithStatusCode:_response.statusCode];
    if (_response.lastModifiedDate) {
      CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Last-Modified"), (__bridge CFStringRef)GCDWebServerFormatRFC822((NSDate*)_response.lastModifiedDate));
    }
    if (_response.eTag) {
      CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("ETag"), (__bridge CFStringRef)_response.eTag);
    }
    if ((_response.statusCode >= 200) && (_response.statusCode < 300)) {
      if (_response.cacheControlMaxAge > 0) {
        CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Cache-Control"), (__bridge CFStringRef)[NSString stringWithFormat:@"max-age=%i, public", (int)_response.cacheControlMaxAge]);
      } else {
        CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Cache-Control"), CFSTR("no-cache"));
      }
    }
    if (_response.contentType != nil) {
      CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Content-Type"), (__bridge CFStringRef)GCDWebServerNormalizeHeaderValue(_response.contentType));
    }
    if (_response.contentLength != NSUIntegerMax) {
      CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Content-Length"), (__bridge CFStringRef)[NSString stringWithFormat:@"%lu", (unsigned long)_response.contentLength]);
    }
    if (_response.usesChunkedTransferEncoding) {
      CFHTTPMessageSetHeaderFieldValue(_responseMessage, CFSTR("Transfer-Encoding"), CFSTR("chunked"));
    }
    [_response.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
      CFHTTPMessageSetHeaderFieldValue(self->_responseMessage, (__bridge CFStringRef)key, (__bridge CFStringRef)obj);
    }];
    [self writeHeadersWithCompletionBlock:^(BOOL success) {
      if (success) {
        if (hasBody) {
          [self writeBodyWithCompletionBlock:^(BOOL successInner) {
            [self->_response performClose];  // TODO: There's nothing we can do on failure as headers have already been sent
          }];
        }
      } else if (hasBody) {
        [self->_response performClose];
      }
    }];
  } else {
    [self abortRequest:_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
  }
}

// 读取 HttpBody 的过程. initialData 是从 HttpHeader 开始收到的所有信息.
- (void)_readBodyWithLength:(NSUInteger)contentLength initialData:(NSData*)initialData {
  NSError* error = nil;
  if (![_request performOpen:&error]) {
    GWS_LOG_ERROR(@"Failed opening request body for socket %i: %@", _socket, error);
    [self abortRequest:_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
    return;
  }
  
  if (initialData.length) {
    if (![_request performWriteData:initialData error:&error]) {
      GWS_LOG_ERROR(@"Failed writing request body on socket %i: %@", _socket, error);
      if (![_request performClose:&error]) {
        GWS_LOG_ERROR(@"Failed closing request body for socket %i: %@", _socket, error);
      }
      [self abortRequest:_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
      return;
    }
    contentLength -= initialData.length;
  }
  
  if (contentLength) {
    [self readBodyWithRemainingLength:contentLength
                      completionBlock:^(BOOL success) {
      NSError* localError = nil;
      if ([self->_request performClose:&localError]) {
        // 当, 读完了所有的 Request 的信息之后, 进行 Request 的真正业务处理.
        [self _startProcessingRequest];
      } else {
        GWS_LOG_ERROR(@"Failed closing request body for socket %i: %@", self->_socket, error);
        [self abortRequest:self->_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
      }
    }];
  } else {
    if ([_request performClose:&error]) {
      [self _startProcessingRequest];
    } else {
      GWS_LOG_ERROR(@"Failed closing request body for socket %i: %@", _socket, error);
      [self abortRequest:_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
    }
  }
}

- (void)_readChunkedBodyWithInitialData:(NSData*)initialData {
  NSError* error = nil;
  if (![_request performOpen:&error]) {
    GWS_LOG_ERROR(@"Failed opening request body for socket %i: %@", _socket, error);
    [self abortRequest:_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
    return;
  }
  
  NSMutableData* chunkData = [[NSMutableData alloc] initWithData:initialData];
  [self readNextBodyChunk:chunkData
          completionBlock:^(BOOL success) {
    NSError* localError = nil;
    if ([self->_request performClose:&localError]) {
      [self _startProcessingRequest];
    } else {
      GWS_LOG_ERROR(@"Failed closing request body for socket %i: %@", self->_socket, error);
      [self abortRequest:self->_request withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
    }
  }];
}

- (void)_readRequestHeaders {
  // 不断的进行 Request 数据的读取.
  _requestMessage = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
  NSMutableData* headersData = [[NSMutableData alloc] initWithCapacity:kHeadersReadCapacity];
  [self readHeaders:headersData withCompletionBlock:^(NSData* headerData) {
    // 如果 headerData 有值, 就代表着至少作为请求头已经传输完毕了.
    // 相关的值记录到了 _requestMessage 内部.
    // 可以从 _requestMessage 内部, 来抽取请求相关的值了.
    if (headerData) {
      NSString* requestMethod = CFBridgingRelease(CFHTTPMessageCopyRequestMethod(self->_requestMessage));  // Method verbs are case-sensitive and uppercase
      if (self->_server.shouldAutomaticallyMapHEADToGET && [requestMethod isEqualToString:@"HEAD"]) {
        requestMethod = @"GET";
        self->_virtualHEAD = YES;
      }
      NSDictionary* requestHeaders = CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(self->_requestMessage));  // Header names are case-insensitive but CFHTTPMessageCopyAllHeaderFields() will standardize the common ones
      NSURL* requestURL = CFBridgingRelease(CFHTTPMessageCopyRequestURL(self->_requestMessage));
      if (requestURL) {
        requestURL = [self rewriteRequestURL:requestURL withMethod:requestMethod headers:requestHeaders];
        GWS_DCHECK(requestURL);
      }
      NSString* urlPath = requestURL ? CFBridgingRelease(CFURLCopyPath((CFURLRef)requestURL)) : nil;  // Don't use -[NSURL path] which strips the ending slash
      if (urlPath == nil) {
        urlPath = @"/";  // CFURLCopyPath() returns NULL for a relative URL with path "//" contrary to -[NSURL path] which returns "/"
      }
      NSString* requestPath = urlPath ? GCDWebServerUnescapeURLString(urlPath) : nil;
      NSString* queryString = requestURL ? CFBridgingRelease(CFURLCopyQueryString((CFURLRef)requestURL, NULL)) : nil;  // Don't use -[NSURL query] to make sure query is not unescaped;
      NSDictionary* requestQuery = queryString ? GCDWebServerParseURLEncodedForm(queryString) : @{};
      // 抽取完毕 Request Header 相关的值, 就使用之前注册的各个 Handler 来完成对应 reqeust 的处理.
      if (requestMethod && requestURL && requestHeaders && requestPath && requestQuery) {
        for (self->_handler in self->_server.handlers) {
          self->_request = self->_handler.matchBlock(requestMethod, requestURL, requestHeaders, requestPath, requestQuery);
          if (self->_request) {
            break;
          }
        }
        if (self->_request) {
          self->_request.localAddressData = self.localAddressData;
          self->_request.remoteAddressData = self.remoteAddressData;
          if ([self->_request hasBody]) {
            // 进行 HttpBody 的拉取.
            [self->_request prepareForWriting];
            if (self->_request.usesChunkedTransferEncoding || (headerData.length <= self->_request.contentLength)) {
              NSString* expectHeader = [requestHeaders objectForKey:@"Expect"];
              if (expectHeader) {
                // Expect 的先不管.
                if ([expectHeader caseInsensitiveCompare:@"100-continue"] == NSOrderedSame) {  // TODO: Actually validate request before continuing
                  [self writeData:_continueData
              withCompletionBlock:^(BOOL success) {
                    if (success) {
                      if (self->_request.usesChunkedTransferEncoding) {
                        [self _readChunkedBodyWithInitialData:headerData];
                      } else {
                        [self _readBodyWithLength:self->_request.contentLength initialData:headerData];
                      }
                    }
                  }];
                } else {
                  GWS_LOG_ERROR(@"Unsupported 'Expect' / 'Content-Length' header combination on socket %i", self->_socket);
                  [self abortRequest:self->_request withStatusCode:kGCDWebServerHTTPStatusCode_ExpectationFailed];
                }
              } else {
                if (self->_request.usesChunkedTransferEncoding) {
                  [self _readChunkedBodyWithInitialData:headerData];
                } else {
                  [self _readBodyWithLength:self->_request.contentLength initialData:headerData];
                }
              }
            } else {
              GWS_LOG_ERROR(@"Unexpected 'Content-Length' header value on socket %i", self->_socket);
              [self abortRequest:self->_request withStatusCode:kGCDWebServerHTTPStatusCode_BadRequest];
            }
          } else {
            [self _startProcessingRequest];
          }
        } else {
          // 错误处理.
          self->_request = [[GCDWebServerRequest alloc] initWithMethod:requestMethod url:requestURL headers:requestHeaders path:requestPath query:requestQuery];
          GWS_DCHECK(self->_request);
          [self abortRequest:self->_request withStatusCode:kGCDWebServerHTTPStatusCode_NotImplemented];
        }
      } else {
        [self abortRequest:nil withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
        GWS_DNOT_REACHED();
      }
    } else {
      [self abortRequest:nil withStatusCode:kGCDWebServerHTTPStatusCode_InternalServerError];
    }
  }];
}

- (instancetype)initWithServer:(GCDWebServer*)server localAddress:(NSData*)localAddress remoteAddress:(NSData*)remoteAddress socket:(CFSocketNativeHandle)socket {
  if ((self = [super init])) {
    _server = server;
    _localAddressData = localAddress;
    _remoteAddressData = remoteAddress;
    _socket = socket;
    GWS_LOG_DEBUG(@"Did open connection on socket %i", _socket);
    
    [_server willStartConnection:self];
    
    if (![self open]) {
      close(_socket);
      return nil;
    }
    _opened = YES;
    
    // 一次连接的处理.
    [self _readRequestHeaders];
  }
  return self;
}

- (NSString*)localAddressString {
  return GCDWebServerStringFromSockAddr(_localAddressData.bytes, YES);
}

- (NSString*)remoteAddressString {
  return GCDWebServerStringFromSockAddr(_remoteAddressData.bytes, YES);
}

- (void)dealloc {
  int result = close(_socket);
  if (result != 0) {
    GWS_LOG_ERROR(@"Failed closing socket %i for connection: %s (%i)", _socket, strerror(errno), errno);
  } else {
    GWS_LOG_DEBUG(@"Did close connection on socket %i", _socket);
  }
  
  if (_opened) {
    [self close];
  }
  
  [_server didEndConnection:self];
  
  if (_requestMessage) {
    CFRelease(_requestMessage);
  }
  
  if (_responseMessage) {
    CFRelease(_responseMessage);
  }
}

@end

@implementation GCDWebServerConnection (Read)

- (void)readData:(NSMutableData*)data withLength:(NSUInteger)length completionBlock:(ReadDataCompletionBlock)block {
  dispatch_read(_socket, length, dispatch_get_global_queue(_server.dispatchQueuePriority, 0), ^(dispatch_data_t buffer, int error) {
    @autoreleasepool {
      if (error == 0) {
        size_t size = dispatch_data_get_size(buffer);
        if (size > 0) {
          NSUInteger originalLength = data.length;
          dispatch_data_apply(buffer, ^bool(dispatch_data_t region, size_t chunkOffset, const void* chunkBytes, size_t chunkSize) {
            [data appendBytes:chunkBytes length:chunkSize];
            return true;
          });
          [self didReadBytes:((char*)data.bytes + originalLength) length:(data.length - originalLength)];
          block(YES);
        } else {
          if (self->_totalBytesRead > 0) {
            GWS_LOG_ERROR(@"No more data available on socket %i", self->_socket);
          } else {
            GWS_LOG_WARNING(@"No data received from socket %i", self->_socket);
          }
          block(NO);
        }
      } else {
        GWS_LOG_ERROR(@"Error while reading from socket %i: %s (%i)", self->_socket, strerror(error), error);
        block(NO);
      }
    }
  });
}

- (void)readHeaders:(NSMutableData*)headersData withCompletionBlock:(ReadHeadersCompletionBlock)block {
  GWS_DCHECK(_requestMessage);
  [self readData:headersData
      withLength:NSUIntegerMax
 completionBlock:^(BOOL success) {
    if (success) {
      NSRange range = [headersData rangeOfData:_CRLFCRLFData options:0 range:NSMakeRange(0, headersData.length)];
      // 这里判断, 是否出现了请求行和请求体之间的间隔, 如果出现了, 至少可以认为请求头已经结束了.
      if (range.location == NSNotFound) {
        // 没有出现, 递归调用, 收集请求头的数据.
        [self readHeaders:headersData withCompletionBlock:block];
      } else {
        NSUInteger length = range.location + range.length;
        if (CFHTTPMessageAppendBytes(self->_requestMessage, headersData.bytes, length)) {
          if (CFHTTPMessageIsHeaderComplete(self->_requestMessage)) {
            block([headersData subdataWithRange:NSMakeRange(length, headersData.length - length)]);
          } else {
            GWS_LOG_ERROR(@"Failed parsing request headers from socket %i", self->_socket);
            block(nil);
          }
        } else {
          GWS_LOG_ERROR(@"Failed appending request headers data from socket %i", self->_socket);
          block(nil);
        }
      }
    } else {
      block(nil);
    }
  }];
}

- (void)readBodyWithRemainingLength:(NSUInteger)length completionBlock:(ReadBodyCompletionBlock)block {
  GWS_DCHECK([_request hasBody] && ![_request usesChunkedTransferEncoding]);
  NSMutableData* bodyData = [[NSMutableData alloc] initWithCapacity:kBodyReadCapacity];
  [self readData:bodyData
      withLength:length
 completionBlock:^(BOOL success) {
    if (success) {
      if (bodyData.length <= length) {
        NSError* error = nil;
        if ([self->_request performWriteData:bodyData error:&error]) {
          NSUInteger remainingLength = length - bodyData.length;
          if (remainingLength) {
            [self readBodyWithRemainingLength:remainingLength completionBlock:block];
          } else {
            block(YES);
          }
        } else {
          GWS_LOG_ERROR(@"Failed writing request body on socket %i: %@", self->_socket, error);
          block(NO);
        }
      } else {
        GWS_LOG_ERROR(@"Unexpected extra content reading request body on socket %i", self->_socket);
        block(NO);
        GWS_DNOT_REACHED();
      }
    } else {
      block(NO);
    }
  }];
}

static inline NSUInteger _ScanHexNumber(const void* bytes, NSUInteger size) {
  char buffer[size + 1];
  bcopy(bytes, buffer, size);
  buffer[size] = 0;
  char* end = NULL;
  long result = strtol(buffer, &end, 16);
  return ((end != NULL) && (*end == 0) && (result >= 0) ? result : NSNotFound);
}

- (void)readNextBodyChunk:(NSMutableData*)chunkData completionBlock:(ReadBodyCompletionBlock)block {
  GWS_DCHECK([_request hasBody] && [_request usesChunkedTransferEncoding]);
  
  while (1) {
    NSRange range = [chunkData rangeOfData:_CRLFData options:0 range:NSMakeRange(0, chunkData.length)];
    if (range.location == NSNotFound) {
      break;
    }
    NSRange extensionRange = [chunkData rangeOfData:[NSData dataWithBytes:";" length:1] options:0 range:NSMakeRange(0, range.location)];  // Ignore chunk extensions
    NSUInteger length = _ScanHexNumber((char*)chunkData.bytes, extensionRange.location != NSNotFound ? extensionRange.location : range.location);
    if (length != NSNotFound) {
      if (length) {
        if (chunkData.length < range.location + range.length + length + 2) {
          break;
        }
        const char* ptr = (char*)chunkData.bytes + range.location + range.length + length;
        if ((*ptr == '\r') && (*(ptr + 1) == '\n')) {
          NSError* error = nil;
          if ([_request performWriteData:[chunkData subdataWithRange:NSMakeRange(range.location + range.length, length)] error:&error]) {
            [chunkData replaceBytesInRange:NSMakeRange(0, range.location + range.length + length + 2) withBytes:NULL length:0];
          } else {
            GWS_LOG_ERROR(@"Failed writing request body on socket %i: %@", _socket, error);
            block(NO);
            return;
          }
        } else {
          GWS_LOG_ERROR(@"Missing terminating CRLF sequence for chunk reading request body on socket %i", _socket);
          block(NO);
          return;
        }
      } else {
        NSRange trailerRange = [chunkData rangeOfData:_CRLFCRLFData options:0 range:NSMakeRange(range.location, chunkData.length - range.location)];  // Ignore trailers
        if (trailerRange.location != NSNotFound) {
          block(YES);
          return;
        }
      }
    } else {
      GWS_LOG_ERROR(@"Invalid chunk length reading request body on socket %i", _socket);
      block(NO);
      return;
    }
  }
  
  [self readData:chunkData
      withLength:NSUIntegerMax
 completionBlock:^(BOOL success) {
    if (success) {
      [self readNextBodyChunk:chunkData completionBlock:block];
    } else {
      block(NO);
    }
  }];
}

@end

@implementation GCDWebServerConnection (Write)

- (void)writeData:(NSData*)data withCompletionBlock:(WriteDataCompletionBlock)block {
  dispatch_data_t buffer = dispatch_data_create(data.bytes, data.length, dispatch_get_global_queue(_server.dispatchQueuePriority, 0), ^{
    [data self];  // Keeps ARC from releasing data too early
  });
  dispatch_write(_socket, buffer, dispatch_get_global_queue(_server.dispatchQueuePriority, 0), ^(dispatch_data_t remainingData, int error) {
    @autoreleasepool {
      if (error == 0) {
        GWS_DCHECK(remainingData == NULL);
        [self didWriteBytes:data.bytes length:data.length];
        block(YES);
      } else {
        GWS_LOG_ERROR(@"Error while writing to socket %i: %s (%i)", self->_socket, strerror(error), error);
        block(NO);
      }
    }
  });
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(buffer);
#endif
}

- (void)writeHeadersWithCompletionBlock:(WriteHeadersCompletionBlock)block {
  GWS_DCHECK(_responseMessage);
  CFDataRef data = CFHTTPMessageCopySerializedMessage(_responseMessage);
  [self writeData:(__bridge NSData*)data withCompletionBlock:block];
  CFRelease(data);
}

- (void)writeBodyWithCompletionBlock:(WriteBodyCompletionBlock)block {
  GWS_DCHECK([_response hasBody]);
  [_response performReadDataWithCompletion:^(NSData* data, NSError* error) {
    if (data) {
      if (data.length) {
        if (self->_response.usesChunkedTransferEncoding) {
          const char* hexString = [[NSString stringWithFormat:@"%lx", (unsigned long)data.length] UTF8String];
          size_t hexLength = strlen(hexString);
          NSData* chunk = [NSMutableData dataWithLength:(hexLength + 2 + data.length + 2)];
          if (chunk == nil) {
            GWS_LOG_ERROR(@"Failed allocating memory for response body chunk for socket %i: %@", self->_socket, error);
            block(NO);
            return;
          }
          char* ptr = (char*)[(NSMutableData*)chunk mutableBytes];
          bcopy(hexString, ptr, hexLength);
          ptr += hexLength;
          *ptr++ = '\r';
          *ptr++ = '\n';
          bcopy(data.bytes, ptr, data.length);
          ptr += data.length;
          *ptr++ = '\r';
          *ptr = '\n';
          data = chunk;
        }
        [self writeData:data
    withCompletionBlock:^(BOOL success) {
          if (success) {
            [self writeBodyWithCompletionBlock:block];
          } else {
            block(NO);
          }
        }];
      } else {
        if (self->_response.usesChunkedTransferEncoding) {
          [self writeData:_lastChunkData
      withCompletionBlock:^(BOOL success) {
            block(success);
          }];
        } else {
          block(YES);
        }
      }
    } else {
      GWS_LOG_ERROR(@"Failed reading response body for socket %i: %@", self->_socket, error);
      block(NO);
    }
  }];
}

@end

@implementation GCDWebServerConnection (Subclassing)

- (BOOL)open {
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
  if (_server.recordingEnabled) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _connectionIndex = OSAtomicIncrement32(&_connectionCounter);
#pragma clang diagnostic pop
    // 日志记录, 应该就是这回事.
    // 在合适的地方, 进行相关数据的写入.
    _requestPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    _requestFD = open([_requestPath fileSystemRepresentation], O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    GWS_DCHECK(_requestFD > 0);
    
    _responsePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    _responseFD = open([_responsePath fileSystemRepresentation], O_CREAT | O_TRUNC | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    GWS_DCHECK(_responseFD > 0);
  }
#endif
  
  return YES;
}

- (void)didReadBytes:(const void*)bytes length:(NSUInteger)length {
  GWS_LOG_DEBUG(@"Connection received %lu bytes on socket %i", (unsigned long)length, _socket);
  _totalBytesRead += length;
  
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
  // 如果设置了存储, 那么就将请求的数据, 写入到文件系统里面.
  if ((_requestFD > 0) && (write(_requestFD, bytes, length) != (ssize_t)length)) {
    GWS_LOG_ERROR(@"Failed recording request data: %s (%i)", strerror(errno), errno);
    close(_requestFD);
    _requestFD = 0;
  }
#endif
}

- (void)didWriteBytes:(const void*)bytes length:(NSUInteger)length {
  GWS_LOG_DEBUG(@"Connection sent %lu bytes on socket %i", (unsigned long)length, _socket);
  _totalBytesWritten += length;
  
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
  // 如果记录, 那么就将相关的数据, 写到文件系统里面.
  if ((_responseFD > 0) && (write(_responseFD, bytes, length) != (ssize_t)length)) {
    GWS_LOG_ERROR(@"Failed recording response data: %s (%i)", strerror(errno), errno);
    close(_responseFD);
    _responseFD = 0;
  }
#endif
}

- (NSURL*)rewriteRequestURL:(NSURL*)url withMethod:(NSString*)method headers:(NSDictionary<NSString*, NSString*>*)headers {
  return url;
}

// https://tools.ietf.org/html/rfc2617
- (GCDWebServerResponse*)preflightRequest:(GCDWebServerRequest*)request {
  GCDWebServerResponse* response = nil;
  if (_server.authenticationBasicAccounts) {
    __block BOOL authenticated = NO;
    NSString* authorizationHeader = [request.headers objectForKey:@"Authorization"];
    if ([authorizationHeader hasPrefix:@"Basic "]) {
      NSString* basicAccount = [authorizationHeader substringFromIndex:6];
      [_server.authenticationBasicAccounts enumerateKeysAndObjectsUsingBlock:^(NSString* username, NSString* digest, BOOL* stop) {
        if ([basicAccount isEqualToString:digest]) {
          authenticated = YES;
          *stop = YES;
        }
      }];
    }
    if (!authenticated) {
      response = [GCDWebServerResponse responseWithStatusCode:kGCDWebServerHTTPStatusCode_Unauthorized];
      [response setValue:[NSString stringWithFormat:@"Basic realm=\"%@\"", _server.authenticationRealm] forAdditionalHeader:@"WWW-Authenticate"];
    }
  } else if (_server.authenticationDigestAccounts) {
    BOOL authenticated = NO;
    BOOL isStaled = NO;
    NSString* authorizationHeader = [request.headers objectForKey:@"Authorization"];
    if ([authorizationHeader hasPrefix:@"Digest "]) {
      NSString* realm = GCDWebServerExtractHeaderValueParameter(authorizationHeader, @"realm");
      if (realm && [_server.authenticationRealm isEqualToString:realm]) {
        NSString* nonce = GCDWebServerExtractHeaderValueParameter(authorizationHeader, @"nonce");
        if ([nonce isEqualToString:_digestAuthenticationNonce]) {
          NSString* username = GCDWebServerExtractHeaderValueParameter(authorizationHeader, @"username");
          NSString* uri = GCDWebServerExtractHeaderValueParameter(authorizationHeader, @"uri");
          NSString* actualResponse = GCDWebServerExtractHeaderValueParameter(authorizationHeader, @"response");
          NSString* ha1 = [_server.authenticationDigestAccounts objectForKey:username];
          NSString* ha2 = GCDWebServerComputeMD5Digest(@"%@:%@", request.method, uri);  // We cannot use "request.path" as the query string is required
          NSString* expectedResponse = GCDWebServerComputeMD5Digest(@"%@:%@:%@", ha1, _digestAuthenticationNonce, ha2);
          if ([actualResponse isEqualToString:expectedResponse]) {
            authenticated = YES;
          }
        } else if (nonce.length) {
          isStaled = YES;
        }
      }
    }
    if (!authenticated) {
      response = [GCDWebServerResponse responseWithStatusCode:kGCDWebServerHTTPStatusCode_Unauthorized];
      [response setValue:[NSString stringWithFormat:@"Digest realm=\"%@\", nonce=\"%@\"%@", _server.authenticationRealm, _digestAuthenticationNonce, isStaled ? @", stale=TRUE" : @""] forAdditionalHeader:@"WWW-Authenticate"];  // TODO: Support Quality of Protection ("qop")
    }
  }
  return response;
}

- (void)processRequest:(GCDWebServerRequest*)request completion:(GCDWebServerCompletionBlock)completion {
  GWS_LOG_DEBUG(@"Connection on socket %i processing request \"%@ %@\" with %lu bytes body", _socket, _virtualHEAD ? @"HEAD" : _request.method, _request.path, (unsigned long)_totalBytesRead);
  // 具体的 Request 应该怎么处理, 是放到各个 _handler 里面了.
  _handler.asyncProcessBlock(request, [completion copy]);
}

// http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.25
// http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.26
static inline BOOL _CompareResources(NSString* responseETag, NSString* requestETag, NSDate* responseLastModified, NSDate* requestLastModified) {
  if (requestLastModified && responseLastModified) {
    if ([responseLastModified compare:requestLastModified] != NSOrderedDescending) {
      return YES;
    }
  }
  if (requestETag && responseETag) {  // Per the specs "If-None-Match" must be checked after "If-Modified-Since"
    if ([requestETag isEqualToString:@"*"]) {
      return YES;
    }
    if ([responseETag isEqualToString:requestETag]) {
      return YES;
    }
  }
  return NO;
}

- (GCDWebServerResponse*)overrideResponse:(GCDWebServerResponse*)response forRequest:(GCDWebServerRequest*)request {
  if ((response.statusCode >= 200) && (response.statusCode < 300) && _CompareResources(response.eTag, request.ifNoneMatch, response.lastModifiedDate, request.ifModifiedSince)) {
    NSInteger code = [request.method isEqualToString:@"HEAD"] || [request.method isEqualToString:@"GET"] ? kGCDWebServerHTTPStatusCode_NotModified : kGCDWebServerHTTPStatusCode_PreconditionFailed;
    GCDWebServerResponse* newResponse = [GCDWebServerResponse responseWithStatusCode:code];
    newResponse.cacheControlMaxAge = response.cacheControlMaxAge;
    newResponse.lastModifiedDate = response.lastModifiedDate;
    newResponse.eTag = response.eTag;
    GWS_DCHECK(newResponse);
    return newResponse;
  }
  return response;
}

// 将, 所有的失败集中到一起了.
- (void)abortRequest:(GCDWebServerRequest*)request withStatusCode:(NSInteger)statusCode {
  GWS_DCHECK(_responseMessage == NULL);
  GWS_DCHECK((statusCode >= 400) && (statusCode < 600));
  [self _initializeResponseHeadersWithStatusCode:statusCode];
  [self writeHeadersWithCompletionBlock:^(BOOL success){
    // Nothing more to do
  }];
  GWS_LOG_DEBUG(@"Connection aborted with status code %i on socket %i", (int)statusCode, _socket);
}

- (void)close {
#ifdef __GCDWEBSERVER_ENABLE_TESTING__
  if (_requestPath) {
    BOOL success = NO;
    NSError* error = nil;
    if (_requestFD > 0) {
      close(_requestFD);
      NSString* name = [NSString stringWithFormat:@"%03lu-%@.request", (unsigned long)_connectionIndex, _virtualHEAD ? @"HEAD" : _request.method];
      success = [[NSFileManager defaultManager] moveItemAtPath:_requestPath toPath:[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:name] error:&error];
    }
    if (!success) {
      GWS_LOG_ERROR(@"Failed saving recorded request: %@", error);
      GWS_DNOT_REACHED();
    }
    unlink([_requestPath fileSystemRepresentation]);
  }
  
  if (_responsePath) {
    BOOL success = NO;
    NSError* error = nil;
    if (_responseFD > 0) {
      close(_responseFD);
      NSString* name = [NSString stringWithFormat:@"%03lu-%i.response", (unsigned long)_connectionIndex, (int)_statusCode];
      success = [[NSFileManager defaultManager] moveItemAtPath:_responsePath toPath:[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:name] error:&error];
    }
    if (!success) {
      GWS_LOG_ERROR(@"Failed saving recorded response: %@", error);
      GWS_DNOT_REACHED();
    }
    unlink([_responsePath fileSystemRepresentation]);
  }
#endif
  
  if (_request) {
    GWS_LOG_VERBOSE(@"[%@] %@ %i \"%@ %@\" (%lu | %lu)", self.localAddressString, self.remoteAddressString, (int)_statusCode, _virtualHEAD ? @"HEAD" : _request.method, _request.path, (unsigned long)_totalBytesRead, (unsigned long)_totalBytesWritten);
  } else {
    GWS_LOG_VERBOSE(@"[%@] %@ %i \"(invalid request)\" (%lu | %lu)", self.localAddressString, self.remoteAddressString, (int)_statusCode, (unsigned long)_totalBytesRead, (unsigned long)_totalBytesWritten);
  }
}

@end
