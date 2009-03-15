//
//	RXMovie.m
//	rivenx
//
//	Created by Jean-Francois Roy on 08/09/2005.
//	Copyright 2005 MacStorm. All rights reserved.
//

#import <pthread.h>
#import <limits.h>

#import <OpenGL/CGLMacro.h>

#import "RXMovie.h"


@interface RXMovieReaper : NSObject {
@public
	QTMovie* movie;
	QTVisualContextRef vc;
}
@end

@implementation RXMovieReaper

- (void)dealloc {
#if defined(DEBUG)
	RXOLog2(kRXLoggingRendering, kRXLoggingLevelDebug, @"deallocating");
#endif

	CGLContextObj cgl_ctx = [RXGetWorldView() loadContext];
	CGLLockContext(cgl_ctx);
	
	[movie release];
	if (vc)
		QTVisualContextRelease(vc);
	
	CGLUnlockContext(cgl_ctx);
	
	[super dealloc];
}

@end


@implementation RXMovie

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

- (id)init {
	[self doesNotRecognizeSelector:_cmd];
	[self release];
	return nil;
}

- (id)initWithMovie:(Movie)movie disposeWhenDone:(BOOL)disposeWhenDone owner:(id)owner {
	self = [super init];
	if (!self)
		return nil;
	
	// we must be on the main thread to use QuickTime
	if (!pthread_main_np()) {
		[self release];
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"[RXMovie initWithMovie:disposeWhenDone:] MAIN THREAD ONLY" userInfo:nil];
	}
	
	_owner = owner;
	
	OSStatus err = noErr;
	NSError* error = nil;
	
	// bind the movie to a QTMovie
	_movie = [[QTMovie alloc] initWithQuickTimeMovie:movie disposeWhenDone:disposeWhenDone error:&error];
	if (!_movie) {
		[self release];
		@throw [NSException exceptionWithName:@"RXMovieException" reason:@"[QTMovie initWithQuickTimeMovie:disposeWhenDone:error:] failed." userInfo:(error) ? [NSDictionary dictionaryWithObject:error forKey:NSUnderlyingErrorKey] : nil];
	}
	
	// no particular movie hints initially
	_movieHints = 0;
	
	// we do not restrict playback to the selection initially
	[_movie setAttribute:[NSNumber numberWithBool:NO] forKey:QTMoviePlaysSelectionOnlyAttribute];
	
	// cache the movie's current size
	[[_movie attributeForKey:QTMovieCurrentSizeAttribute] getValue:&_currentSize];
	
	// pixel buffer attributes
	NSMutableDictionary* pixelBufferAttributes = [NSMutableDictionary new];
	[pixelBufferAttributes setObject:[NSNumber numberWithInt:_currentSize.width] forKey:(NSString*)kCVPixelBufferWidthKey];
	[pixelBufferAttributes setObject:[NSNumber numberWithInt:_currentSize.height] forKey:(NSString*)kCVPixelBufferHeightKey];
	[pixelBufferAttributes setObject:[NSNumber numberWithInt:4] forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
	[pixelBufferAttributes setObject:[NSNumber numberWithBool:YES] forKey:(NSString*)kCVPixelBufferOpenGLCompatibilityKey];
#if defined(__LITTLE_ENDIAN__)
	[pixelBufferAttributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
#else
	[pixelBufferAttributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
#endif

	CFMutableDictionaryRef visualContextOptions = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(visualContextOptions, kQTVisualContextPixelBufferAttributesKey, pixelBufferAttributes);
	[pixelBufferAttributes release];
	
	// get the load context and the associated pixel format
	CGLContextObj cgl_ctx = [RXGetWorldView() loadContext];
	CGLPixelFormatObj pixel_format = [RXGetWorldView() cglPixelFormat];
	
	// lock the load context
	CGLLockContext(cgl_ctx);
	
	// alias the load context state object pointer
	NSObject<RXOpenGLStateProtocol>* gl_state = g_loadContextState;
	
	// if the movie is smaller than 128 bytes in width, using a main-memory pixel buffer visual context and override the width to 128 bytes
	if (_currentSize.width < 32) {
#if defined(DEBUG)
		RXOLog2(kRXLoggingGraphics, kRXLoggingLevelDebug, @"using main memory pixel buffer path");
#endif
		
		err = QTPixelBufferContextCreate(NULL, visualContextOptions, &_visualContext);
		CFRelease(visualContextOptions);
		if (err != noErr) {
			[self release];
			@throw [NSException exceptionWithName:@"RXMovieException" reason:@"QTPixelBufferContextCreate failed." userInfo:[NSDictionary dictionaryWithObject:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey]];
		}
		
		// allocate a texture storage buffer and setup a texture object
		_textureStorage = malloc(MAX((int)_currentSize.width, 128) * (int)_currentSize.height * 2);
		bzero(_textureStorage, MAX((int)_currentSize.width, 128) * (int)_currentSize.height * 2);
		
		glGenTextures(1, &_glTexture); glReportError();
		glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _glTexture); glReportError();
		
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
		glReportError();
		
#if defined(__LITTLE_ENDIAN__)
		glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGB8, MAX(_currentSize.width, 128), _currentSize.height, 0, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, _textureStorage); glReportError();
#else
		glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGB8, MAX(_currentSize.width, 128), _currentSize.height, 0, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_REV_APPLE, _textureStorage); glReportError();
#endif
	} else {
		err = QTOpenGLTextureContextCreate(NULL, cgl_ctx, pixel_format, visualContextOptions, &_visualContext);
		CFRelease(visualContextOptions);
		if (err != noErr) {
			[self release];
			@throw [NSException exceptionWithName:@"RXMovieException" reason:@"QTOpenGLTextureContextCreate failed." userInfo:[NSDictionary dictionaryWithObject:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey]];
		}
	}
	
	// create a VAO and prepare the VA state
	glGenVertexArraysAPPLE(1, &_vao); glReportError();
	[gl_state bindVertexArrayObject:_vao];
	
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	
	glEnableClientState(GL_VERTEX_ARRAY); glReportError();
	glVertexPointer(2, GL_FLOAT, 0, _coordinates); glReportError();
	
	glClientActiveTexture(GL_TEXTURE0);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY); glReportError();
	glTexCoordPointer(2, GL_FLOAT, 0, _coordinates + 8); glReportError();
	
	[gl_state bindVertexArrayObject:0];
	
	CGLUnlockContext(cgl_ctx);
	
	// render at (0, 0), natural size; this will update certain attributes in the visual context
	_renderRect.origin.x = 0.0f;
	_renderRect.origin.y = 0.0f;
	_renderRect.size = _currentSize;
	[self setRenderRect:_renderRect];
	
	// set the movie's visual context
	err = SetMovieVisualContext(movie, _visualContext);
	if (err != noErr) {
		[self release];
		@throw [NSException exceptionWithName:@"RXMovieException" reason:@"SetMovieVisualContext failed." userInfo:[NSDictionary dictionaryWithObject:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey]];
	}
	
	return self;
}

