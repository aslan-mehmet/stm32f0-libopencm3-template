##
## This file is part of the libopencm3 project.
##
## Copyright (C) 2009 Uwe Hermann <uwe@hermann-uwe.de>
## Copyright (C) 2010 Piotr Esden-Tempski <piotr@esden.net>
## Copyright (C) 2013 Frantisek Burian <BuFran@seznam.cz>
##
## This library is free software: you can redistribute it and/or modify
## it under the terms of the GNU Lesser General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This library is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Lesser General Public License for more details.
##
## You should have received a copy of the GNU Lesser General Public License
## along with this library.  If not, see <http://www.gnu.org/licenses/>.
##

# Be silent per default, but 'make V=1' will show all compiler calls.
ifneq ($(V),1)
Q		:= @
NULL		:= 2>/dev/null
endif

###############################################################################
# Executables

PREFIX		?= arm-none-eabi

CC		:= $(PREFIX)-gcc
CXX		:= $(PREFIX)-g++
LD		:= $(PREFIX)-gcc
AR		:= $(PREFIX)-ar
AS		:= $(PREFIX)-as
OBJCOPY		:= $(PREFIX)-objcopy
OBJDUMP		:= $(PREFIX)-objdump
GDB		:= $(PREFIX)-gdb
STFLASH		= $(shell which st-flash)
OPT		:= -Os
DEBUG		:= -ggdb3
CSTD		?= -std=c99


###############################################################################
# Source files

OBJS		:= $(addprefix $(BINDIR)/, $(notdir $(SRC_FILES)))
OBJS		:= $(OBJS:.c=.o)



ifeq ($(V),1)
$(info Using $(OPENCM3_DIR) path to library)
endif


# Old style, assume LDSCRIPT exists
DEFS		+= -I$(OPENCM3_DIR)/include
LDFLAGS		+= -L$(OPENCM3_DIR)/lib
LDLIBS		+= -l$(LIBNAME)
LDSCRIPT	?= $(PROJECT_NAME).ld


OPENCM3_SCRIPT_DIR = $(OPENCM3_DIR)/scripts
EXAMPLES_SCRIPT_DIR	= $(OPENCM3_DIR)/../scripts

###############################################################################
# C flags

TGT_CFLAGS	+= $(OPT) $(CSTD) $(DEBUG)
TGT_CFLAGS	+= $(ARCH_FLAGS)
TGT_CFLAGS	+= -Wextra -Wshadow -Wimplicit-function-declaration
TGT_CFLAGS	+= -Wredundant-decls -Wmissing-prototypes -Wstrict-prototypes
TGT_CFLAGS	+= -fno-common -ffunction-sections -fdata-sections

###############################################################################
# C++ flags

TGT_CXXFLAGS	+= $(OPT) $(CXXSTD) $(DEBUG)
TGT_CXXFLAGS	+= $(ARCH_FLAGS)
TGT_CXXFLAGS	+= -Wextra -Wshadow -Wredundant-decls  -Weffc++
TGT_CXXFLAGS	+= -fno-common -ffunction-sections -fdata-sections

###############################################################################
# C & C++ preprocessor common flags

TGT_CPPFLAGS	+= -MD
TGT_CPPFLAGS	+= -Wall -Wundef
TGT_CPPFLAGS	+= $(DEFS)

###############################################################################
# Linker flags

TGT_LDFLAGS		+= --static -nostartfiles
TGT_LDFLAGS		+= -T$(LDSCRIPT)
TGT_LDFLAGS		+= $(ARCH_FLAGS) $(DEBUG)
TGT_LDFLAGS		+= -Wl,-Map=$(BINDIR)/$(*).map -Wl,--cref
TGT_LDFLAGS		+= -Wl,--gc-sections
ifeq ($(V),99)
TGT_LDFLAGS		+= -Wl,--print-gc-sections
endif

###############################################################################
# Used libraries

LDLIBS		+= -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group

###############################################################################
###############################################################################
###############################################################################

.SUFFIXES: .elf .bin .hex .srec .list .map .images
.SECONDEXPANSION:
.SECONDARY:

all: elf

elf: $(BINDIR)/$(PROJECT_NAME).elf
bin: $(BINDIR)/$(PROJECT_NAME).bin
hex: $(BINDIR)/$(PROJECT_NAME).hex
srec: $(BINDIR)/$(PROJECT_NAME).srec
list: $(BINDIR)/$(PROJECT_NAME).list

images: $(BINDIR)/$(PROJECT_NAME).images
flash: $(BINDIR)/$(PROJECT_NAME).stlink-flash

# Either verify the user provided LDSCRIPT exists, or generate it.
ifeq ($(strip $(DEVICE)),)
$(LDSCRIPT):
    ifeq (,$(wildcard $(LDSCRIPT)))
        $(error Unable to find specified linker script: $(LDSCRIPT))
    endif
else
include $(OPENCM3_DIR)/mk/genlink-rules.mk
endif

$(OPENCM3_DIR)/lib/lib$(LIBNAME).a:
ifeq (,$(wildcard $@))
	$(warning $(LIBNAME).a not found, attempting to rebuild in $(OPENCM3_DIR))
	$(MAKE) -C $(OPENCM3_DIR)
endif

# Define a helper macro for debugging make errors online
# you can type "make print-OPENCM3_DIR" and it will show you
# how that ended up being resolved by all of the included
# makefiles.
print-%:
	@echo $*=$($*)

$(BINDIR)/%.images: $(BINDIR)/%.bin $(BINDIR)/%.hex $(BINDIR)/%.srec $(BINDIR)/%.list $(BINDIR)/%.map
	@printf "*** $* images generated ***\n"

$(BINDIR)/%.bin: $(BINDIR)/%.elf
	@printf "  OBJCOPY $(*).bin\n"
	$(Q)$(OBJCOPY) -Obinary $< $@

$(BINDIR)/%.hex: $(BINDIR)/%.elf
	@printf "  OBJCOPY $(*).hex\n"
	$(Q)$(OBJCOPY) -Oihex $<.elf $@.hex

$(BINDIR)/%.srec: $(BINDIR)/%.elf
	@printf "  OBJCOPY $(*).srec\n"
	$(Q)$(OBJCOPY) -Osrec $< $@

$(BINDIR)/%.list: $(BINDIR)/%.elf
	@printf "  OBJDUMP $(*).list\n"
	$(Q)$(OBJDUMP) -S $< > $@

$(BINDIR)/%.elf $(BINDIR)/%.map: $(OBJS) $(LDSCRIPT) $(OPENCM3_DIR)/lib/lib$(LIBNAME).a
	@printf "  LD      $(*).elf\n"
	$(Q)$(LD) $(TGT_LDFLAGS) $(LDFLAGS) $(OBJS) $(LDLIBS) -o $(BINDIR)/$(*).elf

$(BINDIR)/%.o: $(SRC_DIR)/%.c
	@printf "  CC      $(*).c\n"
	@mkdir -p $(BINDIR)
	$(Q)$(CC) $(TGT_CFLAGS) $(CFLAGS) $(TGT_CPPFLAGS) $(CPPFLAGS) -o $@ -c $(SRC_DIR)/$(*).c

clean:
	@printf "  CLEAN\n"
	$(Q)$(RM) -f $(BINDIR)/*

$(BINDIR)/%.stlink-flash: $(BINDIR)/%.bin
	@printf "  FLASH  $<\n"
	$(STFLASH) write $< 0x8000000


.PHONY: images clean elf bin hex srec list

-include $(OBJS:.o=.d)
