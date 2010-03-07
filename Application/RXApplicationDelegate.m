//
//  RXApplicationDelegate.m
//  rivenx
//
//  Created by Jean-Francois Roy on 30/08/2005.
//  Copyright 2005 MacStorm. All rights reserved.
//

#import <ExceptionHandling/NSExceptionHandler.h>
#import <Sparkle/SUUpdater.h>

#import "Application/RXApplicationDelegate.h"

#import "Engine/RXWorld.h"

#import "Rendering/Graphics/RXWorldView.h"

#import "Debug/RXDebug.h"
#import "Debug/RXDebugWindowController.h"

#import "Utilities/GTMSystemVersion.h"


@interface RXApplicationDelegate (RXApplicationDelegate_Private)
- (BOOL)_openGameWithURL:(NSURL*)url;
@end

@implementation RXApplicationDelegate

+ (void)initialize {
    [super initialize];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:NO], @"Fullscreen",
        nil
    ]];
}

- (void)awakeFromNib {
    // setup the about box
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* version_format = NSLocalizedStringFromTable(@"VERSION_FORMAT", @"About", nil);
    NSString* version = [NSString stringWithFormat:@"branch '%@' r%@", NSLocalizedStringFromTable(@"BUILD_BRANCH", @"build", nil), NSLocalizedStringFromTable(@"BUILD_VERSION", @"build", nil)];
    
    [aboutBox center];
    [versionField setStringValue:[NSString stringWithFormat:version_format, [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"], version]];
    [copyrightField setStringValue:NSLocalizedStringFromTable(@"LONG_COPYRIGHT", @"About", nil)];
}

- (void)dealloc {
    [super dealloc];
}

#pragma mark -
#pragma mark debug UI

#if defined(DEBUG)
- (void)_showDebugConsole:(id)sender {
    [debugConsoleWC showWindow:sender];
}

- (void)_initDebugUI {
    debugConsoleWC = [[RXDebugWindowController alloc] initWithWindowNibName:@"DebugConsole"];
    
    NSMenu* debugMenu = [[NSMenu alloc] initWithTitle:@"Debug"];
    [debugMenu addItemWithTitle:@"Console" action:@selector(_showDebugConsole:) keyEquivalent:@""];
    
    NSMenuItem* debugMenuItem = [[NSMenuItem alloc] initWithTitle:@"Debug" action:NULL keyEquivalent:@""];
    [debugMenuItem setSubmenu:debugMenu];
    [[NSApp mainMenu] addItem:debugMenuItem];
    
    [debugMenu release];
    [debugMenuItem release];
}
#endif

#pragma mark -
#pragma mark error handling

- (BOOL)attemptRecoveryFromError:(NSError*)error optionIndex:(NSUInteger)recoveryOptionIndex {
    if ([error domain] == RXErrorDomain) {
        switch ([error code]) {
            case kRXErrEditionCantBecomeCurrent:
                if (recoveryOptionIndex == 0)
//                    [[RXEditionManager sharedEditionManager] showEditionManagerWindow];
                    NSBeep();
                else
                    [NSApp terminate:self];
                break;
            
            case kRXErrSavedGameCantBeLoaded:
                if (recoveryOptionIndex == 0)
//                    [[RXEditionManager sharedEditionManager] showEditionManagerWindow];
                break;
            
            case kRXErrQuickTimeTooOld:
                if (recoveryOptionIndex == 0) {
                    // once to launch SU, and another time to make sure it becomes the active application
                    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.SoftwareUpdate" options:0 additionalEventParamDescriptor:nil launchIdentifier:NULL];
                    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.SoftwareUpdate" options:0 additionalEventParamDescriptor:nil launchIdentifier:NULL];
                }
                [NSApp terminate:self];
                break;
            
            case kRXErrArchiveUnavailable:
            case kRXErrUnableToLoadExtrasArchive:
                // these are fatal right now
                [NSApp terminate:self];
                break;
            
            // fatal errors
            case kRXErrFailedToCreatePixelFormat:
                [NSApp terminate:self];
                break;
        }
        return YES;
    }
    
    return NO;
}

- (void)notifyUserOfFatalException:(NSException*)e {
    NSError* error = [[e userInfo] objectForKey:NSUnderlyingErrorKey];
    
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:0];
    
    rx_print_exception_backtrace(e);
    
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:
        NSLogUncaughtExceptionMask | NSHandleUncaughtExceptionMask |
        NSLogUncaughtRuntimeErrorMask | NSHandleUncaughtRuntimeErrorMask];

    NSAlert* failureAlert = [NSAlert new];
    [failureAlert setMessageText:[e reason]];
    [failureAlert setAlertStyle:NSWarningAlertStyle];
    [failureAlert addButtonWithTitle:NSLocalizedString(@"Quit", @"quit button")];
    
    NSDictionary* userInfo = [e userInfo];
    if (userInfo) {
        if (error)
            [failureAlert setInformativeText:[error localizedDescription]];
        else
            [failureAlert setInformativeText:[e name]];
    } else
        [failureAlert setInformativeText:[e name]];
    
    [failureAlert runModal];
    [failureAlert release];
    
    [NSApp terminate:nil];
}

- (BOOL)exceptionHandler:(NSExceptionHandler*)sender shouldLogException:(NSException*)e mask:(NSUInteger)aMask {
    if ([[e name] isEqualToString:@"RXCommandArgumentsException"] || [[e name] isEqualToString:@"RXUnknownCommandException"] || [[e name] isEqualToString:@"RXCommandError"])
        return NO;
    
    [self notifyUserOfFatalException:e];
    return NO;
}

- (BOOL)_checkQuickTime {
    // check that the user has QuickTime 7.6.2 or later
    NSArray* qtkit_vers = [[[NSBundle bundleWithIdentifier:@"com.apple.QTKit"] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] componentsSeparatedByString:@"."];
    if (!qtkit_vers || [qtkit_vers count] == 0)
        qtkit_vers = [NSArray arrayWithObjects:@"0", nil];
    
#if defined(TEST_QUICKTIME_CHECK)
    qtkit_vers = [NSArray arrayWithObjects:@"7", @"6", @"1", nil];
#endif
    
    BOOL quicktime_too_old = NO;
    if ([qtkit_vers count] > 0)
        if ([[qtkit_vers objectAtIndex:0] intValue] < 7)
            quicktime_too_old = YES;
    
    if ([qtkit_vers count] > 1) {
        if ([[qtkit_vers objectAtIndex:1] intValue] < 6)
            quicktime_too_old = YES;
    } else
        quicktime_too_old = YES;
    
    if ([qtkit_vers count] > 2) {
        if ([[qtkit_vers objectAtIndex:2] intValue] < 2)
            quicktime_too_old = YES;
    } else
        quicktime_too_old = YES;
    
    if (!quicktime_too_old)
        return YES;
    
    // if QuickTime is too old, tell the user about the Cinepak problem and offer them to launch SU
    NSError* error = [NSError errorWithDomain:RXErrorDomain code:kRXErrQuickTimeTooOld userInfo:
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       NSLocalizedString(@"QUICKTIME_REQUIRE_762", "require QuickTime 7.6.2"), NSLocalizedDescriptionKey,
                       NSLocalizedString(@"QUICKTIME_SHOULD_UPGRADE", "should upgrade QuickTime"), NSLocalizedRecoverySuggestionErrorKey,
                       [NSArray arrayWithObjects:NSLocalizedString(@"UPDATE_QUICKTIME", "update QuickTime"), NSLocalizedString(@"QUIT", "quit"), nil], NSLocalizedRecoveryOptionsErrorKey,
                       self, NSRecoveryAttempterErrorKey,
                       nil]];
    [NSApp presentError:error];
    return NO;
}