- (id)initWithURL:(NSURL*)movieURL owner:(id)owner {
	if (!pthread_main_np()) {
		[self release];
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"[RXMovie initWithURL:] MAIN THREAD ONLY" userInfo:nil];
	}
	
	// prepare a property structure
	Boolean active = true;
	Boolean dontAskUnresolved = true;
	Boolean dontInteract = true;
	Boolean async = true;
	Boolean idleImport = true;
//	Boolean optimizations = true;
	_visualContext = NULL;
	QTNewMoviePropertyElement newMovieProperties[] = {
		{kQTPropertyClass_DataLocation, kQTDataLocationPropertyID_CFURL, sizeof(NSURL *), &movieURL, 0},
		{kQTPropertyClass_Context, kQTContextPropertyID_VisualContext, sizeof(QTVisualContextRef), &_visualContext, 0},
		{kQTPropertyClass_NewMovieProperty, kQTNewMoviePropertyID_Active, sizeof(Boolean), &active, 0}, 
		{kQTPropertyClass_NewMovieProperty, kQTNewMoviePropertyID_DontInteractWithUser, sizeof(Boolean), &dontInteract, 0}, 
		{kQTPropertyClass_MovieInstantiation, kQTMovieInstantiationPropertyID_DontAskUnresolvedDataRefs, sizeof(Boolean), &dontAskUnresolved, 0},
		{kQTPropertyClass_MovieInstantiation, kQTMovieInstantiationPropertyID_AsyncOK, sizeof(Boolean), &async, 0},
		{kQTPropertyClass_MovieInstantiation, kQTMovieInstantiationPropertyID_IdleImportOK, sizeof(Boolean), &idleImport, 0},
//		{kQTPropertyClass_MovieInstantiation, kQTMovieInstantiationPropertyID_AllowMediaOptimization, sizeof(Boolean), &optimizations, 0}, LEOPARD ONLY
	};
	
	// try to open the movie
	Movie aMovie = NULL;
	OSStatus err = NewMovieFromProperties(sizeof(newMovieProperties) / sizeof(newMovieProperties[0]), newMovieProperties, 0, NULL, &aMovie);
	if (err != noErr) {
		[self release];
		@throw [NSException exceptionWithName:@"RXMovieException" reason:@"NewMovieFromProperties failed." userInfo:[NSDictionary dictionaryWithObject:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey]];
	}
	
	@try {
		return [self initWithMovie:aMovie disposeWhenDone:YES owner:owner];
	} @catch(NSException* e) {
		DisposeMovie(aMovie);
		@throw e;
	}
	
	return self;
}

