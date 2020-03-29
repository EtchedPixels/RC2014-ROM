#include "ff.h"
#include "diskio.h"
#include "config.h"
#include "system.h"

static FRESULT report(FRESULT f);

/* C library helpers */

void *memcpy(void *dest, const void *src, unsigned int len)
{
	uint8_t *dp = dest;
	const uint8_t *sp = src;
	while(len-- > 0)
		*dp++=*sp++;
	return dest;
}

/* Could do with a strcasecmp instead */
int strcmp(const char *a, const char *b)
{
    while(*a == *b) {
        if (*a == 0)
            return 0;
        a++;
        b++;
    }
    if (*a < *b)
        return -1;
    return 1;
}

unsigned int strlen(const char *t)
{
	unsigned int ct = 0;
	while (*t++)
		ct++;
	return ct;
}

unsigned int strnlen(const char *t, unsigned int n)
{
	unsigned int ct = 0;
	while (*t++ && ct++ < n);
	return ct;
}

unsigned int strlcpy(char *dst, const char *src, unsigned int dstsize)
{
  unsigned int len = strnlen(src, dstsize);
  unsigned int cp = len >= dstsize ? dstsize - 1 : len;
  memcpy(dst, src, cp);
  dst[cp] = 0;
  return len;
}

unsigned int strlcat(char *dst, const char *src, unsigned int dstsize)
{
  unsigned int len = strlen(dst);
  /* No room at all: existing string fills the buffer */
  if (len >= dstsize - 1)
    return len + strlen(src);
  return strlcpy(dst + len, src, dstsize - len);
}

