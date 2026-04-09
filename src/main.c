#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

// Forward declarations for Swift functions (linked via @_cdecl)
extern OSStatus GeneratePreviewForURL_Swift(void *thisInterface,
                                            QLPreviewRequestRef preview,
                                            CFURLRef url,
                                            CFStringRef contentTypeUTI,
                                            CFDictionaryRef options);

extern OSStatus GenerateThumbnailForURL_Swift(void *thisInterface,
                                              QLThumbnailRequestRef thumbnail,
                                              CFURLRef url,
                                              CFStringRef contentTypeUTI,
                                              CFDictionaryRef options);

// Our unique factory UUID — must match Info.plist CFPlugInFactories key
#define PLUGIN_ID CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("CE2A5E78-DA56-4FE5-A837-4DA5D1E0753C"))

// Standard QL generator type UUID (same for all QL generators)
#define QL_GENERATOR_TYPE CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("5E2D9680-5022-40FA-B806-43349622E5B9"))

// Plugin instance structure
typedef struct {
    void *conduitInterface;
    CFUUIDRef factoryID;
    UInt32 refCount;
} QuickLookGeneratorPluginType;

// Forward declarations
static QuickLookGeneratorPluginType *AllocQuickLookGeneratorPluginType(CFUUIDRef inFactoryID);
static void DeallocQuickLookGeneratorPluginType(QuickLookGeneratorPluginType *thisInstance);
static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG AddRef(void *thisInstance);
static ULONG Release(void *thisInstance);

// IUnknown vtable + QL callbacks
static QLGeneratorInterfaceStruct myInterfaceFtbl = {
    NULL,                              // padding (reserved)
    QueryInterface,                    // QueryInterface
    AddRef,                           // AddRef
    Release,                          // Release
    NULL,                             // GenerateThumbnailForURL (unused; see GenerateThumbnailForURL_Swift)
    NULL,                             // CancelThumbnailGeneration
    GeneratePreviewForURL_Swift,      // GeneratePreviewForURL
    NULL                              // CancelPreviewGeneration
};

// Allocate a new plugin instance
static QuickLookGeneratorPluginType *AllocQuickLookGeneratorPluginType(CFUUIDRef inFactoryID) {
    QuickLookGeneratorPluginType *theNewInstance = (QuickLookGeneratorPluginType *)malloc(sizeof(QuickLookGeneratorPluginType));
    memset(theNewInstance, 0, sizeof(QuickLookGeneratorPluginType));
    theNewInstance->conduitInterface = &myInterfaceFtbl;
    theNewInstance->factoryID = CFRetain(inFactoryID);
    CFPlugInAddInstanceForFactory(inFactoryID);
    theNewInstance->refCount = 1;
    return theNewInstance;
}

// Deallocate plugin instance
static void DeallocQuickLookGeneratorPluginType(QuickLookGeneratorPluginType *thisInstance) {
    CFUUIDRef theFactoryID = thisInstance->factoryID;
    free(thisInstance);
    if (theFactoryID) {
        CFPlugInRemoveInstanceForFactory(theFactoryID);
        CFRelease(theFactoryID);
    }
}

// IUnknown::QueryInterface
static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv) {
    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
    if (CFEqual(interfaceID, kQLGeneratorCallbacksInterfaceID)) {
        ((QuickLookGeneratorPluginType *)thisInstance)->conduitInterface =  &myInterfaceFtbl;
        AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
    }
    if (CFEqual(interfaceID, IUnknownUUID)) {
        ((QuickLookGeneratorPluginType *)thisInstance)->conduitInterface = &myInterfaceFtbl;
        AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
    }
    *ppv = NULL;
    CFRelease(interfaceID);
    return E_NOINTERFACE;
}

// IUnknown::AddRef
static ULONG AddRef(void *thisInstance) {
    return ++((QuickLookGeneratorPluginType *)thisInstance)->refCount;
}

// IUnknown::Release
static ULONG Release(void *thisInstance) {
    ((QuickLookGeneratorPluginType *)thisInstance)->refCount--;
    if (((QuickLookGeneratorPluginType *)thisInstance)->refCount == 0) {
        DeallocQuickLookGeneratorPluginType((QuickLookGeneratorPluginType *)thisInstance);
        return 0;
    }
    return ((QuickLookGeneratorPluginType *)thisInstance)->refCount;
}

// Factory function — called by Quick Look to create plugin instance
// This is the entry point declared in Info.plist CFPlugInFactories
void *QuickLookGeneratorPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID) {
    if (CFEqual(typeID, QL_GENERATOR_TYPE)) {
        return AllocQuickLookGeneratorPluginType(PLUGIN_ID);
    }
    return NULL;
}
