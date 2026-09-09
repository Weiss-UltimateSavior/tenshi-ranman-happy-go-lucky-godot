/*
 * tlg2png — Kirikiri TLG (TLG5 / TLG6 / TLG0.0 SDS) to PNG converter.
 *
 * Cross-platform reimplementation of the Tlg2Png.exe helper used by the
 * Windows development environment, following the reference decoder in
 * krkrZ visual/LoadTLG.cpp and visual/tvpgl.c (TVPTLG5DecompressSlide_c,
 * TVPTLG5ComposeColors*_c, TVPTLG6DecodeGolomb*_c, TVPTLG6DecodeLineGeneric_c).
 *
 * Usage (mirrors the Windows helper invoked from scripts/story/story_player.gd):
 *   tlg2png <file.tlg> <output-dir>     convert one file
 *   tlg2png <source-dir> <output-dir>   convert every *.tlg under source-dir
 *                                       (recursively, preserving the tree)
 *
 * Output PNG paths are <output-dir>/<relative-input-path>.png.
 * Builds on macOS/Linux with cc -O2 tlg2png.c -o tlg2png and on Windows with
 * any C compiler; the Windows developer setup keeps using its existing exe.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
#include <direct.h>
#else
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>
#endif

/* ----------------------------------------------------------------------------
 * Minimal PNG writer (no external dependencies): zlib store blocks + CRC32.
 * -------------------------------------------------------------------------- */

static uint32_t crc_table[256];
static void crc_init(void) {
	for (uint32_t n = 0; n < 256; n++) {
		uint32_t c = n;
		for (int k = 0; k < 8; k++)
			c = (c & 1) ? 0xedb88320u ^ (c >> 1) : c >> 1;
		crc_table[n] = c;
	}
}
static uint32_t crc32_buf(uint32_t crc, const uint8_t *buf, size_t len) {
	crc ^= 0xffffffffu;
	for (size_t i = 0; i < len; i++)
		crc = crc_table[(crc ^ buf[i]) & 0xff] ^ (crc >> 8);
	return crc ^ 0xffffffffu;
}

static void put32be(uint8_t *p, uint32_t v) {
	p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16);
	p[2] = (uint8_t)(v >> 8);  p[3] = (uint8_t)v;
}

typedef struct {
	FILE *f;
	uint32_t crc;
	size_t uncomp_total;
	size_t comp_cap, comp_len;
	uint8_t *comp;     /* single adler32-terminated zlib stream, stored */
	uint32_t adler_a, adler_b;
	size_t block_left;
} png_writer;

static void wr_raw(png_writer *w, const uint8_t *data, size_t len) {
	if (len) fwrite(data, 1, len, w->f);
}

static void wr_chunk(png_writer *w, const char *type, const uint8_t *data, size_t len) {
	uint8_t header[8], crcb[4];
	put32be(header, (uint32_t)len);
	memcpy(header + 4, type, 4);
	wr_raw(w, header, 8);
	w->crc = crc32_buf(crc32_buf(0, (const uint8_t *)type, 4), data, len);
	if (len) wr_raw(w, data, len);
	put32be(crcb, w->crc);
	wr_raw(w, crcb, 4);
}

