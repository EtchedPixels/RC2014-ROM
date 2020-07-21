/*
 *	Tweak the base Cubix ROM to stop checksum at FDFF
 */

#define _GNU_SOURCE

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    uint8_t buf[8192];
    uint8_t *p;

    if (read(0, buf, 8192) != 8192) {
        fprintf(stderr, "short rom.\n");
        exit(1);
    }
    p = memmem(buf, 8192, "ROM... ", 7);
    if (p == NULL) {
        fprintf(stderr, "can't find ROM tag to find patch point.\n");
        exit(1);
    }
    p = memmem(p, buf + 8192 - p, "\0\0", 2);
    if (p == NULL) {
        fprintf(stderr, "can't find value to patch - already patched ?\n");
        exit(1);
    }
    *p = 0xFE;
    write(1, buf, 8192);
    return 0;
}