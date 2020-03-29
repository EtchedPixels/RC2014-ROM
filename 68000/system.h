/*
 *	System to platform interface
 */

struct disk {
    DRESULT (*read)(struct disk *d, BYTE *buff, LBA_t sector, UINT count);
    DRESULT (*write)(struct disk *d, const BYTE *buff, LBA_t sector, UINT count);
    DRESULT (*ioctl)(struct disk *d, BYTE cmd, void *buf);
    DSTATUS (*status)(struct disk *d);
    DSTATUS (*init)(struct disk *d);
    BYTE unit;
    BYTE flags;
#define DISK_REMOVABLE		1
#define DISK_MEDIACHANGE	2
#define DISK_MOUNTED		4
#define DISK_PRESENT		8
    void *priv;
    FATFS fs;
};

extern int disk_register(struct disk *d);
extern void disk_reserve(void);
extern void disk_mediachange(struct disk *d);

extern void disk_probe(void);

/*
 *	Console
 */

extern int getchar(void);
extern int putchar(int c);
extern int constat(void);
extern int conostat(void);
extern void coninit(void);

extern int puts(const char *s);
extern int puthexbyte(uint8_t n);
extern int puthexword(uint16_t n);
extern int puthexlong(uint32_t n);
extern int getstr(char *buf, int len);

#define NULL	((void *)0)