static int png_write(const char *path, int width, int height, const uint8_t *rgba) {
	png_writer w;
	w.f = fopen(path, "wb");
	if (!w.f) return -1;
	static const uint8_t sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
	wr_raw(&w, sig, 8);

	uint8_t ihdr[13];
	put32be(ihdr, (uint32_t)width);
	put32be(ihdr + 4, (uint32_t)height);
	ihdr[8] = 8;   /* bit depth */
	ihdr[9] = 6;   /* color type RGBA */
	ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
	wr_chunk(&w, "IHDR", ihdr, 13);

	/* zlib stream with stored (uncompressed) deflate blocks, all in one IDAT.
	 * Each scanline gets a filter byte 0 prepended; PNG rows are emitted one
	 * per outer iteration so block headers never split a row's accounting. */
	size_t stride = 1 + (size_t)width * 4;
	size_t raw_len = (size_t)height * stride;
	size_t max_block = 65535;
	/* Worst case: a block header per row plus headers spanning row bodies. */
	uint8_t *comp = (uint8_t *)malloc(2 + 5 * (height + raw_len / max_block + 2) + raw_len + 4);
	if (!comp) { fclose(w.f); return -1; }
	size_t off = 0;
	uint32_t adler_a = 1, adler_b = 0;
	comp[off++] = 0x78;
	comp[off++] = 0x01;
	const uint8_t *src = rgba;
#define EMIT_BYTE(b_) do { \
	uint8_t b__ = (uint8_t)(b_); \
	comp[off++] = b__; \
	adler_a = (adler_a + b__) % 65521u; \
	adler_b = (adler_b + adler_a) % 65521u; \
	raw_left--; \
} while (0)
	size_t raw_left = raw_len;
	size_t pending_block = 0; /* position of header for current open block */
	int block_open = 0;
	size_t block_counted = 0;
	for (int y = 0; y < height; y++) {
		/* Ensure a block is open with enough room for this row. */
		if (!block_open || block_counted + stride > max_block) {
			if (block_open) {
				/* Patch previous block header: not final, actual length. */
				comp[pending_block + 1] = (uint8_t)(block_counted & 0xff);
				comp[pending_block + 2] = (uint8_t)(block_counted >> 8);
				comp[pending_block + 3] = (uint8_t)(~block_counted & 0xff);
				comp[pending_block + 4] = (uint8_t)((~block_counted >> 8) & 0xff);
			}
			pending_block = off;
			comp[off++] = 0x00; /* not final (patched later) */
			off += 4;           /* LEN/NLEN placeholder */
			block_open = 1;
			block_counted = 0;
		}
		EMIT_BYTE(0); /* filter None */
		for (size_t x = 0; x < (size_t)width * 4; x++)
			EMIT_BYTE(src[x]);
		src += (size_t)width * 4;
		block_counted += stride;
		/* Close the block if the next row would overflow it. */
		if (block_counted + stride > max_block) {
			comp[pending_block] = (uint8_t)((y == height - 1) ? 1 : 0);
			comp[pending_block + 1] = (uint8_t)(block_counted & 0xff);
			comp[pending_block + 2] = (uint8_t)(block_counted >> 8);
			comp[pending_block + 3] = (uint8_t)(~block_counted & 0xff);
			comp[pending_block + 4] = (uint8_t)((~block_counted >> 8) & 0xff);
			block_open = 0;
		}
	}
	if (block_open) {
		comp[pending_block] = 0x01; /* final */
		comp[pending_block + 1] = (uint8_t)(block_counted & 0xff);
		comp[pending_block + 2] = (uint8_t)(block_counted >> 8);
		comp[pending_block + 3] = (uint8_t)(~block_counted & 0xff);
		comp[pending_block + 4] = (uint8_t)((~block_counted >> 8) & 0xff);
	}
	comp[off++] = (uint8_t)(adler_b >> 8);
	comp[off++] = (uint8_t)(adler_b & 0xff);
	comp[off++] = (uint8_t)(adler_a >> 8);
	comp[off++] = (uint8_t)(adler_a & 0xff);
#undef EMIT_BYTE
	wr_chunk(&w, "IDAT", comp, off);
	free(comp);
	wr_chunk(&w, "IEND", NULL, 0);
	fclose(w.f);
	return 0;
}

/* ----------------------------------------------------------------------------
 * TLG5 decoding (krkrz TVPTLG5DecompressSlide_c / ComposeColors*_c).
 * -------------------------------------------------------------------------- */

static int tlg5_decompress_slide(uint8_t *out, const uint8_t *in, int insize,
                                 uint8_t *text, int r) {
	const uint8_t *inlim = in + insize;
	uint32_t flags = 0;
	while (in < inlim) {
		flags >>= 1;
		if ((flags & 256) == 0)
			flags = *in++ | 0xff00;
		if (flags & 1) {
			int mpos = in[0] | ((in[1] & 0xf) << 8);
			int mlen = (in[1] & 0xf0) >> 4;
			in += 2;
			mlen += 3;
			if (mlen == 18) mlen += *in++;
			while (mlen--) {
				text[r] = text[mpos];
				*out++ = text[r];
				r = (r + 1) & (4096 - 1);
				mpos = (mpos + 1) & (4096 - 1);
			}
		} else {
			uint8_t c = *in++;
			text[r] = c;
			*out++ = c;
			r = (r + 1) & (4096 - 1);
		}
	}
	return r;
}

static void tlg5_compose_first_line(uint8_t *out, uint8_t *const *buf,
                                    int width, int colors) {
	int pb = 0, pg = 0, pr = 0, pa = 0;
	for (int x = 0; x < width; x++) {
		int b = buf[0][x], g = buf[1][x], r = buf[2][x];
		b += g; r += g;
		pb = (pb + b) & 0xff;
		pg = (pg + g) & 0xff;
		pr = (pr + r) & 0xff;
		*out++ = (uint8_t)pb;
		*out++ = (uint8_t)pg;
		*out++ = (uint8_t)pr;
		if (colors == 4) { pa = (pa + buf[3][x]) & 0xff; *out++ = (uint8_t)pa; }
		else *out++ = 0xff;
	}
}

static void tlg5_compose_line(uint8_t *out, const uint8_t *upper,
                              uint8_t *const *buf, int width, int colors) {
	uint8_t pc[4] = {0, 0, 0, 0};
	for (int x = 0; x < width; x++) {
		uint8_t c[4] = {buf[0][x], buf[1][x], buf[2][x], 0};
		if (colors == 4) c[3] = buf[3][x];
		c[0] = (uint8_t)(c[0] + c[1]);
		c[2] = (uint8_t)(c[2] + c[1]);
		pc[0] = (uint8_t)(pc[0] + c[0]);
		pc[1] = (uint8_t)(pc[1] + c[1]);
		pc[2] = (uint8_t)(pc[2] + c[2]);
		pc[3] = (uint8_t)(pc[3] + c[3]);
		*out++ = (uint8_t)((pc[0] + upper[0]) & 0xff);
		*out++ = (uint8_t)((pc[1] + upper[1]) & 0xff);
		*out++ = (uint8_t)((pc[2] + upper[2]) & 0xff);
		*out++ = (uint8_t)((pc[3] + upper[3]) & 0xff);
		upper += 4;
	}
}

