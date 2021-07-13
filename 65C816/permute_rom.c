/*
 *	The board as A15-A8 and A7-A0 flipped over (it's a big win for I/O
 *	and ROM/RAM don't care). However we do need to permute the ROM
 *	image to map
 */
 
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>

static void permute_rom(uint8_t *in, uint8_t *out)
{
    uint8_t *op;
    unsigned int l, h;

    /* Read horizontally and write vertically  line by line */   
    for (l = 0; l < 256; l++) {
        op = out++;
        for (h = 0; h <256; h++) {
            *op = *in++;
            op += 256;
        }
    }
}

int main(int argc, char *argv[])
{
    int i;
    uint8_t in[65536], out[65536];

    for (i = 0; i < 8; i++) {
        if (read(0, in, 65536) != 65536) {
            fprintf(stderr, "ROM too short.\n");
            return 1;
        }
        permute_rom(in, out);
        if (write(1, out, 65536) != 65536) {
            fprintf(stderr, "Unable to write ROM.\n");
            return 1;
        }
    }
    return 0;
}
