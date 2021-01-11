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

#define K   7
#define C_A 91
#define C_B 121

#define NUM_BT 1000
#define BIT(y) ( (state >> y) & 1)

#define T_BIT(y) ( (t_state >> y) & 1)

uint32_t state;
unsigned int byte_a, byte_b ;

struct path {
   int32_t cost;
   uint32_t from_state[NUM_BT];
   uint32_t bits[NUM_BT];
   uint32_t bm[NUM_BT];
   uint32_t set[NUM_BT];
   uint32_t to_state[NUM_BT];
   uint32_t win[NUM_BT];
};

uint32_t win_history[100][64];

struct path_metric {
   int idx;
   struct path paths[ 0x40 ];
};

void branch_metric_loop(struct path_metric *in_path, uint8_t r_a, int erasure_a, uint8_t r_b, int erasure_b) {
   // the T_ prefix just means test
   unsigned t_state;
   uint8_t t_bit_a, t_bit_b;
   uint32_t bm;
   uint32_t next_state;

   uint32_t bm_tbl_cost[0x40]; // idx: the end state
   uint32_t bm_tbl_bit[0x40]; // idx: the end state
   memset(bm_tbl_cost, 0xff, sizeof(bm_tbl_cost));
   memset(bm_tbl_bit, 0xff, sizeof(bm_tbl_bit));

   struct path_metric out_path;

   memcpy(&out_path, in_path, sizeof(out_path));
   out_path.idx = in_path->idx++;

   for (t_state = 0; t_state <= 0x3f; t_state++) {
      // calculate the branch metric by:
      //    assuming the trellis at t_state and is about to head to next_state
      //    the uncoded data bit determines to which one of two states the trellis goes from t_state
      //    as it goes to next_state from t_state, two coded bits t_bit_a and t_bit_b are output
      //    the branch metric is the sum of error between the expected value t_bit_a/t_bit_b and the received value r_a/r_b
      //
      // each "destination state"'s path metric is calculated by adding the current corresponding branch metric to the two possible "source state"'s path metric,
      //    and selecting the path with the lowest total path cost
      //
      // each state can only be entered from 2 previous states, so the hardware only has to calculate the branch metric (and total path metric) from 2 previous "source states".

      // bit is 0?
      t_bit_a = T_BIT(5) ^ T_BIT(4) ^ T_BIT(2) ^ T_BIT(1) ^ 0;
      t_bit_b = T_BIT(5) ^ T_BIT(2) ^ T_BIT(1) ^ T_BIT(0) ^ 0;

      //bm = (t_bit_a - r_a) + (t_bit_b - r_b);
      bm = in_path->paths[t_state].cost;
      if (!erasure_a) {
         if (t_bit_a > r_a) {
            bm += t_bit_a - r_a;
         } else {
            bm += r_a - t_bit_a;
         }
      }

      if (!erasure_b) {
         if (t_bit_b > r_b) {
            bm += t_bit_b - r_b;
         } else {
            bm += r_b - t_bit_b;
         }
      }

      next_state = (t_state << 1) & 0x3f;

      if (bm < bm_tbl_cost[next_state]) {
         bm_tbl_cost[next_state] = bm;
         bm_tbl_bit[next_state] = 0;

         out_path.paths[next_state] = in_path->paths[t_state];
         out_path.paths[next_state].cost = bm;
         out_path.paths[next_state].from_state[out_path.idx] = t_state;
         out_path.paths[next_state].bits[out_path.idx] = 0;
         out_path.paths[next_state].to_state[out_path.idx] = next_state;
         out_path.paths[next_state].bm[out_path.idx] = bm;
         out_path.paths[next_state].set[out_path.idx] = 1;
         win_history[out_path.idx][next_state] = !!(t_state & (1 << 5));
      }
      //printf("B=0 COMPUTE S=%.2d TO D=%.2d del=%d\n", t_state, next_state, t_state-next_state);


      bm = in_path->paths[t_state].cost;
      // bit is 1?
      t_bit_a = T_BIT(5) ^ T_BIT(4) ^ T_BIT(2) ^ T_BIT(1) ^ 1;
      t_bit_b = T_BIT(5) ^ T_BIT(2) ^ T_BIT(1) ^ T_BIT(0) ^ 1;

      if (!erasure_a) {
         if (t_bit_a > r_a) {
            bm += t_bit_a - r_a;
         } else {
            bm += r_a - t_bit_a;
         }
      }

      if (!erasure_b) {
         if (t_bit_b > r_b) {
            bm += t_bit_b - r_b;
         } else {
            bm += r_b - t_bit_b;
         }
      }
      next_state = ((t_state << 1) & 0x3f) | 1;

      if (bm < bm_tbl_cost[next_state]) {
         bm_tbl_cost[next_state] = bm;
         bm_tbl_bit[next_state] = 0;

         out_path.paths[next_state] = in_path->paths[t_state];
         out_path.paths[next_state].cost = bm;
         out_path.paths[next_state].from_state[out_path.idx] = t_state;
         out_path.paths[next_state].bits[out_path.idx] = 1;
         out_path.paths[next_state].to_state[out_path.idx] = next_state;
         out_path.paths[next_state].bm[out_path.idx] = bm;
         out_path.paths[next_state].set[out_path.idx] = 1;
         win_history[out_path.idx][next_state] = !!(t_state & (1 << 5));
      }
      //printf("B=1 COMPUTE S=%.2d TO D=%.2d del=%d\n", t_state, next_state, t_state-next_state);

   }

   out_path.idx++;
   memcpy(in_path, &out_path, sizeof(out_path));

}