static int decode_tlg5(const uint8_t *d, size_t len, const char *out_path) {
	/* Header: 11-byte magic "TLG5.0\x00raw\x1a" then colors(1), w, h, blockh. */
	if (len < 24) return -1;
	int colors = d[11];
	uint32_t width, height, blockheight;
	memcpy(&width, d + 12, 4);
	memcpy(&height, d + 16, 4);
	memcpy(&blockheight, d + 20, 4);
	if ((colors != 3 && colors != 4) || width == 0 || height == 0 ||
	    blockheight == 0) return -1;
	int blockcount = (int)((height - 1) / blockheight) + 1;
	size_t pos = 24 + (size_t)blockcount * 4;
	if (pos >= len) return -1;

	uint8_t *image = (uint8_t *)malloc((size_t)width * height * 4);
	uint8_t *planes[4] = {NULL, NULL, NULL, NULL};
	uint8_t *inbuf = (uint8_t *)malloc((size_t)blockheight * width + 16);
	uint8_t *text = (uint8_t *)calloc(4096, 1);
	if (!image || !inbuf || !text) { free(image); free(inbuf); free(text); return -1; }
	for (int c = 0; c < colors; c++)
		planes[c] = (uint8_t *)malloc((size_t)blockheight * width + 16);

	int r = 0;
	int written = 0;
	for (uint32_t y_blk = 0; y_blk < height; y_blk += blockheight) {
		for (int c = 0; c < colors; c++) {
			if (pos + 5 > len) goto fail;
			uint8_t mark = d[pos++];
			uint32_t size; memcpy(&size, d + pos, 4); pos += 4;
			if (pos + size > len || size > (size_t)blockheight * width + 10) goto fail;
			if (mark == 0) {
				r = tlg5_decompress_slide(planes[c], d + pos, (int)size, text, r);
			} else {
				memcpy(planes[c], d + pos, size);
			}
			pos += size;
		}
		uint32_t y_lim = y_blk + blockheight;
		if (y_lim > height) y_lim = height;
		uint8_t *bufp[4];
		for (int c = 0; c < colors; c++) bufp[c] = planes[c];
		for (uint32_t y = y_blk; y < y_lim; y++) {
			uint8_t *outp = image + ((size_t)y * width) * 4;
			if (written) {
				uint8_t *upper = image + ((size_t)(y - 1) * width) * 4;
				tlg5_compose_line(outp, upper, bufp, (int)width, colors);
			} else {
				tlg5_compose_first_line(outp, bufp, (int)width, colors);
			}
			for (int c = 0; c < colors; c++) bufp[c] += width;
			written = 1;
		}
	}
	int rc = png_write(out_path, (int)width, (int)height, image);
	for (int c = 0; c < colors; c++) free(planes[c]);
	free(image); free(inbuf); free(text);
	return rc;
fail:
	for (int c = 0; c < colors; c++) free(planes[c]);
	free(image); free(inbuf); free(text);
	return -1;
}

/* ----------------------------------------------------------------------------
 * TLG6 decoding (krkrz TVPTLG6DecodeGolomb*_c / DecodeLineGeneric_c).
 * -------------------------------------------------------------------------- */

#define TLG6_W_BLOCK_SIZE 8
#define TLG6_H_BLOCK_SIZE 8
#define TLG6_GOLOMB_N_COUNT 4
#define LZ_TABLE_BITS 12
#define LZ_TABLE_SIZE (1 << LZ_TABLE_BITS)

static uint8_t leading_zero_table[LZ_TABLE_SIZE];
static int8_t golomb_bit_length_table[TLG6_GOLOMB_N_COUNT * 2 * 128][TLG6_GOLOMB_N_COUNT];
static int tables_ready = 0;

static void tlg6_init_tables(void) {
	if (tables_ready) return;
	static const short golomb_compressed[TLG6_GOLOMB_N_COUNT][9] = {
		{3, 7, 15, 27, 63, 108, 223, 448, 130},
		{3, 5, 13, 24, 51, 95, 192, 384, 257},
		{2, 5, 12, 21, 39, 86, 155, 320, 384},
		{2, 3, 9, 18, 33, 61, 129, 258, 511},
	};
	for (int i = 0; i < LZ_TABLE_SIZE; i++) {
		int cnt = 0, j;
		for (j = 1; j != LZ_TABLE_SIZE && !(i & j); j <<= 1, cnt++);
		cnt++;
		if (j == LZ_TABLE_SIZE) cnt = 0;
		leading_zero_table[i] = (uint8_t)cnt;
	}
	for (int n = 0; n < TLG6_GOLOMB_N_COUNT; n++) {
		int a = 0;
		for (int i = 0; i < 9; i++)
			for (int j = 0; j < golomb_compressed[n][i]; j++)
				golomb_bit_length_table[a++][n] = (int8_t)i;
	}
	tables_ready = 1;
}

