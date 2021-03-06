/*
 *  RXCoreStructures.h
 *  rivenx
 *
 *  Created by Jean-Francois Roy on 13/12/2008.
 *  Copyright 2005-2012 MacStorm. All rights reserved.
 *
 */

#if !defined(RX_CORE_STRUCTURES_H)
#define RX_CORE_STRUCTURES_H

#include <stdint.h>

#pragma pack(push, 1)
struct rx_core_rect {
  uint16_t left;
  uint16_t top;
  uint16_t right;
  uint16_t bottom;
};
typedef struct rx_core_rect rx_core_rect_t;

struct rx_plst_record {
  uint16_t index;
  uint16_t bitmap_id;
  rx_core_rect_t rect;
};

struct rx_mlst_record {
  uint16_t index;
  uint16_t movie_id;
  uint16_t code;
  uint16_t left;
  uint16_t top;
  uint16_t selection_start;
  uint16_t selection_current;
  uint16_t selection_end;
  uint16_t loop;
  uint16_t volume;
  uint16_t rate;
};

struct rx_slst_record1 {
  uint16_t index;
  uint16_t sound_count;
};

struct rx_slst_record2 {
  uint16_t fade_flags;
  uint16_t global_volume;
  uint16_t u0;
  uint16_t u1;
};

struct rx_hspt_record {
  uint16_t blst_id;
  int16_t name_rec;
  rx_core_rect_t rect;
  uint16_t u0;
  uint16_t mouse_cursor;
  uint16_t index;
  int16_t u1;
  uint16_t zip;
};

struct rx_blst_record {
  uint16_t index;
  uint16_t enabled;
  uint16_t hotspot_id;
};

struct rx_flst_record {
  uint16_t index;
  uint16_t sfxe_id;
  uint16_t u0;
};

struct rx_sfxe_record {
  uint16_t magic;
  uint16_t frame_count;
  uint32_t offset_table;
  rx_core_rect_t rect;
  uint16_t fps;
  uint16_t u0;
  rx_core_rect_t alt_rect;
  uint16_t u1;
  uint16_t alt_frame_count;
  uint32_t u2;
  uint32_t u3;
  uint32_t u4;
  uint32_t u5;
  uint32_t u6;
};
#pragma pack(pop)

#endif // RX_CORE_STRUCTURES_H

RX_INLINE rx_core_rect_t rx_swap_core_rect(rx_core_rect_t r)
{
  r.left = CFSwapInt16(r.left);
  r.top = CFSwapInt16(r.top);
  r.right = CFSwapInt16(r.right);
  r.bottom = CFSwapInt16(r.bottom);
  return r;
}
