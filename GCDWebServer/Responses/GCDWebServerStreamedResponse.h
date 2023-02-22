#import "GCDWebServerResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The GCDWebServerStreamBlock is called to stream the data for the HTTP body.
 *  The block must return either a chunk of data, an empty NSData when done, or
 *  nil on error and set the "error" argument which is guaranteed to be non-NULL.
 */
typedef NSData* _Nullable (^GCDWebServerStreamBlock)(NSError** error);

/**
 *  The GCDWebServerAsyncStreamBlock works like the GCDWebServerStreamBlock
 *  except the streamed data can be returned at a later time allowing for
 *  truly asynchronous generation of the data.
 *
 *  The block must call "completionBlock" passing the new chunk of data when ready,
 *  an empty NSData when done, or nil on error and pass a NSError.
 *
 *  The block cannot call "completionBlock" more than once per invocation.
 */
typedef void (^GCDWebServerAsyncStreamBlock)(GCDWebServerBodyReaderCompletionBlock completionBlock);

/**
 *  The GCDWebServerStreamedResponse subclass of GCDWebServerResponse streams
 *  the body of the HTTP response using a GCD block.
 */
@interface GCDWebServerStreamedResponse : GCDWebServerResponse
@property(nonatomic, copy) NSString* contentType;  // Redeclare as non-null

/**
 *  Creates a response with streamed data and a given content type.
 */
+ (instancetype)responseWithContentType:(NSString*)type streamBlock:(GCDWebServerStreamBlock)block;

/**
 *  Creates a response with async streamed data and a given content type.
 */
+ (instancetype)responseWithContentType:(NSString*)type asyncStreamBlock:(GCDWebServerAsyncStreamBlock)block;

/**
 *  Initializes a response with streamed data and a given content type.
 */
- (instancetype)initWithContentType:(NSString*)type streamBlock:(GCDWebServerStreamBlock)block;

/**
 *  This method is the designated initializer for the class.
 */
- (instancetype)initWithContentType:(NSString*)type asyncStreamBlock:(GCDWebServerAsyncStreamBlock)block;

@end

NS_ASSUME_NONNULL_END