#define FETCH32(p) ((uint32_t)(p)[0] | ((uint32_t)(p)[1] << 8) | \
                    ((uint32_t)(p)[2] << 16) | ((uint32_t)(p)[3] << 24))

static void tlg6_decode_golomb_first(int8_t *pixelbuf, int pixel_count, uint8_t *bit_pool) {
	int n = TLG6_GOLOMB_N_COUNT - 1, a = 0;
	int bit_pos = 1;
	uint8_t zero = (uint8_t)(*bit_pool & 1 ? 0 : 1);
	int8_t *limit = pixelbuf + (size_t)pixel_count * 4;
	while (pixelbuf < limit) {
		uint32_t t = FETCH32(bit_pool) >> bit_pos;
		int bit_count = leading_zero_table[t & (LZ_TABLE_SIZE - 1)], b = bit_count;
		while (!b) {
			bit_count += LZ_TABLE_BITS;
			bit_pos += LZ_TABLE_BITS;
			bit_pool += bit_pos >> 3;
			bit_pos &= 7;
			t = FETCH32(bit_pool) >> bit_pos;
			b = leading_zero_table[t & (LZ_TABLE_SIZE - 1)];
			bit_count += b;
		}
		bit_pos += b;
		bit_pool += bit_pos >> 3;
		bit_pos &= 7;
		bit_count--;
		int count = 1 << bit_count;
		count += (int)((FETCH32(bit_pool) >> bit_pos) & (count - 1));
		bit_pos += bit_count;
		bit_pool += bit_pos >> 3;
		bit_pos &= 7;
		if (zero) {
			do { *(uint32_t *)pixelbuf = 0; pixelbuf += 4; } while (--count);
			zero ^= 1;
		} else {
			do {
				int k = golomb_bit_length_table[a][n], v, sign;
				t = FETCH32(bit_pool) >> bit_pos;
				bit_count = 0; b = 0;
				if (t) {
					b = leading_zero_table[t & (LZ_TABLE_SIZE - 1)];
					bit_count = b;
					while (!b) {
						bit_count += LZ_TABLE_BITS;
						bit_pos += LZ_TABLE_BITS;
						bit_pool += bit_pos >> 3;
						bit_pos &= 7;
						t = FETCH32(bit_pool) >> bit_pos;
						b = leading_zero_table[t & (LZ_TABLE_SIZE - 1)];
						bit_count += b;
					}
					bit_count--;
				} else {
					bit_pool += 5;
					bit_count = bit_pool[-1];
					bit_pos = 0;
					t = FETCH32(bit_pool);
					b = 0;
				}
				v = (int)((bit_count << k) + (int)((t >> b) & ((1u << k) - 1)));
				sign = (v & 1) - 1;
				v >>= 1;
				a += v;
				*(uint32_t *)pixelbuf = (uint32_t)((uint8_t)((v ^ sign) + sign + 1));
				pixelbuf += 4;
				bit_pos += b;
				bit_pos += k;
				bit_pool += bit_pos >> 3;
				bit_pos &= 7;
				if (--n < 0) { a >>= 1; n = TLG6_GOLOMB_N_COUNT - 1; }
			} while (--count);
			zero ^= 1;
		}
	}
}

static void tlg6_decode_golomb(int8_t *pixelbuf, int pixel_count, uint8_t *bit_pool) {
	int n = TLG6_GOLOMB_N_COUNT - 1, a = 0;
	int bit_pos = 1;
	uint8_t zero = (uint8_t)(*bit_pool & 1 ? 0 : 1);
	int8_t *limit = pixelbuf + (size_t)pixel_count * 4;
	while (pixelbuf < limit) {
		uint32_t t = FETCH32(bit_pool) >> bit_pos;
		int bit_count = leading_zero_table[t & (LZ_TABLE_SIZE - 1)], b = bit_count;
		while (!b) {
			bit_count += LZ_TABLE_BITS;
			bit_pos += LZ_TABLE_BITS;
			bit_pool += bit_pos >> 3;
			bit_pos &= 7;
			t = FETCH32(bit_pool) >> bit_pos;
			b = leading_zero_table[t & (LZ_TABLE_SIZE - 1)];
			bit_count += b;
		}
		bit_pos += b;
		bit_pool += bit_pos >> 3;
		bit_pos &= 7;
		bit_count--;
		int count = 1 << bit_count;
		count += (int)((FETCH32(bit_pool) >> bit_pos) & (count - 1));
		bit_pos += bit_count;
		bit_pool += bit_pos >> 3;
		bit_pos &= 7;
		if (zero) {
			do { *pixelbuf = 0; pixelbuf += 4; } while (--count);
			zero ^= 1;
		} else {
			do {
				int k = golomb_bit_length_table[a][n], v, sign;
				t = FETCH32(bit_pool) >> bit_pos;
				bit_count = 0; b = 0;
				if (t) {
					b = leading_zero_table[t & (LZ_TABLE_SIZE - 1)];
					bit_count = b;
					while (!b) {
						bit_count += LZ_TABLE_BITS;
						bit_pos += LZ_TABLE_BITS;
						bit_pool += bit_pos >> 3;
						bit_pos &= 7;
						t = FETCH32(bit_pool) >> bit_pos;
						b = leading_zero_table[t & (LZ_TABLE_SIZE - 1)];
						bit_count += b;
					}
					bit_count--;
				} else {
					bit_pool += 5;
					bit_count = bit_pool[-1];
					bit_pos = 0;
					t = FETCH32(bit_pool);
					b = 0;
				}
				v = (int)((bit_count << k) + (int)((t >> b) & ((1u << k) - 1)));
				sign = (v & 1) - 1;
				v >>= 1;
				a += v;
				*pixelbuf = (int8_t)((v ^ sign) + sign + 1);
				pixelbuf += 4;
				bit_pos += b;
				bit_pos += k;
				bit_pool += bit_pos >> 3;
				bit_pos &= 7;
				if (--n < 0) { a >>= 1; n = TLG6_GOLOMB_N_COUNT - 1; }
			} while (--count);
			zero ^= 1;
		}
	}
}

