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

#include <math.h>
#include <stdio.h>


int flip_bits(unsigned in, int bits) {
   unsigned ret = 0;
   int i;
   for (i = 0; i < bits; i++) {
      ret |= ( !!(in & (1 << i)) ) << (bits - i - 1);
   }
   printf("IN %d, OUT %d\n", in, ret);
   return ret;
}

int f_s[]= {
0, 1, -1, -1, -1, 1, -1, 1, -1, -1, -1, 1, 1, -1, -1, 1, -1, 1, 1, -1, -1, -1, -1, -1, 1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, -1, 1, 1, 1, -1, 1, 1, -1, -1, -1, -1, 1, -1, -1, -1, -1, -1, 1, 1, -1, -1, 1, 1, -1 };

unsigned rotate_left(unsigned in, int width, int num) {
   unsigned ret = 0;
   unsigned bottom = 0;
   unsigned mask = 0;
   bottom = in;
   //printf("#1 = %d\n", bottom);
   bottom >>= (width - num);
   //printf("#2 = %d\n", bottom);
   mask = ((1 << (num+1)) - 1);
   //printf("mask = %d\n", mask);
   bottom &= mask;
   //printf("BOTTOM = %d\n", bottom);

   ret = in;
   ret <<= num;
   ret = ret & ((1 << width) - 1);
   //printf("TOP = %d\n", ret);

   ret |= bottom;
   return(ret);
}

struct c_sample {
   long long int i, q;
};

#define N     64
#define N_POW 6
#define FMT "%lld"

void gen_sample(int n, struct c_sample *ptr) {
   int r, idx;
   for (r = 0; r < n; r++) {
      idx = flip_bits(r, N_POW);
      ptr[idx].i = f_s[r] * 4096;
      ptr[idx].q = 0;
      printf("Wrote %d to c[%d] = " FMT " + j*" FMT "\n", r, idx, ptr[idx].i, ptr[idx].q);
   }
}

void butter_fly(struct c_sample *A, struct c_sample *B, struct c_sample *TW)
{
   struct c_sample mix, t_A, t_B;
   // A = a_i + j * a_q
   // B = b_i + j * b_q

   // C = A X B = (a_i * b_i + a_i * j * b_q + j * a_q * b_i + j * a_q * j * b_q)
   // C = ( a_i * b_i - a_q * b_q) + j ( a_i * b_q + a_q + b_i )
   // C_i = a_i * b_i - a_q * b_q
   // C_q = a_i * b_q + a_q * b_i


   mix.i = (B->i * TW->i - B->q * TW->q) >> 15;
   mix.q = (B->i * TW->q + B->q * TW->i) >> 15;

   //A->i *= 1;
   //A->q *= 1;
   //B->i *= 1;
   //B->q *= 1;

   t_A.i = A->i + mix.i;
   t_A.q = A->q + mix.q;

   t_B.i = A->i - mix.i;
   t_B.q = A->q - mix.q;

   printf("A: " FMT " + j* " FMT "   B: " FMT " + j* " FMT "  TW: " FMT " + j* " FMT "\n", A->i, A->q, B->i, B->q, TW->i, TW->q);
   printf("mix: " FMT " + j* " FMT "\n", mix.i, mix.q);

   *A = t_A;
   *B = t_B;
   printf("A: " FMT " + j* " FMT "   B: " FMT " + j* " FMT "\n\n", A->i, A->q, B->i, B->q);
}


int W_i[N/2];
int W_q[N/2];
int main() {
   float ti, tq;
   int i, j;
   struct c_sample s_a[N], s_b[N], s_tw[N];
   gen_sample(N, s_a);

#if 0
   for (i = 0; i < (N);i++) {
      printf("[%d] = " FMT " " FMT "\n", i, s_a[i].i, s_a[i].q);
   }
#endif
   /*
   for (i = 0; i < (N/2);i++) {
      printf("%Lf, %Lf\n", sinl((2.0 * M_PI * (float)i) / N), cosl((2.0 * M_PI * (float)i) / N));
   }
   */

   for (i = 0; i < (N/2); i++) {
      ti = cosf((2.0 * M_PI * (float)i) / (float)N);
      s_tw[i].i = W_i[i] = ti * ((1<<15)-1);
      tq = sinf((2.0 * M_PI * (float)i) / (float)N);
      s_tw[i].q = W_q[i] = tq * ((1<<15)-1);


      printf("[%.2d] I= %.15f = 0x%.8x Q= %.15f = 0x%.8x\t\t" FMT ", " FMT "\n", i, ti, W_i[i], tq, W_q[i], s_tw[i].i, s_tw[i].q);
   }

   for (i = 0; i < N_POW; i++) {
      for (j = 0; j < (N/2); j++) {
         int a, b, tw;
         a = rotate_left(j * 2, N_POW, i);
         b = rotate_left(j * 2 + 1, N_POW, i);
         //tw = (j &  ((1<< (i)) - 1)) << (N_POW-1-i); DIF
         tw = (j) & ((1 << (N_POW - 1)) - 1) - ((1 << (N_POW - 1 - i)) -1);

         printf("Stage=%d A=%d,%d tw=%d\n", i, a, b, tw);
         if (i == 0) {
            printf("\t%d,%d => A is timeidx = %d, B is timeidx = %d\n", a,b, flip_bits(a, N_POW), flip_bits(b, N_POW));
         }
         butter_fly(s_a + a, s_a + b, s_tw + tw );

      }
      printf("\n\n");
   }

   for (i = 0; i < N; i++) {
      printf("[%.2d] = " FMT " + j * " FMT "\n", i, s_a[i].i/64, s_a[i].q/64);
   }
   printf("\n\n");
   for (i = 0; i < N; i++) {
      printf("[%.2d] = %f\n", i, sqrt(s_a[i].i * s_a[i].i + s_a[i].q * s_a[i].q));
   }
   return 0;
}
