ENABLE_GNU = 0
ENABLE_ARMCC = 0
ENABLE_MICROLIB = 0
ENABLE_PRINTF_FLOAT = 0
TOOLCHAIN_PATH =
ENABLE_DSP = 0

######################################
# target
######################################
TARGET = target

#######################################
# paths
#######################################
# Build path
BUILD_DIR = build

######################################
# building variables
######################################
# debug build?
DEBUG = 1

GNU_OPT = -pedantic -Wall -Wextra -Wundef -Wunused -Wshadow -Winline -Wpacked -Wcast-qual -Wcast-align -Wc++-compat -Wfloat-equal -Wswitch-enum -Wswitch-default -Wdouble-promotion

ifeq ($(ENABLE_ARMCC), 1)
ifeq ($(ENABLE_GNU), 1)
C_OPT += --gnu
endif # ENABLE_GNU
C_OPT += --c99
ifeq ($(DEBUG), 1)
C_OPT += -g -O0
AS_OPT += -g
else # NDEBUG
C_OPT += -DNDEBUG -O2
endif # DEBUG
else # DISABLE_ARMCC
ifeq ($(ENABLE_GNU), 1)
C_OPT += -std=gnu99
else # DISABLE_GNU
C_OPT += -std=c99
endif # ENABLE_GNU
ifeq ($(DEBUG), 1)
C_OPT += -g -gdwarf-2 -O0
else # NDEBUG
C_OPT += -DNDEBUG -Og
endif # DEBUG
C_OPT += $(GNU_OPT)
AS_OPT += $(GNU_OPT)
endif # ENABLE_ARMCC

#######################################
# binaries
#######################################
#######################################
# binaries
#######################################
ifeq ($(ENABLE_ARMCC), 1)
ifdef TOOLCHAIN_PATH
ARMCC_PATH = $(abspath $(TOOLCHAIN_PATH))
FROMELF = $(ARMCC_PATH)/fromelf
AR = $(ARMCC_PATH)/armar
AS = $(ARMCC_PATH)/armasm
CC = $(ARMCC_PATH)/armcc
LN = $(ARMCC_PATH)/armlink
else # NO TOOLCHAIN_PATH
AR = armar
AS = armasm
CC = armcc
LN = armlink
FROMELF = fromelf
endif # TOOLCHAIN_PATH
else # DISABLE_ARMCC
PREFIX = arm-none-eabi-
ifdef GCC_PATH
CC = $(GCC_PATH)/$(PREFIX)gcc
AS = $(GCC_PATH)/$(PREFIX)gcc -x assembler-with-cpp
CP = $(GCC_PATH)/$(PREFIX)objcopy
SZ = $(GCC_PATH)/$(PREFIX)size
else # NO GCC_PATH
CC = $(PREFIX)gcc
AS = $(PREFIX)gcc -x assembler-with-cpp
CP = $(PREFIX)objcopy
SZ = $(PREFIX)size
endif # GCC_PATH
HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S
endif # ENABLE_ARMCC

######################################
# source
######################################
-include Drivers/Makefile

# ASM sources
ASM_SOURCE = startup_stm32f40_41xxx.s
ifeq ($(ENABLE_ARMCC), 1)
ASM_SOURCES += Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/arm/$(ASM_SOURCE)
else # DISABLE_ARMCC
ASM_SOURCES += Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/gcc_ride7/$(ASM_SOURCE)
endif # ENABLE_ARMCC

