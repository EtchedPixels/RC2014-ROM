
		org 0

start:          di
		im 1
		ld a,0F0h
		out (0),a
		xor a
		out (060h),a
		out (090h),a
		ld a,080h
		out (013h),a
		ld a,041h
		out (011h),a
		inc a
		out (012h),a
		ld sp,08000h
		jp 0c210h