- (void)dealloc {
#if defined(DEBUG)
	RXOLog2(kRXLoggingRendering, kRXLoggingLevelDebug, @"deallocating");
#endif
	
	CGLContextObj cgl_ctx = [RXGetWorldView() loadContext];
	CGLLockContext(cgl_ctx);
	
	if (_vao)
		glDeleteVertexArraysAPPLE(1, &_vao);
	if (_glTexture)
		glDeleteTextures(1, &_glTexture);
	if (_textureStorage)
		free(_textureStorage);
	if (_image_buffer)
		CFRelease(_image_buffer);
	
	CGLUnlockContext(cgl_ctx);
	
	if (_movie || _visualContext) {
		RXMovieReaper* reaper = [RXMovieReaper new];
		reaper->movie = _movie;
		reaper->vc = _visualContext;
		
		if (!pthread_main_np())
			[reaper performSelectorOnMainThread:@selector(release) withObject:nil waitUntilDone:NO];
		else
			[reaper release];
	}
	
	[super dealloc];
}

- (id)owner {
	return _owner;
}

- (QTMovie*)movie {
	return _movie;
}

- (CGSize)currentSize {
	return _currentSize;
}

- (BOOL)looping {
	return [[_movie attributeForKey:QTMovieLoopsAttribute] boolValue];
}

- (void)setLooping:(BOOL)flag {
	[_movie setAttribute:[NSNumber numberWithBool:flag] forKey:QTMovieLoopsAttribute];
	[self clearPlaybackSelection];
	
	if (flag && !_seamless_looping_hacked) {
		// ladies and gentlemen, because QuickTime fails at life, here is the seamless movie hack
		
		// get the movie's duration
		QTTime duration = [_movie duration];
		
		// find the video and audio tracks; bail out if the movie doesn't have exactly one of each or only one video track
		NSArray* tracks = [_movie tracksOfMediaType:QTMediaTypeVideo];
		if ([tracks count] != 1)
			return;
		QTTrack* video_track = [tracks objectAtIndex:0];
		
		tracks = [_movie tracksOfMediaType:QTMediaTypeSound];
		if ([tracks count] > 1)
			return;
		QTTrack* audio_track = ([tracks count]) ? [tracks objectAtIndex:0] : nil;
		
#if defined(DEBUG)
		RXOLog2(kRXLoggingGraphics, kRXLoggingLevelDebug, @"using smooth movie looping hack for %@", self);
#endif
		
		TimeValue tv;
		
		// find the movie's last sample time
		GetMovieNextInterestingTime([_movie quickTimeMovie], nextTimeStep | nextTimeEdgeOK, 0, NULL, (TimeValue)duration.timeValue, -1, &tv, NULL);
		assert(GetMoviesError() == noErr);
		__attribute__((unused)) QTTime last_sample_time = QTMakeTime(tv, duration.timeScale);
		
		// find the beginning time of the video track's last sample
		QTTimeRange track_range = [[video_track attributeForKey:QTTrackRangeAttribute] QTTimeRangeValue];
		GetTrackNextInterestingTime([video_track quickTimeTrack], nextTimeStep | nextTimeEdgeOK, (TimeValue)track_range.duration.timeValue, -1, &tv, NULL);
		assert(GetMoviesError() == noErr);
		QTTime video_last_sample_time = QTMakeTime(tv, duration.timeScale);
		
		GetTrackNextInterestingTime([video_track quickTimeTrack], nextTimeStep, tv, -1, &tv, NULL);
		assert(GetMoviesError() == noErr);
		QTTime video_second_last_sample_time = QTMakeTime(tv, duration.timeScale);
		
		// make the movie editable
		[_movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieEditableAttribute];
		
		QTTime last_sample_duration = QTTimeDecrement(duration, video_last_sample_time);
		QTTime second_last_sample_duration = QTTimeDecrement(video_last_sample_time, video_second_last_sample_time);
		
		// loop the video samples using the *last video sample time plus half the last video sample duration* as the duration
		if (QTTimeCompare(last_sample_duration, second_last_sample_duration) == NSOrderedDescending)
			track_range = QTMakeTimeRange(QTZeroTime, QTTimeIncrement(video_last_sample_time, QTMakeTime((duration.timeValue - video_last_sample_time.timeValue) / 2, duration.timeScale)));
		for (int i = 0; i < 300; i++)
			[video_track insertSegmentOfTrack:video_track timeRange:track_range atTime:track_range.duration];
		
		// loop the audio samples using the *last video sample time* as the duration
		if (audio_track) {
			track_range = QTMakeTimeRange(QTZeroTime, video_last_sample_time);
			for (int i = 0; i < 300; i++)
				[audio_track insertSegmentOfTrack:audio_track timeRange:track_range atTime:track_range.duration];
		}
		
		// we're done editing the movie
		[_movie setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieEditableAttribute];
		
		// flag the movie as being hacked for looping
		_seamless_looping_hacked = YES;
		
#if defined(DEBUG) && DEBUG > 1
		[_movie writeToFile:[[NSString stringWithFormat:@"~/Desktop/looping %p.mov", self] stringByExpandingTildeInPath] withAttributes:nil];
#endif
	}
}

