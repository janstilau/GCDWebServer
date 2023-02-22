#import "GCDWebServerDataRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The GCDWebServerURLEncodedFormRequest subclass of GCDWebServerRequest
 *  parses the body of the HTTP request as a URL encoded form using
 *  GCDWebServerParseURLEncodedForm().
 */
@interface GCDWebServerURLEncodedFormRequest : GCDWebServerDataRequest

/**
 *  Returns the unescaped control names and values for the URL encoded form.
 *
 *  The text encoding used to interpret the data is extracted from the
 *  "Content-Type" header or defaults to UTF-8.
 */
@property(nonatomic, readonly) NSDictionary<NSString*, NSString*>* arguments;

/**
 *  Returns the MIME type for URL encoded forms
 *  i.e. "application/x-www-form-urlencoded".
 */
+ (NSString*)mimeType;

@end

NS_ASSUME_NONNULL_END
