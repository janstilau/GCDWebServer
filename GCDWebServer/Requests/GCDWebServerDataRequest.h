#import "GCDWebServerRequest.h"

NS_ASSUME_NONNULL_BEGIN

/*
 *  The GCDWebServerDataRequest subclass of GCDWebServerRequest stores the body
 *  of the HTTP request in memory.
 */
// GCDWebServerDataRequest 大部分的能力, 是复用 GCDWebServerRequest 的. 只是 GCDWebServerBodyWriter 的相关实现, 变为了内存 NSMutableData 的拼接.
@interface GCDWebServerDataRequest : GCDWebServerRequest

/**
 *  Returns the data for the request body.
 */
@property(nonatomic, readonly) NSData* data;

@end

@interface GCDWebServerDataRequest (Extensions)

/*
 *  Returns the data for the request body interpreted as text. If the content
 *  type of the body is not a text one, or if an error occurs, nil is returned.
 *
 *  The text encoding used to interpret the data is extracted from the
 *  "Content-Type" header or defaults to UTF-8.
 */
@property(nonatomic, readonly, nullable) NSString* text;

/*
 *  Returns the data for the request body interpreted as a JSON object. If the
 *  content type of the body is not JSON, or if an error occurs, nil is returned.
 */
@property(nonatomic, readonly, nullable) id jsonObject;

@end

NS_ASSUME_NONNULL_END
