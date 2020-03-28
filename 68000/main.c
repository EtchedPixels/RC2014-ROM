/*
 *	Although we are in C the normal rules don't exactly apply yet
 *	In particular we need to fix the linker and boot code to put
 *	the data segment somewhere and copy it. For now stick to BSS!
 */
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned long uint32_t;

/* Console I/O: quick prototype */

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

/* Portable console helper functions */

int puts(const char *s)
{
    while(*s)
        putchar(*s++);
    return 0;
}

static void puthexch(uint8_t n)
{
    putchar("0123456789ABCDEF"[n & 0x0F]);
}

int puthexbyte(uint8_t n)
{
    puthexch(n >> 4);
    puthexch(n);
    return 0;
}

int puthexword(uint16_t n)
{
    puthexbyte(n >> 8);
    puthexbyte(n);
    return 0;
}

int puthexlong(uint32_t n)
{
    puthexword(n >> 16);
    puthexword(n);
    return 0;
}

char *getstr(char *buf, int len)
{
    char *bp = buf;
    char *be = buf + len - 1;
    while(1) {
        char c = getchar();
        switch(c) {
            case 8:
            case 127:
                if (bp != buf) {
                    puts("\010 \010");
                    bp--;
                }
                break;
            case 13:
                *bp = 0;
                putchar('\n');
                return buf;
            default:
                if (bp == be)
                    break;
                if (c >= 31 && c < 127) {
                    putchar(c); 
                    *bp++ = c;
                }
                break;
        }
    }
}

void con_init(void)
{
}

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

static int drive;

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

static void set_lba(uint32_t lba)
{
    io[IDE_REG_LBA(0)] = lba;
    io[IDE_REG_LBA(1)] = lba >> 8;
    io[IDE_REG_LBA(2)] = lba >> 16;
    io[IDE_REG_LBA(3)] = ((lba >> 24) & 0x0F) | (drive ? 0xF0 : 0xE0);
}

static int disk_map;

int disk_select(int n)
{
    if (n > 16 || !(disk_map & (1 << n)))
        return -1;
    drive = n;
    return 0;
}

int disk_read_lba(uint32_t lba, uint8_t *buf)
{
    uint16_t i;
    set_lba(lba);
    if (send_command(IDE_CMD_READ_SECTOR))
        return -1;
    wait_drq();
    for (i = 0; i < 512; i++)
        *buf++ = io[IDE_REG_DATA];
    return 0;
}

int disk_write_lba(uint32_t lba, const uint8_t *buf)
{
    uint16_t i;
    set_lba(lba);
    if (send_command(IDE_CMD_WRITE_SECTOR))
        return -1;
    wait_drq();
    for (i = 0; i < 512; i++)
        io[IDE_REG_DATA] = *buf++;
    wait_drdy();    
    return 0;
}

void cf_disk_probe(int n)
{
    char buf[512];
    char *bp = buf;
    uint16_t i;

    if(wait_drdy())
        goto fail;
    io[IDE_REG_DEVHEAD] = n ? 0xF0 : 0xE0;
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
    /* Now look for volumes */
    putchar('\n');
    disk_map |= (1 << n);
    return;
fail:
    puts("No drive present.\n");
    return;
}

void disk_init(void)
{
    uint8_t i;
    puts("hda: ");
    cf_disk_probe(0);
    puts("hdb: ");
    cf_disk_probe(1);
    for (i = 0; i < 16; i++)
        if (disk_select(i) == 0)
            return;
}

/*
 *	Parsing helpers
 */

static int isdrive(char c)
{
    if (c >= 'A' && c <= 'P')
        return 1;
    if (c >= 'a' && c <= 'p')
        return 1;
    return 0;
}

/* Caller must already have checked c is valid */
static int todrive(char c)
{
    return (c & 0x0F) - 1;
}

/*
 *	Entered with stack top of memory, UART initialized and that's
 *	about it.
 */

void rommain(void)
{
    char cmd[256];
    puts("\010RC2014 68008 ROM v0.01\n\n");
    con_init();
    disk_init();
    putchar('\n');
    while(1) {
        putchar('A' + drive);
        puts("> ");
        getstr(cmd, sizeof(cmd));
        if (isdrive(cmd[0]) && cmd[1] == ':' && cmd[2] == 0) {
            if (disk_select(todrive(cmd[0]))) {
                puts("Not found.\n");
                continue;
            }
        }
    }
}