static uint32_t make_gt_mask(uint32_t a, uint32_t b) {
	uint32_t tmp2 = ~b;
	uint32_t tmp = ((a & tmp2) + (((a ^ tmp2) >> 1) & 0x7f7f7f7f)) & 0x80808080;
	tmp = ((tmp >> 7) + 0x7f7f7f7f) ^ 0x7f7f7f7f;
	return tmp;
}
static uint32_t packed_bytes_add(uint32_t a, uint32_t b) {
	uint32_t tmp = (((a & b) << 1) + ((a ^ b) & 0xfefefefe)) & 0x01010100;
	return a + b - tmp;
}
static uint32_t med2(uint32_t a, uint32_t b, uint32_t c) {
	uint32_t aa_gt_bb = make_gt_mask(a, b);
	uint32_t x = ((a ^ b) & aa_gt_bb);
	uint32_t aa = x ^ a, bb = x ^ b;
	uint32_t n = make_gt_mask(c, bb);
	uint32_t nn = make_gt_mask(aa, c);
	uint32_t m = ~(n | nn);
	return (n & aa) | (nn & bb) | ((bb & m) - (c & m) + (aa & m));
}
static uint32_t med(uint32_t a, uint32_t b, uint32_t c, uint32_t v) {
	return packed_bytes_add(med2(a, b, c), v);
}
static uint32_t tlg6_avg(uint32_t a, uint32_t b, uint32_t c, uint32_t v) {
	uint32_t x = ((a & b) + ((((a ^ b) & 0xfefefefe) >> 1))) + (((a ^ b) & 0x01010101));
	return packed_bytes_add(x, v);
}

typedef struct {
	uint32_t *prevline, *curline;
	int width;
	int start_block, block_limit;
	const uint8_t *filtertypes;
	int skipblockbytes;
	const uint32_t *in;
	uint32_t initialp;
	int oddskip, dir;
} tlg6_line_args;