char *strrchr(const char *s, int c)
{
    const char *r = NULL;
    while(*s) {
        if (*s == c)
            r = s;
        s++;
    }
    return (char *)r;
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

int putunum(uint32_t n)
{
    char buf[16];
    char *bp = buf + 15;
    *bp-- = 0;
    do {
        *bp-- = (n % 10) + '0';
        n /= 10;
    } while(n);
    bp++;
    puts(bp);
    return 0;
}

int putnum(int32_t n)
{
    if (n < 0) {
        putchar('-');
        n = -n;
    }
    putunum(n);
    return 0;
}

int getstr(char *buf, int len)
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
                return bp - buf;
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

/*
 *	High level disk interface for FATFS
 */

static struct disk *disks[MAXDISK];
static int ndisk = 0;
static int curvol;

int disk_register(struct disk *d)
{
    if (ndisk == MAXDISK)
        return -1;
    disks[ndisk++] = d;
    return 0;
}

void disk_reserve(void)
{
    ndisk++;
}

void disk_mediachange(struct disk *d)
{
    d->flags |= DISK_MEDIACHANGE;
}

DSTATUS disk_status(BYTE drive)
{
    if (!disks[drive])
        return STA_NODISK|STA_NOINIT;
    return disks[drive]->status(disks[drive]);
}

DRESULT disk_read(BYTE drive, BYTE *buff, LBA_t sector, UINT count)
{
    return disks[drive]->read(disks[drive], buff, sector, count);
}

DRESULT disk_write(BYTE drive, const BYTE *buff, LBA_t sector, UINT count)
{
    return disks[drive]->write(disks[drive], buff, sector, count);
}

DRESULT disk_ioctl(BYTE drive, BYTE cmd, void *buf)
{
    return disks[drive]->ioctl(disks[drive], cmd, buf);
}

DSTATUS disk_initialize(BYTE drive)
{
    if (!disks[drive])
        return STA_NODISK|STA_NOINIT;
    return disks[drive]->init(disks[drive]);
}

//PARTITION VolToPart[FF_VOLUMES];

static void disk_init(void)
{
    static char path[3]= "0:";
    uint8_t i;
    uint8_t fv = 255;
    FRESULT r;
    disk_probe();
    for (i = 0; i < MAXDISK; i++) {
        if (disks[i] && (disks[i]->flags & DISK_PRESENT)) {
            path[0] = '0' + i;
            if ((r = f_mount(&disks[i]->fs, path, 1)) == FR_OK) {
                puts("Mounted volume ");
                putchar('0' + i);
                puts(":\n");
                if (fv == 255)
                    fv = i;
            } else
                report(r); 
        }
    }
    if (fv == 255)
        fv = 0;
    path[0] = '0' + fv;
    f_chdrive(path);
    curvol = fv;
}

uint32_t syscall(uint32_t *argp)
{
    uint16_t call = *argp++;
    static char buf[3] = "0:";
    FRESULT r;
    UINT n;

    switch(call) {
        case 0x01:
            return getchar();
        case 0x02:
            putchar(*argp);
            return 1;
        case 0x03:
            return constat();
        case 0x04:
            return conostat();
        case 0x05:
            puts((const char *)*argp);
            return 0;
        case 0x06:
            return getstr((char *)*argp, *(uint8_t *)argp[1]);
        /* We probably want aux/printer here */
        case 0x10:
            return f_open((FIL *)*argp, (const TCHAR *)argp[1], argp[2]);
        case 0x11:
            return f_close((FIL *)*argp);
        case 0x12:
            r = f_read((FIL *)*argp, (void *)argp[1], argp[2], &n);
            if (r)
                return -r;
            return n;
        case 0x13:
            r = f_write((FIL *)*argp, (void *)argp[1], argp[2], &n);
            if (r)
                return -r;
            return n;
        case 0x14:
            return -f_lseek((FIL *)*argp, argp[1]);
        case 0x15:
            return -f_truncate((FIL *)*argp);
        case 0x16:
            return -f_sync((FIL *)*argp);
        case 0x17:
            return f_tell((FIL *)*argp);
        case 0x18:
            return f_eof((FIL *)*argp);
        case 0x19:
            return f_size((FIL *)*argp);
        case 0x1A:
            return f_error((FIL *)*argp);
        case 0x20:
            return -f_opendir((DIR *)argp[0], (const TCHAR *)argp[1]);
        case 0x21:
            return -f_closedir((DIR *)argp[1]);
        case 0x22:
            return -f_readdir((DIR *)argp[0], (FILINFO *)argp[1]);
        case 0x23:
            return -f_findfirst((DIR *)argp[0], (FILINFO *)argp[1],
                (const TCHAR *)argp[2], (const TCHAR *)argp[3]);
        case 0x24:
            return -f_findnext((DIR *)argp[0], (FILINFO *)argp[1]);
        case 0x25:
            return -f_mkdir((const TCHAR *)argp[0]);
        case 0x26:
            return -f_chdir((const TCHAR *)argp[0]);
        case 0x27:
            buf[0] = argp[0] + '0';
            curvol = argp[0] & 0x0F;
            return -f_chdrive(buf);
        case 0x28:
            return -f_getcwd((TCHAR *)argp[0], argp[1]);
        case 0x30:
            return -f_stat((const TCHAR *)argp[0], (FILINFO *)argp[1]);
        case 0x31:
            return -f_unlink((const TCHAR *)argp[0]);
        case 0x32:
            return -f_rename((const TCHAR *)argp[0], (const TCHAR *)argp[1]);
        case 0x33:
            return -f_chmod((const TCHAR *)argp[0], argp[1], argp[2]);
        case 0x34:
            return -f_utime((const TCHAR *)argp[0], (const FILINFO *)argp[1]);
        case 0x35: {
            FATFS *tmp;
            DWORD d;
            r = f_getfree((const TCHAR *)argp[0], &d, &tmp);
            if (r)
                return -r;
            *(DWORD *)argp[1] = (tmp->n_fatent - 2) * tmp->csize;
            *(DWORD *)argp[2] = d * tmp->csize;
            return 512;	/* TODO: true sector size if we ever support non 512 */
        }
        case 0x36:
            return -f_getlabel((const TCHAR *)argp[0], (TCHAR *)argp[1],
                    (DWORD *)argp[2]);
        case 0x37:
            return -f_setlabel((const TCHAR *)argp[0]);
            
        case 0x40:
            return -f_mkfs((const TCHAR *)argp[0], (const MKFS_PARM *)argp[1],
                (void *)argp[2], argp[3]);
    }
    return -FR_INVALID_PARAMETER;
}

/*
 *	Parsing helpers
 */

static int isdrive(char c)
{
    if (c >= '0' && c <= '9')
        return 1;
    return 0;
}

static FRESULT report(FRESULT f)
{
    switch(f) {
    case FR_OK:
        return FR_OK;
    case FR_DISK_ERR:
        puts("I/O error");
        break;
    case FR_INT_ERR:
        puts("Internal error/Corrupt media");
        break;
    case FR_NOT_READY:
        puts("Not ready");
        break;
    case FR_NO_FILE:
        puts("File not found");
        break;
    case FR_NO_PATH:
        puts("Path not found");
        break;
    case FR_INVALID_NAME:
        puts("Invalid name");
        break;
    case FR_DENIED:
        puts("Access denied");
        break;
    case FR_EXIST:
        puts("File already exists");
        break;
    case FR_INVALID_OBJECT:
        puts("Invalid object");
        break;
    case FR_WRITE_PROTECTED:
        puts("Write protected");
        break;
    case FR_INVALID_DRIVE:
        puts("Invalid drive");
        break;
    case FR_NOT_ENABLED:
        puts("Drive not present");
        break;
    case FR_NO_FILESYSTEM:
        puts("No filesystem");
        break;
    case FR_MKFS_ABORTED:
        puts("Mkfs aborted");
        break;
    case FR_TIMEOUT:
        puts("Timed out");
        break;
    case FR_LOCKED:
        puts("Locked");
        break;
    case FR_NOT_ENOUGH_CORE:
        puts("Out of memory");
        break;
    case FR_TOO_MANY_OPEN_FILES:
        puts("Too many open files");
        break;
    case FR_INVALID_PARAMETER:
        puts("Invalid parameter");
        break;
    default:
        puts("Unknown error ");
        puthexword(f);
        break;
    }
    puts(".\n");
    return f;
}

static char *argp;

/* It would also make sense to have a pattern aware version of this
   that uses findfirst/findnext and handed back each match before
   going on an argument. Some care is still needed - eg no pattern in the
   copy tail but a directory name would be needed */

static char *getarg(void)
{
    char *n;
    while(*argp && (*argp == ' ' || *argp == '\t'))
        argp++;
    if (*argp == 0)
        return NULL;
    n = argp;
    while(*argp && !(*argp == ' ' || *argp == '\t'))
        argp++;
    if (*argp)
        *argp++ = 0;
    return n;
}

/* Could do with a long form and patterns */
static void command_dir(char *tail)
{
    DIR dp;
    FILINFO fno;
    DWORD clust;
    FATFS *fs;
    char p[13];
    uint8_t row = 0;
    uint8_t i;
    FRESULT r;
        
    p[12] = 0;
    
    r = f_getlabel(tail, p, &clust);
    if (r) {
        report(r);
        return;
    }
    puts("Volume: ");
    i = 0;
    while (i < 12 && p[i]) {
        putchar(p[i]);
        i++;
    }
    while(i++ < 12)
        putchar(' ');
    
    puts("            Serial ");
    putunum(clust);
    puts("\n\n");

    if (report(f_opendir(&dp, tail)) == FR_OK) {
        while(f_readdir(&dp, &fno) == FR_OK && fno.fname[0]) {
            puts(fno.fname);
            if (++row == 8) {
                row = 0;
                putchar('\n');
            } else
                puts("  ");
        }
        f_closedir(&dp);
        if (row)
            putchar('\n');
        putchar('\n');
        if (report(f_getfree(tail, &clust, &fs)) == FR_OK) {
           putunum((fs->n_fatent - 2) * fs->csize / 2);
           puts("KiB total / ");
           putunum((clust * fs->csize) / 2);
           puts("KiB free.\n");
        }
    }
}

static void output(char *p, unsigned int len)
{
    while(len--)
        putchar(*p++);
}

static void command_type(void)
{
    char *p;
    char buf[512];
    FIL fp;
    UINT l;

    while((p = getarg()) != NULL) {
        puts(p);
        puts(":\n");

        if (report(f_open(&fp, p, FA_READ)) != FR_OK)
            continue;

        do {
            if (report(f_read(&fp, buf, 512, &l)) != FR_OK)
                break;
            output(buf, l);
        } while(l > 0);
        f_close(&fp);
    }
    putchar('\n');
}

static void command_copy(void)
{
    char *s, *d;
    char buf[512];
    FIL src,dst;
    UINT l, w;

    s = getarg();
    d = getarg();
    if (s == NULL || d == NULL || getarg()) {
        puts("COPY [FROM] [TO]\n");
        return;
    }
    if (report(f_open(&src, s, FA_READ)) != FR_OK)
        return;
    if (report(f_open(&dst, d, FA_CREATE_ALWAYS| FA_WRITE)) != FR_OK) {
        f_close(&src);
        return;
    }
    
    do {
        if (report(f_read(&src, buf, 512, &l)) != FR_OK)
            break;
        if (report(f_write(&dst, buf, l, &w)) != FR_OK)
            break;
        if (l != w) {
            puts("Disk full.\n");
            break;
        }
    } while(l > 0);
    report(f_close(&dst));
    f_close(&src);
    putchar('\n');
}

#define MAX_PATH 16
static char *path[MAX_PATH + 1];
static char pathdata[256];

static void command_path(void)
{
    char **pathp = path;
    unsigned int n = 0;
    char *p;
    char *dp = pathdata;

    while(n++ < MAX_PATH && (p = getarg()) != NULL) {
        *pathp++ = dp;
        while(*p)
            *dp++ = *p++;
        *dp++ = 0;
    }
    if (p)
        puts("Too many paths.\n");
    *pathp = NULL;
}

        
static int internal_command(char *cmd, char *tail)
{
    argp = tail;
    if (strcmp(cmd, "CD") == 0) {
        report(f_chdir(tail));
        return 1;
    }
    if (strcmp(cmd, "DIR") == 0) {
        command_dir(tail);
        return 1;
    }
    if (strcmp(cmd, "DEL") == 0) {
        report(f_unlink(tail));
        return 1;
    }
    if (strcmp(cmd, "MKDIR") == 0) {
        report(f_mkdir(tail));
        return 1;
    }
    if (strcmp(cmd, "TYPE") == 0) {
        command_type();
        return 1;
    }
    if (strcmp(cmd, "COPY") == 0) {
        command_copy();
        return 1;
    }
    if (strcmp(cmd, "PATH") == 0) {
        command_path();
        return 1;
    }
    return 0;
}                

static int execute(char *head, char *tail)
{
#if 0
    FIL fp;
    FRESULT r;
    struct exec exh;
    struct mem *mem;
    UINT s;

    if (report(f_open(&fp, head, FA_READ)) != FR_OK)
        return -1;
    r = report(f_read(&fp, (void *)&exh, sizeof(exh), &s));
    if (r != FR_OK || s != sizeof(exh) || !valid_header(&exh)) {
        f_close(&fp);
        return -1;
    }
    mem = allocate(&exh);
    if (mem == NULL) {
        f_close(&fp);
        report(FR_NOT_ENOUGH_CORE);
        return -1;
    }
    /* load binary into mem */
    /* relocate */
    /* and close up */
    f_close(&fp);
    launch(mem);
#endif    
    /* And done when it comes back to us */
    return 0;
}

static char *find_program(char *p, int local)
{
    static char buf[256];
    char *t;
    char **pathp = path;
    int addexe = 0;
    FILINFO fi;

    t = strrchr(p, '/');
    if (t == NULL)
        t = p;
    t = strrchr(t, '.');
    if (t == NULL)
        addexe = 1;

    if (local) {
        while(*pathp) {
            strlcpy(buf, *pathp++, 256);
            strlcat(buf, p, 256);
            if (addexe)
                strlcat(buf, ".exe", 256);
            if (f_stat(buf, &fi) == FR_OK)
                return buf;
        }
    }
    strlcpy(buf, p, 256);
    if (addexe)
        strlcat(buf, ".exe", 256);
    if (f_stat(buf, &fi) == FR_OK)
        return buf;
    return NULL;
}
    
static void process_command(char *p)
{
    char *head;
    char *tail;
    int local = 1;
    while(*p && (*p == ' ' || *p == '\t'))
        p++;
    head = p;
    while(*p && !(*p == ' ' || *p == '\t')) {
        if (*p == '/' || *p == ':')
            local = 0;
        p++;
    }
    if (*p)
        *p++ = 0;
    tail = p;
    if (local && internal_command(head, tail))
        return;
    /* Add suffix if needed, look along path if local */
    head = find_program(head, local);
    if (head && !execute(head, tail))
        return;
    puts("Command not found.\n");
}
    
/*
 *	Entered with stack top of memory, UART initialized and that's
 *	about it.
 */

void rommain(void)
{
    char cmd[256];
    coninit();
    puts("\010RC2014 68008 ROM v0.01\n\n");
    disk_init();
    putchar('\n');
    while(1) {
        putchar('0' + curvol);
        puts("> ");
        getstr(cmd, sizeof(cmd));
        if (isdrive(cmd[0]) && cmd[1] == ':' && cmd[2] == 0) {
            if (report(f_chdrive(cmd)) == FR_OK)
                curvol = cmd[0] - '0';
            continue;
        }
        process_command(cmd);
    }
}

