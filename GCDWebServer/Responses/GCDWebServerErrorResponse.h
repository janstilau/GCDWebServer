#import "GCDWebServerDataResponse.h"
#import "GCDWebServerHTTPStatusCodes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The GCDWebServerDataResponse subclass of GCDWebServerDataResponse generates
 *  an HTML body from an HTTP status code and an error message.
 */
@interface GCDWebServerErrorResponse : GCDWebServerDataResponse

/**
 *  Creates a client error response with the corresponding HTTP status code.
 */
+ (instancetype)responseWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 *  Creates a server error response with the corresponding HTTP status code.
 */
+ (instancetype)responseWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 *  Creates a client error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
+ (instancetype)responseWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4);

/**
 *  Creates a server error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
+ (instancetype)responseWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4);

/**
 *  Initializes a client error response with the corresponding HTTP status code.
 */
- (instancetype)initWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 *  Initializes a server error response with the corresponding HTTP status code.
 */
- (instancetype)initWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode message:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 *  Initializes a client error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
- (instancetype)initWithClientError:(GCDWebServerClientErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4);

/**
 *  Initializes a server error response with the corresponding HTTP status code
 *  and an underlying NSError.
 */
- (instancetype)initWithServerError:(GCDWebServerServerErrorHTTPStatusCode)errorCode underlyingError:(nullable NSError*)underlyingError message:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4);

@end

NS_ASSUME_NONNULL_END