static void tlg6_decode_line_generic(const tlg6_line_args *args) {
	uint32_t p, up;
	const uint32_t *in = args->in;
	uint32_t *prevline = args->prevline, *curline = args->curline;
	int start_block = args->start_block;
	if (start_block) {
		prevline += (size_t)start_block * TLG6_W_BLOCK_SIZE;
		curline += (size_t)start_block * TLG6_W_BLOCK_SIZE;
		p = curline[-1];
		up = prevline[-1];
	} else {
		p = up = args->initialp;
	}
	in += (size_t)args->skipblockbytes * start_block;
	int step = (args->dir & 1) ? 1 : -1;
	for (int i = start_block; i < args->block_limit; i++) {
		int w = args->width - i * TLG6_W_BLOCK_SIZE;
		if (w > TLG6_W_BLOCK_SIZE) w = TLG6_W_BLOCK_SIZE;
		int ww = w;
		if (step == -1) in += ww - 1;
		if (i & 1) in += args->oddskip * ww;
		uint8_t ft = args->filtertypes[i];
		int filter = ft >> 1;
		int proto2 = ft & 1;
		for (int x = 0; x < w; x++) {
			uint32_t u = *prevline;
			/* Reference extracts each channel as a signed char of the decoded
			 * DWORD, combines on int, then keeps the low byte per channel. */
			int32_t dw = (int32_t)*in;
			int32_t ib = (int8_t)(dw & 0xff);
			int32_t ig = (int8_t)((dw >> 8) & 0xff);
			int32_t ir = (int8_t)((dw >> 16) & 0xff);
			int32_t ia = (int8_t)((dw >> 24) & 0xff);
			int32_t B, G, R;
			switch (filter) {
			case 0:  B = ib; G = ig; R = ir; break;
			case 1:  B = ib + ig; G = ig; R = ir + ig; break;
			case 2:  B = ib; G = ig + ib; R = ir + ib + ig; break;
			case 3:  B = ib + ir + ig; G = ig + ir; R = ir; break;
			case 4:  B = ib + ir; G = ig + ib + ir; R = ir + ib + ir + ig; break;
			case 5:  B = ib + ir; G = ig + ib + ir; R = ir; break;
			case 6:  B = ib + ig; G = ig; R = ir; break;
			case 7:  B = ib; G = ig + ib; R = ir; break;
			case 8:  B = ib; G = ig; R = ir + ig; break;
			case 9:  B = ib + ig + ir + ib; G = ig + ir + ib; R = ir + ib; break;
			case 10: B = ib + ir; G = ig + ir; R = ir; break;
			case 11: B = ib; G = ig + ib; R = ir + ib; break;
			case 12: B = ib; G = ig + ir + ib; R = ir + ib; break;
			case 13: B = ib + ig; G = ig + ir + ib + ig; R = ir + ib + ig; break;
			case 14: B = ib + ig + ir; G = ig + ir; R = ir + ib + ig + ir; break;
			case 15: B = ib; G = ig + (ib << 1); R = ir + (ib << 1); break;
			default: return;
			}
			uint32_t v = ((uint32_t)(R & 0xff) << 16) |
			             ((uint32_t)(G & 0xff) << 8) |
			             (uint32_t)(B & 0xff) |
			     ((uint32_t)(ia & 0xff) << 24);
			p = proto2 ? tlg6_avg(p, u, up, v) : med(p, u, up, v);
			up = u;
			*curline++ = p;
			prevline++;
			in += step;
		}
		if (step == 1)
			in += args->skipblockbytes - ww;
		else
			in += args->skipblockbytes + 1;
		if (i & 1) in -= args->oddskip * ww;
	}
}

static int decode_tlg6(const uint8_t *d, size_t len, const char *out_path) {
	/* Header: 11-byte magic, then colors(1)+flags(3), w(4), h(4), max_bit(4). */
	if (len < 32) return -1;
	tlg6_init_tables();
	int colors = d[11];
	if (colors != 1 && colors != 3 && colors != 4) return -1;
	if (d[12] != 0 || d[13] != 0 || d[14] != 0) return -1;
	uint32_t width, height, max_bit_length;
	memcpy(&width, d + 15, 4);
	memcpy(&height, d + 19, 4);
	memcpy(&max_bit_length, d + 23, 4);
	int x_block_count = (int)((width - 1) / TLG6_W_BLOCK_SIZE) + 1;
	int y_block_count = (int)((height - 1) / TLG6_H_BLOCK_SIZE) + 1;
	int main_count = (int)width / TLG6_W_BLOCK_SIZE;
	(void)main_count;

	size_t pos = 27;
	if (pos >= len) return -1;
	uint32_t filt_size; memcpy(&filt_size, d + pos, 4); pos += 4;
	if (pos + filt_size > len) return -1;
	uint8_t *filter_types = (uint8_t *)calloc((size_t)x_block_count * y_block_count + 16, 1);
	uint8_t *lzss_text = (uint8_t *)malloc(4096);
	/* krkrz initializes the chroma-filter LZSS window with a fixed pattern;
	 * matches can reference it before any bytes are written. */
	{
		uint32_t *p32 = (uint32_t *)lzss_text;
		uint32_t i, j;
		for (i = 0; i < 0x01010101u * 32; i += 0x01010101u)
			for (j = 0; j < 0x01010101u * 16; j += 0x01010101u) {
				uint32_t pair[2] = {i, j};
				memcpy(p32, pair, sizeof(pair));
				p32 += 2;
			}
	}
	tlg5_decompress_slide(filter_types, d + pos, (int)filt_size, lzss_text, 0);
	pos += filt_size;

	uint32_t *zeroline = (uint32_t *)malloc((size_t)width * 4);
	uint32_t fill = (colors == 3) ? 0xff000000u : 0u;
	for (uint32_t x = 0; x < width; x++) zeroline[x] = fill;
	uint32_t *pixelbuf = (uint32_t *)malloc(sizeof(uint32_t) * (size_t)width * TLG6_H_BLOCK_SIZE + 4);
	uint8_t *bit_pool = (uint8_t *)malloc((size_t)max_bit_length / 8 + 8);
	uint32_t *image = (uint32_t *)malloc((size_t)width * height * 4);
	if (!filter_types || !lzss_text || !zeroline || !pixelbuf || !bit_pool || !image) goto fail;

	const uint32_t *prevline = zeroline;
	for (uint32_t y = 0; y < height; y += TLG6_H_BLOCK_SIZE) {
		uint32_t ylim = y + TLG6_H_BLOCK_SIZE;
		if (ylim >= height) ylim = height;
		int pixel_count = (int)((ylim - y) * width);
		for (int c = 0; c < colors; c++) {
			if (pos + 4 > len) goto fail;
			uint32_t bit_length; memcpy(&bit_length, d + pos, 4); pos += 4;
			int method = (int)((bit_length >> 30) & 3);
			bit_length &= 0x3fffffff;
			if (method != 0) goto fail;
			uint32_t byte_length = bit_length / 8 + (bit_length % 8 ? 1 : 0);
			if (pos + byte_length > len) goto fail;
			memcpy(bit_pool, d + pos, byte_length);
			pos += byte_length;
			if (c == 0 && colors != 1)
				tlg6_decode_golomb_first((int8_t *)pixelbuf, pixel_count, bit_pool);
			else
				tlg6_decode_golomb((int8_t *)pixelbuf + c, pixel_count, bit_pool);
		}
		const uint8_t *ft = filter_types + (size_t)(y / TLG6_H_BLOCK_SIZE) * x_block_count;
		int skipbytes = (int)((ylim - y) * TLG6_W_BLOCK_SIZE);
		for (uint32_t yy = y; yy < ylim; yy++) {
			uint32_t *curline = image + (size_t)yy * width;
			/* Each row of the y-block reads its slice of the decoded buffer
			 * (krkrz: start = W_BLOCK_SIZE * (yy - y)). */
			int start_row = (int)(yy - y);
			tlg6_line_args args;
			args.prevline = (uint32_t *)prevline;
			args.curline = curline;
			args.width = (int)width;
			if (main_count) {
				args.start_block = 0;
				args.block_limit = main_count;
			} else {
				args.start_block = 0;
				args.block_limit = 0;
			}
			args.filtertypes = ft;
			args.skipblockbytes = skipbytes;
			args.in = pixelbuf + (size_t)TLG6_W_BLOCK_SIZE * start_row;
			args.initialp = (colors == 3) ? 0xff000000u : 0u;
			args.oddskip = (int)((ylim - yy - 1) - (yy - y));
			args.dir = (int)((yy & 1) ^ 1);
			if (main_count)
				tlg6_decode_line_generic(&args);
			if (main_count != x_block_count) {
				int ww = width - main_count * TLG6_W_BLOCK_SIZE;
				if (ww > TLG6_W_BLOCK_SIZE) ww = TLG6_W_BLOCK_SIZE;
				args.start_block = main_count;
				args.block_limit = x_block_count;
				args.in = pixelbuf + (size_t)ww * start_row;
				tlg6_decode_line_generic(&args);
			}
			prevline = curline;
		}
	}
	int rc = png_write(out_path, (int)width, (int)height, (const uint8_t *)image);
	free(filter_types); free(lzss_text); free(zeroline); free(pixelbuf); free(bit_pool); free(image);
	return rc;
fail:
	free(filter_types); free(lzss_text); free(zeroline); free(pixelbuf); free(bit_pool); free(image);
	return -1;
}

