/*
 *	Implementation for RC2014 with a 68008 processor, 16x50 UART and
 *	CF or PPIDE adapter
 */

#include "ff.h"
#include "diskio.h"
#include "system.h"

static volatile uint8_t *io = (uint8_t *)0x10000;

int getchar(void)
{
    while(!(io[0xC5] & 0x01));
    return io[0xC0];
}

int putchar(int c)
{
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

/* Called very early to set up the console. We did this in the early
   boot ROM asm so all is good */

void coninit(void)
{
}

/*
 *	Memory interface. Use the memory between the end of the ROM working
 *	space and top for programs. As we put the system stack at the very
 *	top allow 2K for that. Avoid the MMU windowed space.
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

static void dump_cf(const char *p)
{
    int i;
    puts(p);
    nl();
    for(i = 1; i < 8; i++) {
        puthexbyte(io[IDE_REG_BASE + i]);
        putchar(' ');
    }
    nl();
}

static int wait_drq(void)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = io[IDE_REG_STATUS];
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
        r = io[IDE_REG_STATUS];
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
    io[IDE_REG_COMMAND] = cmd;
    /* and we should be slow enough we can't read too early */
    return 0;
}

static void set_lba(uint32_t lba, uint8_t sel)
{
    io[IDE_REG_LBA(3)] = ((lba >> 24) & 0x0F) | sel;
    wait_drdy(0);
    io[IDE_REG_LBA(0)] = lba;
    io[IDE_REG_LBA(1)] = lba >> 8;
    io[IDE_REG_LBA(2)] = lba >> 16;
    io[IDE_REG_SEC_COUNT] = 1;
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
            *buf = io[IDE_REG_DATA];
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
            io[IDE_REG_DATA] = *buf++;
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
    io[IDE_REG_DEVHEAD] = d->unit;
    if (wait_drdy(1))
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

/* PPIDE */

#define PPIDE_PPI_BUS_READ	0x92
#define PPIDE_PPI_BUS_WRITE	0x80

#define PPIDE_PPI_WR_LINE	0x20
#define PPIDE_PPI_RD_LINE	0x40

#define PPIDE_REG_DATA		0
#define PPIDE_REG_ERR		1
#define PPIDE_REG_FEATURES 	1
#define PPIDE_REG_SEC_COUNT	2
#define PPIDE_REG_LBA(n)	(3 + (n))
#define PPIDE_REG_DEVHEAD	6
#define PPIDE_REG_STATUS	7
#define PPIDE_REG_COMMAND	7

static DSTATUS ppide_init(struct disk *d)
{
    io[0x23] = PPIDE_PPI_BUS_READ;
    io[0x22] = PPIDE_REG_STATUS;
    return RES_OK;
}

static uint8_t ppide_readb(uint8_t p)
{
    uint8_t r;
    io[0x22] = p | 0x08;
    io[0x22] = p | 0x08 | PPIDE_PPI_RD_LINE;	/* 0x80 ? */
    r = io[0x20];
    io[0x22] = p | 0x08;
    return r;
}

static void ppide_writeb(uint8_t p, uint16_t v)
{
    io[0x23] = PPIDE_PPI_BUS_WRITE;
    io[0x22] = p | 0x08;
    io[0x20] = v;
    io[0x21] = v >> 8;
    io[0x22] = p | PPIDE_PPI_WR_LINE | 0x08;
    io[0x22] = p | 0x08;
    io[0x23] = PPIDE_PPI_BUS_READ;
}

static uint8_t ppide_read_data(uint8_t *p)
{
    unsigned int ct = 256;
    while(ct--) {
        io[0x22] = PPIDE_REG_DATA|PPIDE_PPI_RD_LINE|0x08;
        *p++ = io[0x20];
        *p++ = io[0x21];
        io[0x22] = PPIDE_REG_DATA|0x08;
    }
    return 0;
}

static uint8_t ppide_write_data(const uint8_t *p)
{
    unsigned int ct = 256;
    io[0x22] = PPIDE_REG_DATA | 0x08;
    io[0x23] = PPIDE_PPI_BUS_WRITE;
    while(ct--) {
        io[0x20] = *p++;
        io[0x21] = *p++;
        io[0x22] = PPIDE_REG_DATA|PPIDE_PPI_WR_LINE;
        io[0x22] = PPIDE_REG_DATA | 0x08 ;
    }
    io[0x23] = PPIDE_PPI_BUS_READ;
    return 0;

}    

static void dump_ppide(const char *p)
{
    int i;
    puts(p);
    nl();
    for(i = 1; i < 8; i++) {
        puthexbyte(ppide_readb(i));
        putchar(' ');
    }
    nl();
}

static int ppide_wait_drq(void)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = ppide_readb(PPIDE_REG_STATUS);
        if (r & IDE_STATUS_BUSY)
            continue;
        if (r & IDE_STATUS_ERROR) {
            dump_ppide("Error (DRQ)");
            return -1;
        }
        if (r & IDE_STATUS_DRQ)
            return 0;
    }
    dump_ppide("Timeout (DRQ)");
    return -1;
}

