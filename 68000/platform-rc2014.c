/*
 *	Implementation for RC2014 with a 68008 processor, 16x50 UART and
 *	CF adapter
 */

#include "ff.h"
#include "diskio.h"
#include "config.h"
#include "system.h"

volatile uint8_t *io = (uint8_t *)0x10000;

int getchar(void)
{
    while(!(io[0xC5] & 0x01));
    return io[0xC0];
}

int putchar(int c)
{
    if (c == '\n')
        putchar('\r');
    while(!(io[0xC5] & 0x20));
    io[0xC0] = c;
    return 0;
}

int constat(void)
{
    if (io[0xC5] & 0x01)
        return 0xFF;
    return 0x00;
}

int conostat(void)
{
    if (io[0xC5] & 0x20)
        return 0xFF;
    return 0x00;
}

void coninit(void)
{
}

/*
 *	CF interface
 */

/*
 *	Disk I/O (low level). Crude prototype - needs error handling etc
 *	then abstracting into a struct disk and installable drivers
 */

#define IDE_REG_BASE		0x10
#define IDE_REG_DATA		(IDE_REG_BASE)
#define IDE_REG_ERR		(IDE_REG_BASE + 1)
#define IDE_REG_FEATURES 	(IDE_REG_BASE + 1)
#define IDE_REG_SEC_COUNT	(IDE_REG_BASE + 2)
#define IDE_REG_LBA(n)		(IDE_REG_BASE + 3 + (n))
#define IDE_REG_DEVHEAD		(IDE_REG_BASE + 6)
#define IDE_REG_STATUS		(IDE_REG_BASE + 7)
#define IDE_REG_COMMAND		(IDE_REG_BASE + 7)

#define IDE_STATUS_ERROR	0x01
#define IDE_STATUS_DRQ		0x08
#define IDE_STATUS_DEVFAULT	0x20
#define IDE_STATUS_READY	0x40
#define IDE_STATUS_BUSY		0x80

#define IDE_CMD_READ_SECTOR	0x20
#define IDE_CMD_WRITE_SECTOR	0x30
#define IDE_CMD_IDENTIFY	0xEC
#define IDE_CMD_SET_FEATURES	0xEF

static int wait_drq(void)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = io[IDE_REG_STATUS];
        if (r & IDE_STATUS_BUSY)
            continue;
        if (r & IDE_STATUS_ERROR)
            return -1;
        if (r & IDE_STATUS_DRQ)
            return 0;
    }
    return -1;
}

static int wait_drdy(void)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = io[IDE_REG_STATUS];
        if (r & IDE_STATUS_BUSY)
            continue;
        if (r & IDE_STATUS_ERROR)
            return -1;
        if (r & IDE_STATUS_READY)
            return 0;
    }
    return -1;
}

static int send_command(uint8_t cmd)
{
    if (wait_drdy())
        return -1;
    io[IDE_REG_COMMAND] = cmd;
    /* and we should be slow enough we can't read too early */
    return 0;
}

static void set_lba(uint32_t lba, uint8_t sel)
{
    wait_drdy();
    io[IDE_REG_LBA(3)] = ((lba >> 24) & 0x0F) | sel;
    wait_drdy();
    io[IDE_REG_LBA(0)] = lba;
    io[IDE_REG_LBA(1)] = lba >> 8;
    io[IDE_REG_LBA(2)] = lba >> 16;
}

static DSTATUS cf_status(struct disk *d)
{
    return 0;
}

static DSTATUS cf_init(struct disk *d)
{
    return 0;
}

static DRESULT cf_ioctl(struct disk *d, BYTE cmd, void *buf)
{
    switch(cmd) {
        case CTRL_SYNC:
            /* TODO: send a flush cache */
            return RES_OK;
        case GET_SECTOR_COUNT:
            /* TODO */
            return RES_OK;
        case GET_SECTOR_SIZE:
            *(DWORD *)buf = 512;
            return RES_OK;
        case GET_BLOCK_SIZE:
            return RES_ERROR;
        case CTRL_TRIM:
            return RES_ERROR;
    }
    return RES_PARERR;
}

static DRESULT cf_read(struct disk *d, uint8_t *buf, LBA_t lba, UINT count)
{
    uint16_t i;
    while(count--) {
        set_lba(lba, d->unit);
        if (send_command(IDE_CMD_READ_SECTOR))
            return RES_ERROR;
        if (wait_drq())
            return RES_ERROR;
        for (i = 0; i < 512; i++)
            *buf++ = io[IDE_REG_DATA];
        lba++;
    }
    return RES_OK;
}

static DRESULT cf_write(struct disk *d, const uint8_t *buf, LBA_t lba, UINT count)
{
    uint16_t i;
    while(count--) {
        set_lba(lba, d->unit);
        if (send_command(IDE_CMD_WRITE_SECTOR))
            return RES_ERROR;
        if (wait_drq())
            return RES_ERROR;
        for (i = 0; i < 512; i++)
            io[IDE_REG_DATA] = *buf++;
        if (wait_drdy())
            return RES_ERROR;
        lba++;
    }
    return RES_OK;
}

static void cf_disk_probe(struct disk *d)
{
    char buf[512];
    char *bp = buf;
    uint16_t i;

    if(wait_drdy())
        goto fail;
    io[IDE_REG_DEVHEAD] = d->unit;
    if (wait_drdy())
        goto fail;
    io[IDE_REG_FEATURES] = 0x01;
    /* FIXME: we need to make send_command distinguish between failure
       and unsupported */
    if (send_command(IDE_CMD_SET_FEATURES))
        goto fail;
    if (send_command(IDE_CMD_IDENTIFY))
        goto fail;
    if(wait_drq())
        goto fail;
    for (i = 0; i < 512; i++)
        *bp++ = io[IDE_REG_DATA];
    if (!(buf[99] & 0x02)) {
        puts("LBA not supported.\n");
        return;
    }
    bp = buf + 0x36;		/* Ident string */
    for(i = 0; i < 20; i++) {
        putchar(bp[1]);
        putchar(*bp);
        bp += 2;
    }
    /* Now look for volumes : TODO */
    putchar('\n');
    disk_register(d);
    return;
fail:
    puts("No drive present.\n");
    return;
}

struct disk cfdisk0 = {
    cf_read,
    cf_write,
    cf_ioctl,
    cf_status,
    cf_init,
    0xE0,
    DISK_PRESENT,
};

struct disk cfdisk1 = {
    cf_read,
    cf_write,
    cf_ioctl,
    cf_status,
    cf_init,
    0xF0,
    DISK_PRESENT,
};

void disk_probe(void)
{
    /* For when we add floppy support */
    disk_reserve();
    disk_reserve();
    /* Now probe the CF adapter */
    puts("cf0: ");
    cf_disk_probe(&cfdisk0);
    puts("cf1: ");
    cf_disk_probe(&cfdisk1);
}