/* ----------------------------------------------------------------------------
 * Container handling: raw TLG5/TLG6, TLG0.0 SDS wrapper, plain PNG payloads.
 * -------------------------------------------------------------------------- */

static int convert_buffer(const uint8_t *d, size_t len, const char *out_path) {
	if (len >= 11 && memcmp(d, "TLG5.0\x00raw\x1a", 11) == 0)
		return decode_tlg5(d, len, out_path);
	if (len >= 11 && memcmp(d, "TLG6.0\x00raw\x1a", 11) == 0)
		return decode_tlg6(d, len, out_path);
	if (len >= 15 && memcmp(d, "TLG0.0\x00sds\x1a", 11) == 0) {
		/* SDS: 11-byte magic, u32 raw length, then a nested raw TLG5/TLG6. */
		uint32_t rawlen; memcpy(&rawlen, d + 11, 4);
		if ((size_t)15 + rawlen > len) return -1;
		return convert_buffer(d + 15, rawlen, out_path);
	}
	if (len >= 8 && memcmp(d, "\x89PNG\r\n\x1a\n", 8) == 0) {
		/* Some .tlg files are already PNG (extractor leftovers); copy as-is. */
		FILE *f = fopen(out_path, "wb");
		if (!f) return -1;
		fwrite(d, 1, len, f);
		fclose(f);
		return 0;
	}
	return -1;
}

/* ----------------------------------------------------------------------------
 * Filesystem plumbing (single file or recursive directory batch).
 * -------------------------------------------------------------------------- */

static int ensure_parent_dir(char *path) {
	char *slash = strrchr(path, '/');
#ifdef _WIN32
	char *bslash = strrchr(path, '\\');
	if (bslash > slash) slash = bslash;
#endif
	if (!slash) return 0;
	*slash = 0;
#ifdef _WIN32
	int rc = _mkdir(path);
#else
	int rc = mkdir(path, 0755);
#endif
	if (rc != 0 && errno != EEXIST) {
		/* Create parents recursively. */
		for (char *p = path + 1; *p; p++) {
			if (*p == '/'
#ifdef _WIN32
			    || *p == '\\'
#endif
			) {
				char saved = *p;
				*p = 0;
#ifdef _WIN32
				_mkdir(path);
#else
				mkdir(path, 0755);
#endif
				*p = saved;
			}
		}
#ifdef _WIN32
		rc = _mkdir(path);
#else
		rc = mkdir(path, 0755);
#endif
		if (rc != 0 && errno != EEXIST) { *slash = '/'; return -1; }
	}
	*slash = '/';
	return 0;
}

