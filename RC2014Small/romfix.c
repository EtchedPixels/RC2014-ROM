#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static char buf[65536];

int main(int argc, char *argv[])
{
    unsigned int xfb = 0, xfbe = 0, xft = 0, re = 0;
    FILE *sym = fopen("zout/rom.lst", "r");
    if (sym == NULL) {
        perror("zout/rom.lst");
        exit(1);
    }
    while(fgets(buf, 255, sym)) {
        if(strncmp(buf, "xfer_block ", 11) == 0)
            sscanf(buf + 11, "%x", &xfb);
        if(strncmp(buf, "xfer_block_end ", 15) == 0)
            sscanf(buf + 15, "%x", &xfbe);
        if(strncmp(buf, "xfer_buf ", 9) == 0)
            sscanf(buf + 9, "%x", &xft);
        if(strncmp(buf, "rom_end ", 8) == 0)
            sscanf(buf + 8, "%x", &re);
    }
    if (xfb == 0 || xfbe == 0 || xft == 0 || re == 0) {
        fprintf(stderr, "Missing symbol.\n");
        exit(1);
    }
    fclose(sym);
    if (fread(buf, 1, 65536, stdin) <= 0) {
        fprintf(stderr, "Unable to load image.\n");
        exit(1);
    }
    fprintf(stderr, "ROM ends at 0x%04X, %d bytes free.\n",
        re, 8192 - re);
    fprintf(stderr, "Moved %d bytes from 0x%04X to 0x%04X.\n",
        xfbe - xfb, xfb, xft);
    memmove(buf + xft, buf + xfb, xfbe - xfb);
    if (fwrite(buf, 8192, 1, stdout) != 1) {
        fprintf(stderr, "Unable to write image.\n");
        exit(1);
    }
    exit(0);
}
    