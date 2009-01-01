//
//	RXSoundGroup.mm
//	rivenx
//
//	Created by Jean-Francois Roy on 11/03/2006.
//	Copyright 2006 MacStorm. All rights reserved.
//

#import "integer_pair_hash.h"
#import "RXSoundGroup.h"


@implementation RXSound

- (id <MHKAudioDecompression>)audioDecompressor {
	return [parent audioDecompressorWithID:ID];
}

- (BOOL)isEqual:(id)anObject {
	if (![anObject isKindOfClass:[self class]])
		return NO;
	RXSound* sound = (RXSound*)anObject;
	if (sound->ID == self->ID && sound->parent == self->parent)
		return YES;
	return NO;
}

- (NSUInteger)hash {
	// WARNING: WILL BREAK ON 64-BIT
	return integer_pair_hash((int)parent, (int)ID);
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ {parent=%@, ID=%hu, gain=%f, pan=%f, rampStartTimestamp=%qu, detachTimestampValid=%d, source=%p}", [super description], parent, ID, gain, pan, rampStartTimestamp, detachTimestampValid, source];
}

@end

@implementation RXDataSound

- (id <MHKAudioDecompression>)audioDecompressor {
	return [parent audioDecompressorWithDataID:ID];
}

- (BOOL)isEqual:(id)anObject {
	return (anObject == self) ? YES : NO;
}

- (NSUInteger)hash {
	return (NSUInteger)self;
}

@end

@implementation RXSoundGroup

- (id)init {
	self = [super init];
	if (!self)
		return nil;
	
	_sounds = [NSMutableSet new];
	
	return self;
}

- (void)dealloc {
#if defined(DEBUG)
	RXOLog(@"deallocating");
#endif
	
	[_sounds release];
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat: @"%@ {fadeOutActiveGroupBeforeActivating=%d, fadeInOnActivation=%d, loop=%d, gain=%f, %d sounds}", [super description], fadeOutActiveGroupBeforeActivating, fadeInOnActivation, loop, gain, [_sounds count]];
}

- (void)addSoundWithStack:(RXStack*)parent ID:(uint16_t)ID gain:(float)g pan:(float)p {
	RXSound* source = [RXSound new];
	source->parent = parent;
	source->ID = ID;
	source->gain = g;
	source->pan = p;
	
	[_sounds addObject:source];
	[source release];
}

- (NSSet*)sounds {
	return _sounds;
}

@end