static int convert_file(const char *in_path, const char *out_dir, const char *rel_name) {
	FILE *f = fopen(in_path, "rb");
	if (!f) { fprintf(stderr, "tlg2png: cannot open %s\n", in_path); return -1; }
	fseek(f, 0, SEEK_END);
	long sz = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (sz <= 0) { fclose(f); return -1; }
	uint8_t *data = (uint8_t *)malloc((size_t)sz);
	if (!data || fread(data, 1, (size_t)sz, f) != (size_t)sz) { free(data); fclose(f); return -1; }
	fclose(f);

	char out_path[4096];
	snprintf(out_path, sizeof(out_path), "%s/%s", out_dir, rel_name);
	if (ensure_parent_dir(out_path) != 0) { free(data); return -1; }
	/* Output extension: replace a trailing ".tlg" (if any) with ".png". */
	size_t olen = strlen(out_path);
	if (olen > 4 && (out_path[olen - 4] == '.') &&
	    (out_path[olen - 1] == 'g' || out_path[olen - 1] == 'G'))
		memcpy(out_path + olen - 4, ".png", 4);
	else
		strncat(out_path, ".png", sizeof(out_path) - strlen(out_path) - 1);

	int rc = convert_buffer(data, (size_t)sz, out_path);
	free(data);
	if (rc != 0)
		fprintf(stderr, "tlg2png: failed to convert %s\n", in_path);
	return rc;
}

#ifdef _WIN32
static int convert_dir(const char *in_dir, const char *out_dir, const char *rel) {
	char pattern[4096], search[4096];
	snprintf(search, sizeof(search), "%s/%s*", in_dir, rel ? rel : "");
	WIN32_FIND_DATAA fd;
	HANDLE h = FindFirstFileA(search, &fd);
	if (h == INVALID_HANDLE_VALUE) return -1;
	do {
		if (strcmp(fd.cFileName, ".") == 0 || strcmp(fd.cFileName, "..") == 0) continue;
		char in_path[4096], rel_path[4096];
		snprintf(rel_path, sizeof(rel_path), "%s%s%s",
		         rel ? rel : "", rel && *rel ? "/" : "", fd.cFileName);
		snprintf(in_path, sizeof(in_path), "%s/%s", in_dir, rel_path);
		if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
			convert_dir(in_dir, out_dir, rel_path);
		} else {
			size_t n = strlen(fd.cFileName);
			if (n > 4 && _stricmp(fd.cFileName + n - 4, ".tlg") == 0)
				convert_file(in_path, out_dir, rel_path);
		}
	} while (FindNextFileA(h, &fd));
	FindClose(h);
	snprintf(pattern, sizeof(pattern), "%s", "");
	(void)pattern;
	return 0;
}
#else
static int convert_dir(const char *in_dir, const char *out_dir, const char *rel) {
	char search[4096];
	snprintf(search, sizeof(search), "%s/%s", in_dir, rel ? rel : "");
	DIR *dir = opendir(search);
	if (!dir) { fprintf(stderr, "tlg2png: cannot open dir %s\n", search); return -1; }
	struct dirent *ent;
	while ((ent = readdir(dir)) != NULL) {
		if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0) continue;
		char in_path[4096], rel_path[4096];
		snprintf(rel_path, sizeof(rel_path), "%s%s%s",
		         rel ? rel : "", rel && *rel ? "/" : "", ent->d_name);
		snprintf(in_path, sizeof(in_path), "%s/%s", in_dir, rel_path);
		struct stat st;
		if (stat(in_path, &st) != 0) continue;
		if (S_ISDIR(st.st_mode)) {
			convert_dir(in_dir, out_dir, rel_path);
		} else {
			size_t n = strlen(ent->d_name);
			if (n > 4 && strcasecmp(ent->d_name + n - 4, ".tlg") == 0)
				convert_file(in_path, out_dir, rel_path);
		}
	}
	closedir(dir);
	return 0;
}
#endif

int main(int argc, char **argv) {
	crc_init();
	if (argc != 3) {
		fprintf(stderr, "usage: %s <file.tlg|source-dir> <output-dir>\n", argv[0]);
		return 2;
	}
	const char *in = argv[1], *out = argv[2];
	struct stat st;
	if (stat(in, &st) != 0) { fprintf(stderr, "tlg2png: missing %s\n", in); return 1; }
	int rc;
	if (S_ISDIR(st.st_mode)) {
		rc = convert_dir(in, out, NULL);
	} else {
		const char *base = strrchr(in, '/');
#ifdef _WIN32
		const char *bs = strrchr(in, '\\');
		if (bs > base) base = bs;
#endif
		base = base ? base + 1 : in;
		rc = convert_file(in, out, base);
	}
	return rc == 0 ? 0 : 1;
}