- (float)volume {
	return [_movie volume];
}

- (void)setVolume:(float)volume {
#if defined(DEBUG) && DEBUG > 1
	RXOLog2(kRXLoggingAudio, kRXLoggingLevelDebug, @"setting volume to %f", volume);
#endif
	
	[_movie setVolume:volume];
}

- (BOOL)isPlayingSelection {
	return [[_movie attributeForKey:QTMoviePlaysSelectionOnlyAttribute] boolValue];
}

- (void)setPlaybackSelection:(QTTimeRange)selection {
	[_movie setSelection:selection];
	[self setLooping:NO];
	[_movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMoviePlaysSelectionOnlyAttribute];
}

- (void)clearPlaybackSelection {
	[_movie setAttribute:[NSNumber numberWithBool:NO] forKey:QTMoviePlaysSelectionOnlyAttribute];
}

- (void)setExpectedReadAheadFromDisplayLink:(CVDisplayLinkRef)displayLink {
	CVTime rawOVL = CVDisplayLinkGetOutputVideoLatency(displayLink);
	
	// if the OVL is indefinite, exit
	if (rawOVL.flags | kCVTimeIsIndefinite)
		return;
	
	// set the expected read ahead
	SInt64 ovl = rawOVL.timeValue / rawOVL.timeScale;
	CFNumberRef ovlNumber = CFNumberCreate(NULL, kCFNumberSInt64Type, &ovl);
	QTVisualContextSetAttribute(_visualContext, kQTVisualContextExpectedReadAheadKey, ovlNumber);
	CFRelease(ovlNumber);
}

- (void)setWorkingColorSpace:(CGColorSpaceRef)colorspace {
	QTVisualContextSetAttribute(_visualContext, kQTVisualContextWorkingColorSpaceKey, colorspace);
}

- (void)setOutputColorSpace:(CGColorSpaceRef)colorspace {
	QTVisualContextSetAttribute(_visualContext, kQTVisualContextOutputColorSpaceKey, colorspace);
}

- (CGRect)renderRect {
	return _renderRect;
}

- (void)setRenderRect:(CGRect)rect {
	_renderRect = rect;
	
	// update certain visual context attributes
	NSDictionary* attribDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:_renderRect.size.width], kQTVisualContextTargetDimensions_WidthKey, [NSNumber numberWithFloat:_renderRect.size.height], kQTVisualContextTargetDimensions_HeightKey, nil];
	QTVisualContextSetAttribute(_visualContext, kQTVisualContextTargetDimensionsKey, attribDict);
	
	// specify video rectangle vertices counter-clockwise from (0, 0)
	_coordinates[0] = _renderRect.origin.x;
	_coordinates[1] = _renderRect.origin.y;
	
	_coordinates[2] = _renderRect.origin.x + _renderRect.size.width;
	_coordinates[3] = _renderRect.origin.y;
	
	_coordinates[4] = _renderRect.origin.x + _renderRect.size.width;
	_coordinates[5] = _renderRect.origin.y + _renderRect.size.height;
	
	_coordinates[6] = _renderRect.origin.x;
	_coordinates[7] = _renderRect.origin.y + _renderRect.size.height;
}