#pragma mark -
#pragma mark delegation and UI

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
    [[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:
        NSLogUncaughtExceptionMask | NSHandleUncaughtExceptionMask |
        NSLogUncaughtRuntimeErrorMask | NSHandleUncaughtRuntimeErrorMask];
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {    
    // check if the system's QuickTime version is compatible and return if it is not
    if (![self _checkQuickTime])
        return;
    
    // initialize the world
    [RXWorld sharedWorld];
    
    // if we're not installed, start the welcome controller, otherwise start the world
    // FIXME: implement the above logic
    welcomeController = [[RXWelcomeWindowController alloc] initWithWindowNibName:@"Welcome"];
    [welcomeController showWindow:nil];
    
#if defined(DEBUG)
    [self _initDebugUI];
    [self _showDebugConsole:self];
#endif
}

- (void)applicationWillResignActive:(NSNotification*)notification {
    if (!g_world)
        return;
    
    wasFullscreen = [g_world fullscreen];
    if (wasFullscreen)
        [g_world toggleFullscreen];
}

- (void)applicationWillBecomeActive:(NSNotification*)notification {
    if (!g_world)
        return;
    
    if (wasFullscreen)
        [g_world toggleFullscreen];
}

- (BOOL)application:(NSApplication*)application openFile:(NSString*)filename {
    return [self _openGameWithURL:[NSURL fileURLWithPath:filename]];
}

- (IBAction)orderFrontAboutWindow:(id)sender {
    [aboutBox makeKeyAndOrderFront:sender];
}

- (IBAction)showAcknowledgments:(id)sender {
    NSString* ackPath = [[NSBundle mainBundle] pathForResource:@"Riven X Acknowledgments" ofType:@"pdf"];
    [[NSWorkspace sharedWorkspace] openFile:ackPath];
}

- (IBAction)toggleFullscreen:(id)sender {
    if (g_world)
        [g_world toggleFullscreen];
}

- (id <SUVersionComparison>)versionComparatorForUpdater:(SUUpdater*)updater {
    return versionComparator;
}

#pragma mark -
#pragma mark game opening and saving

- (IBAction)openDocument:(id)sender {
    if (!g_world)
        return;
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    
    [panel setCanCreateDirectories:YES];
    [panel setAllowsOtherFileTypes:NO];
    [panel setCanSelectHiddenExtension:YES];
    [panel setTreatsFilePackagesAsDirectories:NO];
    
    NSArray* types;
    if ([GTMSystemVersion isLeopardOrGreater])
        types = [NSArray arrayWithObject:@"org.macstorm.rivenx.game"];
    else
        types = [NSArray arrayWithObject:[(NSString*)UTTypeCopyPreferredTagWithClass(CFSTR("org.macstorm.rivenx.game"), kUTTagClassFilenameExtension) autorelease]];
    NSInteger result = [panel runModalForDirectory:nil file:nil types:types];
    if (result == NSCancelButton)
        return;
    
    [self _openGameWithURL:[panel URL]];
}

- (void)_updateCanSave {
    [self willChangeValueForKey:@"canSave"];
    if (g_world)
        canSave = (([[g_world gameState] URL])) ? YES : NO;
    else
        canSave = NO;
    [self didChangeValueForKey:@"canSave"];
}

- (IBAction)saveGame:(id)sender {
    if (!g_world)
        return;
    
    NSError* error;
    RXGameState* gameState = [g_world gameState];
    if (![gameState writeToURL:[gameState URL] error:&error])
        [NSApp presentError:error];
}

- (void)_saveAsPanelDidEnd:(NSSavePanel*)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo {
    if (returnCode == NSCancelButton)
        return;
    
    // dismiss the panel now
    [panel orderOut:self];
    
    NSError* error = nil;
    RXGameState* gameState = [g_world gameState];
    if (![gameState writeToURL:[panel URL] error:&error]) {
        [NSApp presentError:error];
        return;
    }
    
    // we need to update the can-save state now, since we may not have had a save file before we saved as
    [self _updateCanSave];
    
    // add the new save file to the recents
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[gameState URL]]; 
}

