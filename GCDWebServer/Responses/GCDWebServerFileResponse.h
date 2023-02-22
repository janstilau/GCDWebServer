#import "GCDWebServerResponse.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The GCDWebServerFileResponse subclass of GCDWebServerResponse reads the body
 *  of the HTTP response from a file on disk.
 *
 *  It will automatically set the contentType, lastModifiedDate and eTag
 *  properties of the GCDWebServerResponse according to the file extension and
 *  metadata.
 */
@interface GCDWebServerFileResponse : GCDWebServerResponse
@property(nonatomic, copy) NSString* contentType;  // Redeclare as non-null
@property(nonatomic) NSDate* lastModifiedDate;  // Redeclare as non-null
@property(nonatomic, copy) NSString* eTag;  // Redeclare as non-null

/**
 *  Creates a response with the contents of a file.
 */
+ (nullable instancetype)responseWithFile:(NSString*)path;

/**
 *  Creates a response like +responseWithFile: and sets the "Content-Disposition"
 *  HTTP header for a download if the "attachment" argument is YES.
 */
+ (nullable instancetype)responseWithFile:(NSString*)path isAttachment:(BOOL)attachment;

/**
 *  Creates a response like +responseWithFile: but restricts the file contents
 *  to a specific byte range.
 *
 *  See -initWithFile:byteRange: for details.
 */
+ (nullable instancetype)responseWithFile:(NSString*)path byteRange:(NSRange)range;

/**
 *  Creates a response like +responseWithFile:byteRange: and sets the
 *  "Content-Disposition" HTTP header for a download if the "attachment"
 *  argument is YES.
 */
+ (nullable instancetype)responseWithFile:(NSString*)path byteRange:(NSRange)range isAttachment:(BOOL)attachment;

/**
 *  Initializes a response with the contents of a file.
 */
- (nullable instancetype)initWithFile:(NSString*)path;

/**
 *  Initializes a response like +responseWithFile: and sets the
 *  "Content-Disposition" HTTP header for a download if the "attachment"
 *  argument is YES.
 */
- (nullable instancetype)initWithFile:(NSString*)path isAttachment:(BOOL)attachment;

/**
 *  Initializes a response like -initWithFile: but restricts the file contents
 *  to a specific byte range. This range should be set to (NSUIntegerMax, 0) for
 *  the full file, (offset, length) if expressed from the beginning of the file,
 *  or (NSUIntegerMax, length) if expressed from the end of the file. The "offset"
 *  and "length" values will be automatically adjusted to be compatible with the
 *  actual size of the file.
 *
 *  This argument would typically be set to the value of the byteRange property
 *  of the current GCDWebServerRequest.
 */
- (nullable instancetype)initWithFile:(NSString*)path byteRange:(NSRange)range;

/**
 *  This method is the designated initializer for the class.
 *
 *  If MIME type overrides are specified, they allow to customize the built-in
 *  mapping from extensions to MIME types. Keys of the dictionary must be lowercased
 *  file extensions without the period, and the values must be the corresponding
 *  MIME types.
 */
- (nullable instancetype)initWithFile:(NSString*)path byteRange:(NSRange)range isAttachment:(BOOL)attachment mimeTypeOverrides:(nullable NSDictionary<NSString*, NSString*>*)overrides;

@end

NS_ASSUME_NONNULL_END
