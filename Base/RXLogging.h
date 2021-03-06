/*
 *  RXLogging.h
 *  rivenx
 *
 *  Created by Jean-Francois Roy on 26/02/2008.
 *  Copyright 2005-2012 MacStorm. All rights reserved.
 *
 */

#if !defined(RXLOGGING_H)
#define RXLOGGING_H

#include <sys/cdefs.h>
#include <CoreFoundation/CoreFoundation.h>

__BEGIN_DECLS

/* facilities */
extern const char* kRXLoggingBase;
extern const char* kRXLoggingEngine;
extern const char* kRXLoggingRendering;
extern const char* kRXLoggingScript;
extern const char* kRXLoggingGraphics;
extern const char* kRXLoggingAudio;
extern const char* kRXLoggingEvents;
extern const char* kRXLoggingAnimation;

/* levels */
extern const int kRXLoggingLevelDebug;
extern const int kRXLoggingLevelMessage;
extern const int kRXLoggingLevelError;
extern const int kRXLoggingLevelCritical;

extern void RXCFLog(const char* facility, int level, CFStringRef format, ...) CF_FORMAT_FUNCTION(3, 4);

#if defined(__OBJC__)

#import <Foundation/NSString.h>

extern void RXLog(const char* facility, int level, NSString* format, ...) NS_FORMAT_FUNCTION(3, 4);
extern void RXLogv(const char* facility, int level, NSString* format, va_list args) NS_FORMAT_FUNCTION(3, 0);

extern void _RXOLog(id object, const char* facility, int level, NSString* format, ...) NS_FORMAT_FUNCTION(4, 5);

#define RXOLog(format, ...) _RXOLog(self, kRXLoggingBase, kRXLoggingLevelMessage, format, ##__VA_ARGS__)
#define RXOLog2(facility, level, format, ...) _RXOLog(self, facility, level, format, ##__VA_ARGS__)

#endif // __OBJC__

__END_DECLS

#endif // RXLOGGING_H
