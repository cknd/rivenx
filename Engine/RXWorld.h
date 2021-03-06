//
//  RXWorld.h
//  rivenx
//
//  Created by Jean-Francois Roy on 25/08/2005.
//  Copyright 2005-2012 MacStorm. All rights reserved.
//

#import "Base/RXBase.h"

#import "Engine/RXWorldProtocol.h"
#import "Engine/RXGameState.h"
#import "Rendering/RXRendering.h"
#import "States/RXRenderState.h"

#import <AppKit/NSApplication.h>

@interface RXWorld : NSObject <RXWorldProtocol> {
  NSURL* _worldBase;
  NSURL* _worldCacheBase;
  NSURL* _worldSupportBase;

  NSDictionary* _extrasDescriptor;

  NSMapTable* _cursors;

  semaphore_t _threadInitSemaphore;
  NSThread* _scriptThread;

  NSView<RXWorldViewProtocol>* _worldView;
  NSWindow* _fullscreenWindow;
  NSWindow* _window;
  void* _audioRenderer;
  RXRenderState* _cardRenderer;

  NSMutableDictionary* _activeStacks;
  NSDictionary* _stackDescriptors;

  RXGameState* _gameState;
  RXGameState* _gameStateToLoad;

  NSMutableDictionary* _engineVariables;
  OSSpinLock _engineVariablesLock;

  NSApplicationPresentationOptions _defaultPresentationOptions;

  NSMutableDictionary* _cachePreferences;

  BOOL _tornDown;
  BOOL _renderingInitialized;
  BOOL _fullscreen;
}

+ (RXWorld*)sharedWorld;

- (void)tearDown;

- (NSURL*)worldBase;
- (NSURL*)worldCacheBase;
- (NSURL*)worldSupportBase;

- (BOOL)isInstalled;
- (void)setIsInstalled:(BOOL)flag;

- (void)setWorldBaseOverride:(NSString*)path;

@end
