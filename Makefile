# executable is named same as current directory
EXEC=pong
SRCS=$(EXEC).asm
LIB_STR_SRCS=$(wildcard ./lib/*.asm)

# Uncomment the below when testing against ./lib
SRCS+=$(LIB_STR_SRCS)
OBJS=$(subst .asm,.o, $(SRCS))

BITS:=32
ifeq ($(BITS),64)
NASM_FMT=elf64
LD_EMM=elf_x86_64
else
NASM_FMT=elf32
LD_EMM=elf_i386
endif

DBGI=dwarf

all: $(EXEC)

deps:
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/ansi_cursor_hide.asm     > lib/ansi_cursor_hide.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/ansi_cursor_position.asm > lib/ansi_cursor_position.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/ansi_cursor_show.asm     > lib/ansi_cursor_show.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/ansi_term_clear.asm      > lib/ansi_term_clear.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/hex2decimal.asm          > lib/hex2decimal.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/sys_nanosleep.asm        > lib/sys_nanosleep.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/sys_signal.asm           > lib/sys_signal.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/sys_write_stdout.asm     > lib/sys_write_stdout.asm
	curl -L https://raw.githubusercontent.com/thlorenz/lib.asm/master/signals.mac              > lib/signals.mac
	curl -L curl -L https://raw.githubusercontent.com/thlorenz/log.mac/master/log.mac          > lib/log.mac

gdb: clean $(EXEC)
	gdb -- $(EXEC)

.SUFFIXES: .asm .o
.asm.o:
	@nasm -f $(NASM_FMT) -g -F $(DBGI) $< -o $@

$(EXEC): $(OBJS)
	@ld -m $(LD_EMM) -o $@ $^

clean:
	@rm -f $(OBJS) $(EXEC)

.PHONY: all clean gdb
