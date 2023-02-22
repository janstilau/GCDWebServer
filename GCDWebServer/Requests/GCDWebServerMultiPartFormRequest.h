#import "GCDWebServerRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The GCDWebServerMultiPart class is an abstract class that wraps the content
 *  of a part.
 */
@interface GCDWebServerMultiPart : NSObject

/**
 *  Returns the control name retrieved from the part headers.
 */
@property(nonatomic, readonly) NSString* controlName;

/**
 *  Returns the content type retrieved from the part headers or "text/plain"
 *  if not available (per HTTP specifications).
 */
@property(nonatomic, readonly) NSString* contentType;

/**
 *  Returns the MIME type component of the content type for the part.
 */
@property(nonatomic, readonly) NSString* mimeType;

@end

/**
 *  The GCDWebServerMultiPartArgument subclass of GCDWebServerMultiPart wraps
 *  the content of a part as data in memory.
 */
@interface GCDWebServerMultiPartArgument : GCDWebServerMultiPart

/**
 *  Returns the data for the part.
 */
@property(nonatomic, readonly) NSData* data;

/**
 *  Returns the data for the part interpreted as text. If the content
 *  type of the part is not a text one, or if an error occurs, nil is returned.
 *
 *  The text encoding used to interpret the data is extracted from the
 *  "Content-Type" header or defaults to UTF-8.
 */
@property(nonatomic, readonly, nullable) NSString* string;

@end

/**
 *  The GCDWebServerMultiPartFile subclass of GCDWebServerMultiPart wraps
 *  the content of a part as a file on disk.
 */
@interface GCDWebServerMultiPartFile : GCDWebServerMultiPart

/**
 *  Returns the file name retrieved from the part headers.
 */
@property(nonatomic, readonly) NSString* fileName;

/**
 *  Returns the path to the temporary file containing the part data.
 *
 *  @warning This temporary file will be automatically deleted when the
 *  GCDWebServerMultiPartFile is deallocated. If you want to preserve this file,
 *  you must move it to a different location beforehand.
 */
@property(nonatomic, readonly) NSString* temporaryPath;

@end

/**
 *  The GCDWebServerMultiPartFormRequest subclass of GCDWebServerRequest
 *  parses the body of the HTTP request as a multipart encoded form.
 */
@interface GCDWebServerMultiPartFormRequest : GCDWebServerRequest

/**
 *  Returns the argument parts from the multipart encoded form as
 *  name / GCDWebServerMultiPartArgument pairs.
 */
@property(nonatomic, readonly) NSArray<GCDWebServerMultiPartArgument*>* arguments;

/**
 *  Returns the files parts from the multipart encoded form as
 *  name / GCDWebServerMultiPartFile pairs.
 */
@property(nonatomic, readonly) NSArray<GCDWebServerMultiPartFile*>* files;

/**
 *  Returns the MIME type for multipart encoded forms
 *  i.e. "multipart/form-data".
 */
+ (NSString*)mimeType;

/**
 *  Returns the first argument for a given control name or nil if not found.
 */
- (nullable GCDWebServerMultiPartArgument*)firstArgumentForControlName:(NSString*)name;

/**
 *  Returns the first file for a given control name or nil if not found.
 */
- (nullable GCDWebServerMultiPartFile*)firstFileForControlName:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