static int ppide_wait_drdy(uint8_t probe)
{
    long ct = 100000;
    uint8_t r;
    while(--ct) {
        r = ppide_readb(PPIDE_REG_STATUS);
        if (r & IDE_STATUS_BUSY)
            continue;
        if (r & IDE_STATUS_ERROR) {
            if (!probe)
                dump_ppide("Error (DRDY)");
            return -1;
        }
        if (r & IDE_STATUS_READY)
            return 0;
    }
    if (!probe)
        dump_ppide("Timeout (DRDY)");
    return -1;
}

static int ppide_send_command(uint8_t cmd)
{
    if (ppide_wait_drdy(0))
        return -1;
    ppide_writeb(PPIDE_REG_COMMAND, cmd);
    /* and we should be slow enough we can't read too early */
    return 0;
}

static void ppide_set_lba(uint32_t lba, uint8_t sel)
{
    ppide_writeb(PPIDE_REG_LBA(3), ((lba >> 24) & 0x0F) | sel);
    ppide_wait_drdy(0);
    ppide_writeb(PPIDE_REG_LBA(0), lba);
    ppide_writeb(PPIDE_REG_LBA(1), lba >> 8);
    ppide_writeb(PPIDE_REG_LBA(2), lba >> 16);
    ppide_writeb(PPIDE_REG_SEC_COUNT, 1);
}

static DSTATUS ppide_status(struct disk *d)
{
    return 0;
}

static DRESULT ppide_ioctl(struct disk *d, BYTE cmd, void *buf)
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

static DRESULT ppide_read(struct disk *d, uint8_t *buf, LBA_t lba, UINT count)
{
    while(count--) {
//        puts("READ LBA ");
//        puthexlong(lba);
//        nl();
        ppide_set_lba(lba, d->unit);
        if (ppide_send_command(IDE_CMD_READ_SECTOR))
            return RES_ERROR;
        if (ppide_wait_drq())
            return RES_ERROR;
        ppide_read_data(buf);
        lba++;
        buf += 512;
//        puts("OK\r\n");
    }
    return RES_OK;
}

static DRESULT ppide_write(struct disk *d, const uint8_t *buf, LBA_t lba, UINT count)
{
    while(count--) {
        ppide_set_lba(lba, d->unit);
        if (ppide_send_command(IDE_CMD_WRITE_SECTOR))
            return RES_ERROR;
        if (ppide_wait_drq())
            return RES_ERROR;
        ppide_write_data(buf);
        if (ppide_wait_drdy(0))
            return RES_ERROR;
        lba++;
        buf += 512;
    }
    return RES_OK;
}

static unsigned int ppide_disk_probe(struct disk *d, const char *x)
{
    uint8_t buf[512];
    uint8_t *bp;
    uint16_t i;

    puts(x);
    if(ppide_wait_drdy(1))
        goto fail;
    ppide_writeb(PPIDE_REG_DEVHEAD, d->unit);
    if (ppide_wait_drdy(1))
        goto fail;
    if (ppide_send_command(IDE_CMD_IDENTIFY))
        goto fail;
    if (ppide_wait_drq())
        goto fail;
    ppide_read_data(buf);
    if (!(buf[99] & 0x02)) {
        puts("LBA not supported.\r\n");
        return 1;
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
    return 1;
fail:
    puts("No PPIDE drive present.\r\n");
    return 0;
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

struct disk ppdisk0 = {
    ppide_read,
    ppide_write,
    ppide_ioctl,
    ppide_status,
    ppide_init,
    0xE0,
    DISK_PRESENT|DISK_BOOTABLE,
};

struct disk ppdisk1 = {
    ppide_read,
    ppide_write,
    ppide_ioctl,
    ppide_status,
    ppide_init,
    0xF0,
    DISK_PRESENT,
};

void disk_probe(void)
{
    /* For when we add floppy support */
    disk_reserve();
    disk_reserve();
    if (ppide_disk_probe(&ppdisk0, "pp0: "))
        ppide_disk_probe(&ppdisk1, "pp1: ");
    else {
        /* Now probe the CF adapter */
        puts("cf0: ");
        cf_disk_probe(&cfdisk0);
        puts("cf1: ");
        cf_disk_probe(&cfdisk1);
    }
}

void platform_init(void)
{
    puts("Platform: RC2014/68008 MMU v0.03\r\n\r\n");
}

/* The disk buffer pointer. In our case it's a hardcoded top of memory space */
uint8_t *diskbuf = (uint8_t *)0x7FE00;
