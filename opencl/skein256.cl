/*
* skein256 kernel implementation.
*
* ==========================(LICENSE BEGIN)============================
* Copyright (c) 2014 djm34
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
* ===========================(LICENSE END)=============================
*
* @author   djm34
*/

#include "util_hash.cl"
#include "sha256d.cl"


__constant static const sph_u64 SKEIN_IV512[] = {
  SPH_C64(0x4903ADFF749C51CE), SPH_C64(0x0D95DE399746DF03),
  SPH_C64(0x8FD1934127C79BCE), SPH_C64(0x9A255629FF352CB1),
  SPH_C64(0x5DB62599DF6CA7B0), SPH_C64(0xEABE394CA9D5C3F4),
  SPH_C64(0x991112C71A75B523), SPH_C64(0xAE18A40B660FCC33)
};

__constant static const sph_u64 SKEIN_IV512_256[8] = {
	SPH_C64(0xCCD044A12FDB3E13), SPH_C64(0xE83590301A79A9EB),
	SPH_C64(0x55AEA0614F816E6F), SPH_C64(0x2A2767A4AE9B94DB),
	SPH_C64(0xEC06025E74DD7683), SPH_C64(0xE7A436CDC4746251),
	SPH_C64(0xC36FBAF9393AD185), SPH_C64(0x3EEDBA1833EDFC13)
};


/*
__constant const sph_u32 ROT256[8][4] =
{
	SPH_C32(0x2E), SPH_C32(0x24), SPH_C32(0x13), SPH_C32(0x25),
	SPH_C32(0x21) SPH_C32(0x1B), SPH_C32(0xE), SPH_C32(0x2A),
	SPH_C32(0x11), SPH_C32(0x31), SPH_C32(0x36), SPH_C32(0x27),
	SPH_C32(0x2C), SPH_C32(0x9), SPH_C32(0x24), SPH_C32(0x38),
	SPH_C32(0x27), SPH_C32(0x1E), SPH_C32(0x22), SPH_C32(0x18),
	SPH_C32(0xD), SPH_C32(0x32), SPH_C32(0xA), SPH_C32(0x11),
	SPH_C32(0x19), SPH_C32(0x1D), SPH_C32(0x27), SPH_C32(0x2B),
	SPH_C32(0x8), SPH_C32(0x23), SPH_C32(0x38), SPH_C32(0x16),
};
*/
__constant static const sph_u32 ROT256[8][4] =
{
{46, 36, 19, 37},
{33, 27, 14, 42 },
{17, 49, 36, 39},
{44, 9, 54, 56},
{39, 30, 34, 24},
{13, 50, 10, 17},
{25, 29, 39, 43},
{8, 35, 56, 22},
};
__constant static const sph_u64 skein_ks_parity = 0x1BD11BDAA9FC1A22;

__constant static const sph_u64 t12[6] =
{ 	SPH_C64(0x20),
	SPH_C64(0xf000000000000000),
	SPH_C64(0xf000000000000020),
	SPH_C64(0x08),
	SPH_C64(0xff00000000000000),
	SPH_C64(0xff00000000000008)
};


#define Round512(p0,p1,p2,p3,p4,p5,p6,p7,ROT)  { \
p0 += p1; p1 = SPH_ROTL64(p1, ROT256[ROT][0]);  p1 ^= p0; \
p2 += p3; p3 = SPH_ROTL64(p3, ROT256[ROT][1]);  p3 ^= p2; \
p4 += p5; p5 = SPH_ROTL64(p5, ROT256[ROT][2]);  p5 ^= p4; \
p6 += p7; p7 = SPH_ROTL64(p7, ROT256[ROT][3]);  p7 ^= p6; \
} 

#define Round_8_512(p0, p1, p2, p3, p4, p5, p6, p7, R) { \
	    Round512(p0, p1, p2, p3, p4, p5, p6, p7, 0); \
	    Round512(p2, p1, p4, p7, p6, p5, p0, p3, 1); \
	    Round512(p4, p1, p6, p3, p0, p5, p2, p7, 2); \
	    Round512(p6, p1, p0, p7, p2, p5, p4, p3, 3); \
	    p0 += h[((R)+0) % 9]; \
      p1 += h[((R)+1) % 9]; \
      p2 += h[((R)+2) % 9]; \
      p3 += h[((R)+3) % 9]; \
      p4 += h[((R)+4) % 9]; \
      p5 += h[((R)+5) % 9] + t[((R)+0) % 3]; \
      p6 += h[((R)+6) % 9] + t[((R)+1) % 3]; \
      p7 += h[((R)+7) % 9] + R; \
		Round512(p0, p1, p2, p3, p4, p5, p6, p7, 4); \
		Round512(p2, p1, p4, p7, p6, p5, p0, p3, 5); \
		Round512(p4, p1, p6, p3, p0, p5, p2, p7, 6); \
		Round512(p6, p1, p0, p7, p2, p5, p4, p3, 7); \
		p0 += h[((R)+1) % 9]; \
		p1 += h[((R)+2) % 9]; \
		p2 += h[((R)+3) % 9]; \
		p3 += h[((R)+4) % 9]; \
		p4 += h[((R)+5) % 9]; \
		p5 += h[((R)+6) % 9] + t[((R)+1) % 3]; \
		p6 += h[((R)+7) % 9] + t[((R)+2) % 3]; \
		p7 += h[((R)+8) % 9] + (R+1); \
}