# C sources
C_SOURCES += $(wildcard Core/Src/*.c)

#######################################
# CFLAGS
#######################################
# mcu
ifeq ($(ENABLE_ARMCC), 1)
CPU = --cpu Cortex-M4.fp
MCU = $(CPU) --apcs=interwork
else # DISABLE_ARMCC
CPU = -mcpu=cortex-m4
FPU = -mfpu=fpv4-sp-d16
FLOAT-ABI = -mfloat-abi=hard
MCU = $(CPU) -mthumb $(FPU) $(FLOAT-ABI)
endif # ENABLE_ARMCC

# C defines
C_DEFS += -DSTM32F40_41xxx
AS_DEFS += --pd "STM32F40_41xxx SETA 1"
ifeq ($(ENABLE_ARMCC)$(ENABLE_MICROLIB), 11)
C_DEFS += -D__MICROLIB
AS_DEFS += --pd "__MICROLIB SETA 1"
endif # ENABLE_ARMCC

# C includes
C_INCLUDES += -ICore/Inc

# compile flags
ifeq ($(ENABLE_ARMCC), 1)
ASFLAGS += $(MCU) $(AS_DEFS) $(AS_INCLUDES) $(AS_OPT) --cpreproc --xref
ASFLAGS += --depend "$(@:%.o=%.d)" --list "$(@:%.o=%.lst)"
CFLAGS += $(MCU) $(C_DEFS) $(C_INCLUDES) $(C_OPT) --split_sections
CFLAGS += --depend "$(@:%.o=%.d)"
else # DISABLE_ARMCC
ASFLAGS += $(MCU) $(AS_DEFS) $(AS_INCLUDES) $(AS_OPT) -fdata-sections -ffunction-sections
CFLAGS += $(MCU) $(C_DEFS) $(C_INCLUDES) $(C_OPT) -fdata-sections -ffunction-sections
CFLAGS += -MMD -MP -MF"$(@:%.o=%.d)" -Wa,-a,-ad,-alms="$(@:%.o=%.lst)"
endif # ENABLE_ARMCC

#######################################
# LDFLAGS
#######################################
ifeq ($(ENABLE_ARMCC), 1)
# link flags
LDFLAGS += --ro-base 0x08000000 --entry 0x08000000
LDFLAGS += --rw-base 0x20000000 --entry Reset_Handler
LDFLAGS += --first __Vectors
LDFLAGS += --strict --map --xref --symbols --callgraph --summary_stderr
LDFLAGS += --info sizes
LDFLAGS += --info totals
LDFLAGS += --info unused
LDFLAGS += --info veneers
LDFLAGS += --info summarysizes
LDFLAGS += --list $(TARGET).map
# fromelf flags
FROMELF_FLAG += --i32 --base=0x08000000 --output=$(@:%.axf=%.hex)
else # DISABLE_ARMCC
# link script
LDSCRIPT = stm32f4xx_flash.ld
# libraries
LIBS += -lc -lm -lnosys
LIBDIR +=
LDFLAGS += $(MCU) -specs=nano.specs -T$(LDSCRIPT) $(LIBDIR) $(LIBS) -Wl,-Map=$(@:%.elf=%.map),--cref -Wl,--gc-sections
# print floating-point
ifeq ($(ENABLE_PRINTF_FLOAT), 1)
LDFLAGS += -u_printf_float
endif # ENABLE_PRINTF_FLOAT
endif # ENABLE_ARMCC

# default action: build all
ifeq ($(ENABLE_ARMCC), 1)
all: $(BUILD_DIR)/$(TARGET).axf
else # DISABLE_ARMCC
all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin
endif # ENABLE_ARMCC

#######################################
# build the application
#######################################
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(C_SOURCES:.c=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(asm_SOURCES:.S=.o)))
vpath %.S $(sort $(dir $(asm_SOURCES)))
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(ASM_SOURCES:.s=.o)))
vpath %.s $(sort $(dir $(ASM_SOURCES)))

$(BUILD_DIR)/%.o: %.c Makefile | $(BUILD_DIR)
	@echo compiling $(notdir $<)...
	@$(CC) -c $(CFLAGS) $< -o $@

$(BUILD_DIR)/%.o: %.S Makefile | $(BUILD_DIR)
	@echo assembling $(notdir $<)...
ifeq ($(ENABLE_ARMCC), 1)
	@$(AS) $(ASFLAGS) $< -o $@
else # DISABLE_ARMCC
	@$(AS) -c $(CFLAGS) $< -o $@
endif # ENABLE_ARMCC

$(BUILD_DIR)/%.o: %.s Makefile | $(BUILD_DIR)
	@echo assembling $(notdir $<)...
ifeq ($(ENABLE_ARMCC), 1)
	@$(AS) $(ASFLAGS) $< -o $@
else # DISABLE_ARMCC
	@$(AS) -c $(CFLAGS) $< -o $@
endif # ENABLE_ARMCC

ifeq ($(ENABLE_ARMCC), 1)
$(BUILD_DIR)/$(TARGET).axf: $(OBJECTS) Makefile
	@echo linking...
	@$(LN) $(CPU) $^ $(LDFLAGS) -o $@
	@echo creating hex file...
	@$(FROMELF) $@ $(FROMELF_FLAG)
else # DISABLE_ARMCC
$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile
	@echo linking...
	@$(CC) $(OBJECTS) $(LDFLAGS) -o $@
	@$(SZ) $@
$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@echo creating hex file...
	@$(HEX) $< $@
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@echo creating bin file...
	@$(BIN) $< $@
endif # ENABLE_ARMCC

$(BUILD_DIR):
	@mkdir $@

#######################################
# clean up
#######################################
.PHONY: clean
clean:
	-rm -fR $(BUILD_DIR)

#######################################
# dependencies
#######################################
-include $(wildcard $(BUILD_DIR)/*.d)

.PHONY: reset flash format
reset:
	openocd -f openocd.cfg -c init -c halt -c reset -c shutdown
flash:
	openocd -f openocd.cfg -c init -c halt -c "program $(BUILD_DIR)/$(TARGET).hex verify reset exit"
format: Core
	@find $^ -regex '.*\.\(c\|h\)' -exec clang-format -style=file -i {} --verbose \;

# *** EOF ***
