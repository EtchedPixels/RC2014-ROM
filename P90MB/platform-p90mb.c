/*
 *	Implementation for the P90MB with onboard CF and onchip serial
 */

#include "ff.h"
#include "diskio.h"
#include "system.h"

static volatile uint8_t *intio = (uint8_t *)0x80000000;

int getchar(void)
{
    uint8_t c;
    while(!(intio[0x2023] & 0x01));
    c = intio[0x2021];
    intio[0x2023] &= ~0x01;
    return c;
}

int putchar(int c)
{
    while(!(intio[0x2023] & 0x02));
    intio[0x2021] = c;
    intio[0x2023] &= ~0x02;
    return 0x00;
}

int constat(void)
{
    if (intio[0x2023] & 0x01)
        return 0xFF;
    return 0x00;
}

int conostat(void)
{
    if (intio[0x2023] & 0x02)
        return 0xFF;
    return 0x00;
}

/* Called very early to set up the console. We did this in the early
   boot ROM asm so all is good */

void coninit(void)
{
}

/*
 *	Memory interface. Use the memory between the end of the ROM working
 *	space and top for programs. As we put the system stack at the very
 *	top allow 2K for that.
 */

void mem_probe(struct mem *mem)
{
    extern uint8_t _end[];
    mem->mem_base = _end;
    mem->mem_size = (uint8_t *)0x80000 - mem->mem_base - 0x800;
}

/*
 *	CF interface
 */

/*
 *	Disk I/O (low level). Crude prototype - needs error handling etc
 *	then abstracting into a struct disk and installable drivers
 */

#define IDE_REG_BASE		0x01200000
#define IDE_REG_DATA		0
#define IDE_REG_ERR		1
#define IDE_REG_FEATURES 	1
#define IDE_REG_SEC_COUNT	2
#define IDE_REG_LBA(n)		(3 + (n))
#define IDE_REG_DEVHEAD		6
#define IDE_REG_STATUS		7
#define IDE_REG_COMMAND		7

#define IDE_STATUS_ERROR	0x01
#define IDE_STATUS_DRQ		0x08
#define IDE_STATUS_DEVFAULT	0x20
#define IDE_STATUS_READY	0x40
#define IDE_STATUS_BUSY		0x80

#define IDE_CMD_READ_SECTOR	0x20
#define IDE_CMD_WRITE_SECTOR	0x30
#define IDE_CMD_IDENTIFY	0xEC
#define IDE_CMD_SET_FEATURES	0xEF

static volatile uint8_t *cfio = (volatile uint8_t *)IDE_REG_BASE;

static void dump_cf(const char *p)
{
    int i;
    puts(p);
    nl();
    for(i = 1; i < 8; i++) {
        puthexbyte(cfio[i]);
        putchar(' ');
    }
    nl();
}

static int wait_drq(void)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = cfio[IDE_REG_STATUS];
        if (r & IDE_STATUS_BUSY)
            continue;
        if (r & IDE_STATUS_ERROR) {
            dump_cf("Error (DRQ)");
            return -1;
        }
        if (r & IDE_STATUS_DRQ)
            return 0;
    }
    dump_cf("Timeout (DRQ)");
    return -1;
}

static int wait_drdy(uint8_t probe)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = cfio[IDE_REG_STATUS];
        if (r & IDE_STATUS_BUSY)
            continue;
        if (r & IDE_STATUS_ERROR) {
            if (!probe)
                dump_cf("Error (DRDY)");
            return -1;
        }
        if (r & IDE_STATUS_READY)
            return 0;
    }
    if (!probe)
        dump_cf("Timeout (DRDY)");
    return -1;
}

static int send_command(uint8_t cmd)
{
    if (wait_drdy(0))
        return -1;
    cfio[IDE_REG_COMMAND] = cmd;
    /* and we should be slow enough we can't read too early */
    return 0;
}

static void set_lba(uint32_t lba, uint8_t sel)
{
    cfio[IDE_REG_LBA(3)] = ((lba >> 24) & 0x0F) | sel;
    wait_drdy(0);
    cfio[IDE_REG_LBA(0)] = lba;
    cfio[IDE_REG_LBA(1)] = lba >> 8;
    cfio[IDE_REG_LBA(2)] = lba >> 16;
    cfio[IDE_REG_SEC_COUNT] = 1;
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
//        puts("READ LBA ");
//        puthexlong(lba);
//        nl();
        set_lba(lba, d->unit);
        if (send_command(IDE_CMD_READ_SECTOR))
            return RES_ERROR;
        if (wait_drq())
            return RES_ERROR;
        for (i = 0; i < 512; i++) {
            *buf = cfio[IDE_REG_DATA];
//            puthexbyte(*buf);
//            putchar(' ');
//            if ((i & 31) == 31)
//                nl();
            buf++;
        }
        lba++;
//        puts("OK\r\n");
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
            cfio[IDE_REG_DATA] = *buf++;
        if (wait_drdy(0))
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

    if(wait_drdy(1))
        goto fail;
    cfio[IDE_REG_DEVHEAD] = d->unit;
    if (wait_drdy(1))
        goto fail;
    cfio[IDE_REG_FEATURES] = 0x01;
    /* FIXME: we need to make send_command distinguish between failure
       and unsupported */
    if (send_command(IDE_CMD_SET_FEATURES))
        goto fail;
    if (send_command(IDE_CMD_IDENTIFY))
        goto fail;
    if(wait_drq())
        goto fail;
    for (i = 0; i < 512; i++)
        *bp++ = cfio[IDE_REG_DATA];
    if (!(buf[99] & 0x02)) {
        puts("LBA not supported.\r\n");
        return;
    }
    bp = buf + 0x36;		/* Ident string */
    for(i = 0; i < 20; i++) {
        putchar(bp[1]);
        putchar(*bp);
        bp += 2;
    }
    /* Now look for volumes : TODO */
    nl();
    disk_register(d);
    return;
fail:
    puts("No drive present.\r\n");
    return;
}

struct disk cfdisk0 = {
    cf_read,
    cf_write,
    cf_ioctl,
    cf_status,
    cf_init,
    0xE0,
    DISK_PRESENT|DISK_BOOTABLE,
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

void platform_init(void)
{
    puts("Platform: P90MB v0.01\r\n\r\n");
}

/* The disk buffer */

uint8_t *diskbuf = (uint8_t *)0x7FE00;
