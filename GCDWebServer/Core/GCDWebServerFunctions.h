#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 *  Converts a file extension to the corresponding MIME type.
 *  If there is no match, "application/octet-stream" is returned.
 *
 *  Overrides allow to customize the built-in mapping from extensions to MIME
 *  types. Keys of the dictionary must be lowercased file extensions without
 *  the period, and the values must be the corresponding MIME types.
 */
NSString* GCDWebServerGetMimeTypeForExtension(NSString* extension, NSDictionary<NSString*, NSString*>* _Nullable overrides);

/**
 *  Add percent-escapes to a string so it can be used in a URL.
 *  The legal characters ":@/?&=+" are also escaped to ensure compatibility
 *  with URL encoded forms and URL queries.
 */
NSString* _Nullable GCDWebServerEscapeURLString(NSString* string);

/**
 *  Unescapes a URL percent-encoded string.
 */
NSString* _Nullable GCDWebServerUnescapeURLString(NSString* string);

/**
 *  Extracts the unescaped names and values from an
 *  "application/x-www-form-urlencoded" form.
 *  http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4.1
 */
NSDictionary<NSString*, NSString*>* GCDWebServerParseURLEncodedForm(NSString* form);

/**
 *  On OS X, returns the IPv4 or IPv6 address as a string of the primary
 *  connected service or nil if not available.
 *
 *  On iOS, returns the IPv4 or IPv6 address as a string of the WiFi
 *  interface if connected or nil otherwise.
 */
NSString* _Nullable GCDWebServerGetPrimaryIPAddress(BOOL useIPv6);

/**
 *  Converts a date into a string using RFC822 formatting.
 *  https://tools.ietf.org/html/rfc822#section-5
 *  https://tools.ietf.org/html/rfc1123#section-5.2.14
 */
NSString* GCDWebServerFormatRFC822(NSDate* date);

/**
 *  Converts a RFC822 formatted string into a date.
 *  https://tools.ietf.org/html/rfc822#section-5
 *  https://tools.ietf.org/html/rfc1123#section-5.2.14
 *
 *  @warning Timezones other than GMT are not supported by this function.
 */
NSDate* _Nullable GCDWebServerParseRFC822(NSString* string);

/**
 *  Converts a date into a string using IOS 8601 formatting.
 *  http://tools.ietf.org/html/rfc3339#section-5.6
 */
NSString* GCDWebServerFormatISO8601(NSDate* date);

/**
 *  Converts a ISO 8601 formatted string into a date.
 *  http://tools.ietf.org/html/rfc3339#section-5.6
 *
 *  @warning Only "calendar" variant is supported at this time and timezones
 *  other than GMT are not supported either.
 */
NSDate* _Nullable GCDWebServerParseISO8601(NSString* string);

/**
 *  Removes "//", "/./" and "/../" components from path as well as any trailing slash.
 */
NSString* GCDWebServerNormalizePath(NSString* path);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
