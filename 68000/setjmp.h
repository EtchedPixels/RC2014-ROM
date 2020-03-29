typedef uint32_t jmp_buf[13];	/* A2-A7/D2-D7/return */
extern int setjmp(jmp_buf __env);
__attribute__((__noreturn__)) void longjmp (jmp_buf __env, int __val);

extern void longjmp(jmp_buf __env, int __rv);