- (void)reset {
	CVPixelBufferRelease(_image_buffer);
	_image_buffer = NULL;
	
	QTVisualContextTask(_visualContext);
}

- (void)render:(const CVTimeStamp*)outputTime inContext:(CGLContextObj)cgl_ctx framebuffer:(GLuint)fbo {
	// WARNING: MUST RUN IN THE CORE VIDEO RENDER THREAD
	if (!_movie)
		return;
	
	// alias the render context state object pointer
	NSObject<RXOpenGLStateProtocol>* gl_state = g_renderContextState;
	
	// does the visual context have a new image?
	if (QTVisualContextIsNewImageAvailable(_visualContext, outputTime)) {
		// release the old image
		if (_image_buffer)
			CVPixelBufferRelease(_image_buffer);
		
		// get the new image
		QTVisualContextCopyImageForTime(_visualContext, kCFAllocatorDefault, outputTime, &_image_buffer);
		
		// get the current texture's coordinates
		GLfloat* texCoords = _coordinates + 8;
		
		// we may not have copied a valid image (for example, a movie with no video track)
		if (_image_buffer) {
			if (CFGetTypeID(_image_buffer) == CVOpenGLTextureGetTypeID()) {
				// get the texture coordinates from the CVOpenGLTexture object and bind its texture object
				CVOpenGLTextureGetCleanTexCoords(_image_buffer, texCoords, texCoords + 2, texCoords + 4, texCoords + 6);
				glBindTexture(CVOpenGLTextureGetTarget(_image_buffer), CVOpenGLTextureGetName(_image_buffer)); glReportError();
			} else {
				GLsizei width = CVPixelBufferGetWidth(_image_buffer);
				GLsizei height = CVPixelBufferGetHeight(_image_buffer);
				GLsizei bytesPerRow = CVPixelBufferGetBytesPerRow(_image_buffer);
				
				// compute texture coordinates
				texCoords[0] = 0.0f;
				texCoords[1] = height;
				
				texCoords[2] = width;
				texCoords[3] = height;
				
				texCoords[4] = width;
				texCoords[5] = 0.0f;
				
				texCoords[6] = 0.0f;
				texCoords[7] = 0.0f;
				
				// marshall the image data into the texture
				CVPixelBufferLockBaseAddress(_image_buffer, 0);
				void* baseAddress = CVPixelBufferGetBaseAddress(_image_buffer);
				for (GLuint row = 0; row < height; row++)
					memcpy(BUFFER_OFFSET(_textureStorage, (row * MAX((int)_currentSize.width, 128)) << 1), BUFFER_OFFSET(baseAddress, row * bytesPerRow), width << 1);
				CVPixelBufferUnlockBaseAddress(_image_buffer, 0);
				
				// bind the texture object and update the texture data
				glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _glTexture); glReportError();
				
#if defined(__LITTLE_ENDIAN__)
				glTexSubImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, 0, 0, MAX(_currentSize.width, 128), height, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, _textureStorage); glReportError();
#else
				glTexSubImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, 0, 0, MAX(_currentSize.width, 128), height, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_REV_APPLE, _textureStorage); glReportError();
#endif
			}
		}
	} else if (_image_buffer) {
		// bind the correct texture object
		if (CFGetTypeID(_image_buffer) == CVOpenGLTextureGetTypeID()) {
			assert(CVOpenGLTextureGetTarget(_image_buffer) == GL_TEXTURE_RECTANGLE_ARB);
			glBindTexture(CVOpenGLTextureGetTarget(_image_buffer), CVOpenGLTextureGetName(_image_buffer));
		} else
			glBindTexture(GL_TEXTURE_RECTANGLE_ARB, _glTexture);
		glReportError();
	}
	
	// do we have an image to render?
	if (_image_buffer) {
		[gl_state bindVertexArrayObject:_vao];
		glDrawArrays(GL_QUADS, 0, 4); glReportError();
	}
}

- (void)performPostFlushTasks:(const CVTimeStamp*)outputTime {
	// WARNING: MUST RUN IN THE CORE VIDEO RENDER THREAD
	QTVisualContextTask(_visualContext);
}

@end
