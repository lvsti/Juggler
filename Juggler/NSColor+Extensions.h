//
//  NSColor+Extensions.h
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 22..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <AvailabilityMacros.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 101500

@interface NSColor (SystemTeal)
@property (class, strong, readonly) NSColor *systemTealColor API_AVAILABLE(macos(10.12));
@end

#endif
