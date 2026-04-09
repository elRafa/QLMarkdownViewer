import Foundation
import QuickLook

@_cdecl("GenerateThumbnailForURL_Swift")
public func generateThumbnail(
    thisInterface: UnsafeMutableRawPointer?,
    thumbnail: QLThumbnailRequest,
    url: CFURL,
    contentTypeUTI: CFString?,
    options: CFDictionary?
) -> OSStatus {
    return OSStatus(noErr)
}