- (IBAction)saveGameAs:(id)sender {
    if (!g_world)
        return;
    
    NSSavePanel* panel = [NSSavePanel savePanel];
    [panel setCanCreateDirectories:YES];
    [panel setAllowsOtherFileTypes:NO];
    [panel setCanSelectHiddenExtension:YES];
    [panel setTreatsFilePackagesAsDirectories:NO];
    
    NSArray* types;
    if ([GTMSystemVersion isLeopardOrGreater])
        types = [NSArray arrayWithObject:@"org.macstorm.rivenx.game"];
    else
        types = [NSArray arrayWithObject:[(NSString*)UTTypeCopyPreferredTagWithClass(CFSTR("org.macstorm.rivenx.game"), kUTTagClassFilenameExtension) autorelease]];
    [panel setAllowedFileTypes:types];
    
    [panel beginSheetForDirectory:nil file:@"untitled" modalForWindow:[g_worldView window] modalDelegate:self didEndSelector:@selector(_saveAsPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (BOOL)_openGameWithURL:(NSURL*)url {
    NSError* error;
    
    // if the game is not running, we can't load anything
    if (!g_world)
        return NO;
    
    // load the save file, and present any error to the user if one occurs
    RXGameState* gameState = [RXGameState gameStateWithURL:url error:&error];
    if (!gameState) {
        [NSApp presentError:error];
        return NO;
    }
    
    // the save game may be using a different edition than the active edition
//    if (![[gameState edition] isEqual:[[RXEditionManager sharedEditionManager] currentEdition]]) {
//        // check if the game's edition can be made current; if not, present an error to the user
//        if (![[gameState edition] canBecomeCurrent]) {
//            error = [NSError errorWithDomain:RXErrorDomain code:kRXErrSavedGameCantBeLoaded userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
//                [NSString stringWithFormat:NSLocalizedStringFromTable(@"CANNOT_LOAD_SAVE_EDITION_NOT_INSTALLED", @"Editions", "cannot load save edition not installed"), [[gameState edition] valueForKey:@"name"]], NSLocalizedDescriptionKey,
//                NSLocalizedStringFromTable(@"INSTALL_EDITION_OR_RESUME", @"Editions", "install or resume"), NSLocalizedRecoverySuggestionErrorKey,
//                [NSArray arrayWithObjects:NSLocalizedString(@"INSTALL", "install"), NSLocalizedString(@"CANCEL", "cancel"), nil], NSLocalizedRecoveryOptionsErrorKey,
//                self, NSRecoveryAttempterErrorKey,
//                nil]];
//            [NSApp presentError:error];
//            return NO;
//        }
//    }
    
    // try to load the game, and present any error to the user if one occurs
    if (![[RXWorld sharedWorld] loadGameState:gameState error:&error]) {
        [NSApp presentError:error];
        return NO;
    }
    
    // add the save file to the recents
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[gameState URL]];
    
    return YES;
}

- (BOOL)isGameLoaded {
    return (g_world) ? YES : NO;
}

@end
