all: rom rom512 romsd romsd-flat romsd512 loadsd loadsd-flat

rom: rom.obj
	dd if=rom.obj bs=16384 skip=2 | dd of=rom bs=32768 count=1 conv=sync

romsd: romsd.obj
	dd if=romsd.obj bs=16384 skip=2 | dd of=romsd bs=32768 count=1 conv=sync

rom512: rom.obj
	dd if=rom.obj bs=16384 skip=3 | dd of=rom512 bs=512k count=1 conv=sync

romsd512: romsd.obj
	dd if=romsd.obj bs=16384 skip=3 | dd of=romsd512 bs=512k count=1 conv=sync

loadsd: loadsd.obj
	dd if=loadsd.obj bs=384 count=1 of=loadsd

romsd-flat: romsd-flat.obj
	dd if=romsd-flat.obj of=romsd-flat bs=512k count=1 conv=sync

loadsd-flat: loadsd-flat.obj
	dd if=loadsd-flat.obj bs=1024 skip=60 | dd bs=384 count=1 of=loadsd-flat


rom.obj: rom.s
	as11 rom.s -b

romsd.obj: romsd.s
	as11 romsd.s -b

loadsd.obj: loadsd.s
	as11 loadsd.s -b

romsd-flat.obj: romsd-flat.s
	as11 romsd-flat.s -b

loadsd-flat.obj: loadsd-flat.s
	as11 loadsd-flat.s -b

rom11a: rom11a.obj
	dd if=rom11a.obj bs=16384 skip=2 | dd of=rom11a bs=32768 count=1 conv=sync

rom11a.obj: rom11a.s
	as11 rom11a.s -b

fixconf: fixconf.obj
	dd if=fixconf.obj bs=16384 skip=2 | dd of=fixconf bs=32768 count=1 conv=sync

fixconf.obj: fixconf.s
	as11 fixconf.s -b

loader: loader.obj
	dd if=loader.obj bs=256 skip=2| dd of=loader bs=350 count=1

loader.obj: loader.s
	as11 loader.s -b

clean:
	rm -f fixconf fixconf.obj fixconf.lst *~ *.obj *.lst
	rm -f rom rom512 loadsd
	rm -f romsd512 romsd-flat loadsd-flat
	rm -f rom11a loader

