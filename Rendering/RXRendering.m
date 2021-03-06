//
//  RXRendering.m
//  rivenx
//
//  Created by Jean-Francois Roy on 11/12/2005.
//  Copyright 2005-2012 MacStorm. All rights reserved.
//

#import "Rendering/RXRendering.h"

const rx_size_t kRXRendererViewportSize = {608, 458};
const rx_size_t kRXCardViewportSize = {608, 392};
const rx_size_t kRXInventorySize = {0, 66};
const GLsizei kRXInventoryVerticalMargin = 10;

const double kRXTransitionDuration = 0.4;

const float kRXSoundGainDivisor = 256.0f;

NSView<RXWorldViewProtocol>* g_worldView = nil;
