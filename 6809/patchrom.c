/*
 *	Perform final fixes on the ROM image
 */

#define _GNU_SOURCE

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BASE 0x19CC

int main(int argc, char *argv[])
{
    static uint8_t buf[8192];
    uint8_t *p;
    uint16_t n;

    if (read(0, buf, 8192) != 8192) {
        fprintf(stderr, "short rom.\n");
        exit(1);
    }
    /* At BASE we have
      0  JMP blah
      3  JMP preboot		- set restart to this
      6  JMP xxx		- old restart vector */
    buf[BASE + 7] = buf[0x1ffe];
    buf[BASE + 8] = buf[0x1fff];
    buf[0x1ffe] = (BASE + 3) >> 8;
    buf[0x1fff] = (BASE + 3) & 0xFF;
    /* Now checksum */
    p = buf;
    while(p < buf + 0x1e00)
        n += *p++;
    buf[0] = n >> 8;
    buf[1] = n & 0xFF;
    /* And write out the resulting image */
    write(1, buf, 8192);
    return 0;
}