void skein256_s(sph_u64 input[], sph_u64 *output)
{
	sph_u64 h[9];
	sph_u64 t[3];
	sph_u64 dt0, dt1, dt2, dt3;
	sph_u64 p0, p1, p2, p3, p4, p5, p6, p7;
	h[8] = skein_ks_parity;

	for (int i = 0; i<8; i++) {
		h[i] = SKEIN_IV512_256[i];
		h[8] ^= h[i];
	}

	t[0] = t12[0];
	t[1] = t12[1];
	t[2] = t12[2];

	dt0 = input[0];
	dt1 = input[1];
	dt2 = input[2];
	dt3 = input[3];

	p0 = h[0] + dt0;
	p1 = h[1] + dt1;
	p2 = h[2] + dt2;
	p3 = h[3] + dt3;
	p4 = h[4];
	p5 = h[5] + t[0];
	p6 = h[6] + t[1];
	p7 = h[7];

	//#pragma unroll 
	for (int i = 1; i<19; i += 2) { Round_8_512(p0, p1, p2, p3, p4, p5, p6, p7, i); }
	p0 ^= dt0;
	p1 ^= dt1;
	p2 ^= dt2;
	p3 ^= dt3;

	h[0] = p0;
	h[1] = p1;
	h[2] = p2;
	h[3] = p3;
	h[4] = p4;
	h[5] = p5;
	h[6] = p6;
	h[7] = p7;
	h[8] = skein_ks_parity;

	for (int i = 0; i<8; i++) { h[8] ^= h[i]; }

	t[0] = t12[3];
	t[1] = t12[4];
	t[2] = t12[5];
	p5 += t[0];  //p5 already equal h[5] 
	p6 += t[1];

	//#pragma unroll
	for (int i = 1; i<19; i += 2) { Round_8_512(p0, p1, p2, p3, p4, p5, p6, p7, i); }

	output[0] = p0;
	output[1] = p1;
	output[2] = p2;
	output[3] = p3;
	barrier(CLK_LOCAL_MEM_FENCE);
}

void skein256(hash_t* hash)
{
	sph_u64 input1[8], input2[8];
	sph_u64 output[4];
	for (int i = 0; i < 8; i++)
	{
		input1[i] = hash->h8[i];
		input2[7 - i] = input1[i];
	}
	skein256_s(input1, &output);
	for (int i = 0; i < 4; i++)
	{
		hash->h8[i] = output[i];
	}
	skein256_s(input2, &output);
	for (int i = 0; i < 4; i++)
	{
		hash->h8[i + 4] = output[i];
	}
	//barrier(CLK_LOCAL_MEM_FENCE);
}

__kernel void scanHash(__global uchar* input,__global uint* goodNonce, const ulong target,const uint nonceStart)
{
	uint gid = get_global_id(0);
	hash_t hashdatadst;
		for(int j=0;j<64;++j)
			hashdatadst.h1[j]=input[j];
		hashdatadst.h4[14] = hashdatadst.h4[14] ^ hashdatadst.h4[15];
		hashdatadst.h4[15] = gid+nonceStart;
		skein256(&hashdatadst);

		//sha256d
		hash_t32 output;
		SHA256_CTX ctx;
		SHA256Initialize(&ctx);
		SHA256Update(&ctx, (BYTE *)hashdatadst.h1, 64);
		SHA256Finalize(&ctx, (BYTE *)output.h1);
		ulong outcome = output.h8[3];
		bool result = (outcome <= target);
		if (result) {
			//printf("gid %d hit target!\n", gid*THREADWIDTH+i+nonceStart);
			goodNonce[goodNonce[FOUND]++]=gid+nonceStart;
		}
		barrier(CLK_GLOBAL_MEM_FENCE);
	
}