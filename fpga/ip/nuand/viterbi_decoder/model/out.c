// This file is part of bladeRF-wiphy.
//
// Copyright (C) 2021 Nuand, LLC.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include <stdlib.h>

#define K  7
#define C_A 91
#define C_B 121

#define BIT(y) ( (state >> y) & 1)

#define T_BIT(y) ( (t_state >> y) & 1)

int main(int argc, char *argv[]) {
   unsigned t_state;
   unsigned next_state;
   uint8_t t_bit_a, t_bit_b;
   for (t_state = 0; t_state <= 0x3f; t_state++) {
      // bit is 0?
      t_bit_a = T_BIT(5) ^ T_BIT(4) ^ T_BIT(2) ^ T_BIT(1) ^ 0;
      t_bit_b = T_BIT(5) ^ T_BIT(2) ^ T_BIT(1) ^ T_BIT(0) ^ 0;
      next_state = (t_state << 1) & 0x3f;
      printf("S[%d] -- bit=%d coded=%d,%d -- D[%d]\n", t_state, 0, t_bit_a, t_bit_b, next_state);

      // bit is 1?
      t_bit_a = T_BIT(5) ^ T_BIT(4) ^ T_BIT(2) ^ T_BIT(1) ^ 1;
      t_bit_b = T_BIT(5) ^ T_BIT(2) ^ T_BIT(1) ^ T_BIT(0) ^ 1;
      next_state = ((t_state << 1) & 0x3f) | 1;
      printf("S[%d] -- bit=%d coded=%d,%d -- D[%d]\n", t_state, 1, t_bit_a, t_bit_b, next_state);
   }
   return 0;
}
