/*
 *	Boot environment for the Z8
 */

typedef void (*boot_t)(void);

#define NULL	0

extern unsigned out(unsigned port, unsigned val);
extern unsigned in(unsigned port);
extern void putchar(unsigned char);
extern int getchar(void);

extern char diskbuf[512];
static unsigned char ide_present;

void puts(register const char *p)
{
	while (*p)
		putchar(*p++);
}

static int strcmp(register char *a, register char *b)
{
	register char ch;
	while((ch = *a) == *b) {
		if (ch == 0)
			return 0;
		a++;
		b++;
	}
	if (ch < *b)
		return -1;
	return 1;
}

unsigned char ramtype;

static void nl(void)
{
	puts("\r\n");
}

static char linebuf[128];

static char *get_line(void)
{
	register char *p = linebuf;
	register char c;
	while (1) {
		c = getchar();
		if ((c == 127 || c == 8) && p != linebuf) {
			p--;
			puts("\010 \010");
			continue;
		}
		if (c == 10 || c == 13) {
			*p = 0;
			nl();
			return linebuf;
		}
		if (c < 32 || c > 126)
			continue;
		if (c >= 'a' && c <= 'z')
			c -= 0x20;
		if (p == linebuf + 127) {
			putchar(7);
			continue;
		}
		*p++ = c;
		putchar(c);
	}
}

static unsigned is_ram(unsigned addr)
{
	register volatile char *p = (volatile char *) addr;
	register char n = *p;
	*p++;
	if (*p != n + 1)
		return 0;
	*p--;
	if (*p != n)
		return 0;
	return 1;
}

char *token(char **ptr)
{
	register char *p = *ptr;
	register char *r;
	while(*p == ' ' || *p == '\t')
		p++;
	r = p;
	if (*p == 0)
		return NULL;
	while(*p != ' ' && *p != '\t' && *p != 0)
		p++;
	if (*p)
		*p++ = 0;
	*ptr = p;
	return r;
}

static int ide_wait_op(register unsigned char mask, register unsigned char val)
{
	register unsigned st = in(0x17);
	register unsigned timeout = 0x4000;

	/* Nonsense status shortcuts */
	if (st == 0x00 || st == 0xFF) {
		puts(" - absent\n");
		return -1;
	}
	while((in(0x17) & mask) != val) {
		if (--timeout) {
			puts(" - no response\n");
			return -1;
		}
	}
	return 0;
}

static int ide_wait_nbusy(void)
{
	return ide_wait_op(0x80, 0x00);
}

static int ide_wait_drdy(void)
{
	return ide_wait_op(0x40, 0x40);
}

static int ide_wait_drq(void)
{
	return ide_wait_op(0x08, 0x08);
}

void probe_ide(void)
{
	register unsigned i;
	register unsigned char *dptr;

	puts("CF CARD: ");
	out(0x16, 0xA0);
	if (ide_wait_nbusy() == -1)
		return;
	/* At this point DRQ should be low */
	if (ide_wait_op(0x08, 0x00))
		return;
	if (ide_wait_drdy() == -1)
		return;
	out(0x11, 0x01);		/* 8bit mode */
	out(0x17, 0xEF);
	if (ide_wait_drdy() == -1)
		return;
	out(0x17, 0xEC);	/* Identify */
	if (ide_wait_drq() == -1)
		return;

	dptr = diskbuf;
	for(i = 0; i < 512; i++)
		*dptr++ = in(0x10);

	/* Check the LBA bit is set, and print the name */
	dptr = diskbuf + 54;		/* Name info */

	if (*dptr) { 
		for (i = 0; i < 20; i++) {
			putchar(dptr[1]);
			putchar(*dptr);
			dptr += 2;
		}
	} else	
		puts("Unknown device");
	ide_present = 1;
	nl();
}		
	
struct cmd {
	const char *name;
	void (*exec)(char *tail);
};

static void cmd_boot(char *p)
{
	register char *dptr;
	register unsigned i;
	if (ide_present == 0) {
		puts("No CF card\r\n");
		return;
	}
	out(0x16,0xE0);
	puts("CF Boot: ");
	if (ide_wait_nbusy() == -1) {
		nl();
		return;
	}
	/* At this point DRQ should be low */
	if (ide_wait_op(0x08, 0x00)) {
		nl();
		return;
	}
	if (ide_wait_drdy() == -1) {
		nl();
		return;
	}
	out(0x12, 1);
	out(0x13, 1);
	out(0x14, 0);
	out(0x15, 0);
	out(0x17, 0x20);	/* Read */
	
	if (ide_wait_drq() == -1) {
		nl();
		return;
	}
	
	dptr  = diskbuf;
	for(i = 0; i < 512; i++)
		*dptr++ = in(0x10);
	if (*diskbuf != 'Z' || diskbuf[1] != 8) {
		puts("not bootable\r\n");
		return;
	}
	puts("OK\r\n");
	/* We have the same C and E mapping so this is safe in split I/D */
	((boot_t)(diskbuf + 2))();
	/* Should not return */
}

struct cmd cmdtab[] = {
	{ "BOOT", cmd_boot },
	{ NULL, NULL }
};

static void run_command(const char *cmd, char *tail)
{
	struct cmd *c = cmdtab;
	while(c->name) {
		if (strcmp(c->name, cmd) == 0) {
			c->exec(tail);
			return;
		}
		c++;
	}
	puts("Unknown command.\r\n");
}
	
/* Non standard main as bootrom passes no args */
void main(void)
{
	char *p;
	register char *c;
	puts("RCBUS Z8 Bootstrap\r\n\r\n");
	/* Now see what sort of memory we have */
	if (is_ram(0x8000))
		ramtype = 0;
	else {
		/* If we are running on the newer split I/D capable MMU then
		   we can waggle 0xFE and move the code segment upper around. This
		   needs asm hooks TODO */
		ramtype = 1;
	}
	if (ramtype == 0)
		puts("32K RAM, 32K ROM System");
	else if (ramtype == 1)
		puts("512K/512K MMU, 56/8K");
	else if (ramtype == 2)
		puts("512K/512K MMU, 56/8K, Split I/D");
	else if (ramtype == 3)
		puts("512K/512K Zeta MMU, 16K banks");
	nl();
	probe_ide();
	nl();
	while (1) {
		puts("> ");
		get_line();
		p = linebuf;
		c = token(&p);
		if (c == NULL)
			continue;
		run_command(c, p);
	}
}
