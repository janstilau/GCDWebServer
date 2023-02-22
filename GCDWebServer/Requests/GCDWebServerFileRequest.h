#import "GCDWebServerRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The GCDWebServerFileRequest subclass of GCDWebServerRequest stores the body
 *  of the HTTP request to a file on disk.
 */
@interface GCDWebServerFileRequest : GCDWebServerRequest

/**
 *  Returns the path to the temporary file containing the request body.
 *
 *  @warning This temporary file will be automatically deleted when the
 *  GCDWebServerFileRequest is deallocated. If you want to preserve this file,
 *  you must move it to a different location beforehand.
 */
@property(nonatomic, readonly) NSString* temporaryPath;

@end

NS_ASSUME_NONNULL_END