uint16_t encode_bit(unsigned char bit, int shift, uint8_t *out_a, uint8_t *out_b) {
   uint8_t bit_a, bit_b;

   //printf("State before = %x\n", (state & 0x3f));

   bit_a = BIT(5) ^ BIT(4) ^ BIT(2) ^ BIT(1) ^ bit;
   bit_b = BIT(5) ^ BIT(2) ^ BIT(1) ^ BIT(0) ^ bit;

   byte_a |= (bit_a << 7);
   byte_b |= (bit_b << 7);

   state <<= 1;
   state |= bit;
   state &= 0x3f;
   //printf("State after = %x\n", (state & 0x3f));

   if (shift) {
      byte_a >>= 1;
      byte_b >>= 1;
   }

   if (out_a)
      *out_a = bit_a;

   if (out_b)
      *out_b = bit_b;

   return ((bit_a << 8) + bit_b);
}

void dump_path_metric(struct path_metric *pm_in) {
   int j, z;
   unsigned min_cost = 0xffff;
   unsigned idx = 0;
   unsigned c_state;
   for (j = 0; j <0x40; j++) {
      if (pm_in->paths[j].cost < min_cost) {
         min_cost = pm_in->paths[j].cost;
         idx = j;
      }
      printf("[%.2d] = %d\n", j, pm_in->paths[j].cost);
      //if (!pm_in->paths[j].cost) {
      //   printf("%d", pm_in->paths[j].bits[0]);
      //   break;
      //}
   }
   printf("%d[%d] idx=%d\n", pm_in->paths[idx].bits[0], min_cost, idx);
   for (j = 0; j < pm_in->idx; j++) {
      for (z = 0; z < 0x40; z++) {
         printf("%d", win_history[j][z]);
      }
      printf("\n");
   }
#if 1
   for (z = 0; z < pm_in->idx; z++) {
      printf("%.3d] SET=%d [%.2d]--> bit=%d/w=%d/bm=%d --> [%.2d]", z,
            pm_in->paths[idx].set[z],
            pm_in->paths[idx].from_state[z],
            pm_in->paths[idx].bits[z],
            win_history[z][pm_in->paths[idx].to_state[z]],
            pm_in->paths[idx].bm[z],
            pm_in->paths[idx].to_state[z]
            );
      printf("  ");
      c_state = pm_in->paths[idx].to_state[z];
      for (j = 5; j >= 0; j--)
         printf("%d", !!(c_state & (1 << j)));

      if (win_history[z][c_state]) {
         c_state >>= 1;
         c_state |= (1<<5);
      } else {
         c_state >>= 1;
      }
      printf("  prev_state_hat: ");
      for (j = 5; j >= 0; j--)
         printf("%d", !!(c_state & (1 << j)));
      printf("\n");
   }
#endif
   printf("\n");

}

int main(int argc, char *argv[]) {
   state = 0;

   uint8_t bit_a, bit_b;

   struct path_metric *pm_in, *pm_out;

   unsigned int tx_bits[] = {1, 1, 1, 0,
                             0, 1, 0, 1,
                             0, 1, 1, 0,
                             0, 1, 1, 1,
                             0, 1, 1, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 0,
                             0, 1, 0, 1,
                             0, 1, 1, 0,
                             0, 1, 1, 1,
                             0, 1, 1, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 0,
                             0, 1, 0, 1,
                             0, 1, 1, 0,
                             0, 1, 1, 1,
                             0, 1, 1, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 0,
                             1, 1, 1, 1,
                             1, 1, 1, 1,
                             1, 1, 1, 1,
                             1, 1, 1, 1,
                             };
   unsigned int tx_len = sizeof(tx_bits)/sizeof(tx_bits[0]);

   pm_in  = (struct path_metric *)malloc(sizeof(struct path_metric));
   pm_out = (struct path_metric *)malloc(sizeof(struct path_metric));

   int i, j, z;

   uint8_t *rx_bits = (uint8_t *)malloc(2 * tx_len * sizeof(uint8_t));

   for (i = 0; i < tx_len; i++) {
      byte_a = byte_b = 0;

      printf("t[%d] = from S[%d] to ", i, state);
      encode_bit(tx_bits[i], 1, &bit_a, &bit_b); // 0 -- 1
      printf("= D[%d]\n", state);
      rx_bits[i*2 + 0] = bit_a;
      rx_bits[i*2 + 1] = bit_b;
      //if ((i)==4)
      //   rx_bits[i*2] ^= 1;
   }
   memset(pm_in, 0, sizeof(pm_in));
   for (i = 0; i < 0x40; i++) {
      pm_in->paths[i].cost = (i == 0) ? 0 : 0xffffff;
      for (z = 0; z < 12; z++) {
         pm_in->paths[i].set[z] = 0;
         pm_in->paths[i].from_state[z] = 0;
         pm_in->paths[i].bits[z] = 0;
         pm_in->paths[i].bm[z] = 0;
         pm_in->paths[i].to_state[z] = 0;
      }
   }

   int bit;
   for (bit = 0; bit < (sizeof(tx_bits)/sizeof(tx_bits[0]))/2 ; bit++) {
      bit_a = rx_bits[bit * 2];
      bit_b = rx_bits[bit * 2 + 1];
      branch_metric_loop(pm_in, bit_a, 0, bit_b, 0);
   }
   printf("LAST = %d\n", bit);
   for (j = 0; j <0x40; j++) {
      printf("[%d] ", pm_in->paths[j].from_state[0]);
      for (i = bit - 20; i < bit; i++) {
         printf(" -> [%d]",
               pm_in->paths[j].to_state[i]
               );
      }
      printf("\n");
   }
   dump_path_metric(pm_in);
   printf("\n");
   free(pm_in);
   free(pm_out);

   return 0;
}
