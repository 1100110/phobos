# Makefile to build linux D runtime library libphobos2.a and its unit test
#
# make clean => removes all targets built by the makefile
#
# make zip => creates a zip file of all the sources (not targets)
# referred to by the makefile, including the makefile
#
# make release => makes release build of the library (this is also the
# default target)
#
# make debug => makes debug build of the library
#
# make unittest => builds all unittests (for both debug and release)
# and runs them
#
# make html => makes html documentation
#
# make install => copies library to /usr/lib

# Configurable stuff, usually from the command line
#
# OS can be linux, win32, win32remote, win32wine, osx, or freebsd. If left
# blank, the system will be determined by using uname

ifeq (,$(OS))
    OS:=$(shell uname)
    ifeq (Darwin,$(OS))
        OS:=osx
    else
        ifeq (Linux,$(OS))
            OS:=linux
        else
            ifeq (FreeBSD,$(OS))
                OS:=freebsd
            else
                $(error Unrecognized or unsupported OS for uname: $(OS))
            endif
        endif
    endif
endif

# For now, 32 bit is the default model
ifeq (,$(MODEL))
	MODEL:=32
endif

# Configurable stuff that's rarely edited
DRUNTIME_PATH = ../druntime
ZIPFILE = phobos.zip
ROOT_OF_THEM_ALL = generated
ROOT = $(ROOT_OF_THEM_ALL)/$(OS)/$(BUILD)/$(MODEL)
# Documentation-related stuff
DOCSRC = ../docsrc
WEBSITE_DIR = ../web/2.0
DOC_OUTPUT_DIR = $(WEBSITE_DIR)/phobos
STYLECSS_SRC = $(DOCSRC)/style.css
STYLECSS_TGT = $(WEBSITE_DIR)/style.css
SRC_DOCUMENTABLES = phobos.d $(addsuffix .d,$(STD_MODULES))
STDDOC = $(DOCSRC)/std.ddoc
DDOCFLAGS=-version=ddoc -d -c -o- $(STDDOC) -I$(DRUNTIME_PATH)/import $(DMDEXTRAFLAGS)

# Variable defined in an OS-dependent manner (see below)
CC =
DMD =
DDOC =
CFLAGS =
DFLAGS =

# BUILD can be debug or release, but is unset by default; recursive
# invocation will set it. See the debug and release targets below.
BUILD =

# Fetch the makefile name, will use it in recursive calls
MAKEFILE:=$(lastword $(MAKEFILE_LIST))

# Set DRUNTIME name and full path
ifeq (,$(findstring win,$(OS)))
	DRUNTIME = $(DRUNTIME_PATH)/lib/libdruntime.a
else
	DRUNTIME = $(DRUNTIME_PATH)/lib/druntime.lib
endif

# Set CC and DMD
ifeq ($(OS),win32wine)
	CC = wine $(HOME)/dmc/bin/dmc.exe
	DMD = wine $(HOME)/dmd2/windows/bin/dmd.exe
	RUN = wine
else
	ifeq ($(OS),win32remote)
		DMD = ssh 206.125.170.138 "cd code/dmd/phobos && dmd"
		CC = ssh 206.125.170.138 "cd code/dmd/phobos && dmc"
	else
		DMD = dmd
		ifeq ($(OS),win32)
			CC = dmc
		else
			CC = cc
		endif
	endif
	RUN =
endif

# Set CFLAGS
ifeq ($(CC),cc)
	CFLAGS += -m$(MODEL)
	ifeq ($(BUILD),debug)
		CFLAGS += -g
	else
		CFLAGS += -O3
	endif
endif

# Set DFLAGS
DFLAGS := -I$(DRUNTIME_PATH)/import $(DMDEXTRAFLAGS) -w -d -m$(MODEL)
ifeq ($(BUILD),debug)
	DFLAGS += -g -debug
else
	DFLAGS += -O -release -nofloat
endif

# Set DOTOBJ and DOTEXE
ifeq (,$(findstring win,$(OS)))
	DOTOBJ:=.o
	DOTEXE:=
	PATHSEP:=/
else
	DOTOBJ:=.obj
	DOTEXE:=.exe
	PATHSEP:=$(shell echo "\\")
endif

# Set LINKOPTS
ifeq (,$(findstring win,$(OS)))
    ifeq (freebsd,$(OS))
        LINKOPTS=-L-L$(ROOT)
    else
        LINKOPTS=-L-ldl -L-L$(ROOT)
    endif
else
    LINKOPTS=-L/co $(LIB)
endif

# Set DDOC, the documentation generator
ifeq ($(OS),linux)
    DDOC=wine dmd
else
    DDOC=dmd
endif

# Set LIB, the ultimate target
ifeq (,$(findstring win,$(OS)))
	LIB = $(ROOT)/libphobos2.a
else
	LIB = $(ROOT)/phobos.lib
endif

################################################################################
MAIN = $(ROOT)/emptymain.d

# Stuff in std/
STD_MODULES = $(addprefix std/, algorithm array base64 bigint bitmanip	\
        compiler complex concurrency container contracts conv cpuid		\
        cstream ctype date datetime datebase dateparse demangle			\
        encoding exception file format functional getopt gregorian		\
        intrinsic json loader math mathspecial md5 metastrings mmfile	\
        numeric outbuffer path perf process random range regex regexp	\
        signals socket socketstream stdint stdio stdiobase stream		\
        string syserror system traits typecons typetuple uni uri utf	\
        variant xml zip zlib)

# Other D modules that aren't under std/
EXTRA_MODULES := $(addprefix std/c/, stdarg stdio) $(addprefix etc/c/,	\
        zlib) $(addprefix std/internal/math/, biguintcore biguintnoasm  \
        biguintx86 gammafunction errorfunction)

# OS-specific D modules
EXTRA_MODULES_LINUX := $(addprefix std/c/linux/, linux socket)
EXTRA_MODULES_WIN32 := $(addprefix std/c/windows/, com stat windows		\
		winsock) $(addprefix std/windows/, charset iunknown syserror)
ifeq (,$(findstring win,$(OS)))
	EXTRA_MODULES+=$(EXTRA_MODULES_LINUX)
else
	EXTRA_MODULES+=$(EXTRA_MODULES_WIN32)
endif

# Aggregate all D modules relevant to this build
D_MODULES = crc32 $(STD_MODULES) $(EXTRA_MODULES)
# Add the .d suffix to the module names
D_FILES = $(addsuffix .d,$(D_MODULES))
# Aggregate all D modules over all OSs (this is for the zip file)
ALL_D_FILES = $(addsuffix .d,crc32 $(STD_MODULES) $(EXTRA_MODULES)	\
$(EXTRA_MODULES_LINUX) $(EXTRA_MODULES_WIN32))

# C files to be part of the build
C_MODULES = $(addprefix etc/c/zlib/, adler32 compress crc32 deflate	\
	gzclose gzlib gzread gzwrite infback inffast inflate inftrees trees uncompr zutil)
C_FILES = $(addsuffix .c,$(C_MODULES))
# C files that are not compiled (right now only zlib-related)
C_EXTRAS = $(addprefix etc/c/zlib/, algorithm.txt ChangeLog crc32.h	\
deflate.h example.c inffast.h inffixed.h inflate.h inftrees.h		\
linux.mak minigzip.c osx.mak README trees.h win32.mak zconf.h		\
gzguts.h zlib.3 zlib.h zutil.h)
# Aggregate all C files over all OSs (this is for the zip file)
ALL_C_FILES = $(C_FILES) $(C_EXTRAS)

OBJS = $(addsuffix $(DOTOBJ),$(addprefix $(ROOT)/,$(C_MODULES)))

################################################################################
# Rules begin here
################################################################################

ifeq ($(BUILD),)
# No build was defined, so here we define release and debug
# targets. BUILD is not defined in user runs, only by recursive
# self-invocations. So the targets in this branch are accessible to
# end users.
release :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release
debug :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=debug
unittest :
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=debug unittest
	$(MAKE) --no-print-directory -f $(MAKEFILE) OS=$(OS) MODEL=$(MODEL) BUILD=release unittest
else
# This branch is normally taken in recursive builds. All we need to do
# is set the default build to $(BUILD) (which is either debug or
# release) and then let the unittest depend on that build's unittests.
$(BUILD) : $(LIB)
unittest : $(addsuffix $(DOTEXE),$(addprefix $(ROOT)/unittest/,$(D_MODULES)))
endif

################################################################################

$(ROOT)/%$(DOTOBJ) : %.c
	@[ -d $(dir $@) ] || mkdir -p $(dir $@) || [ -d $(dir $@) ]
	$(CC) -c $(CFLAGS) $< -o$@

$(LIB) : $(OBJS) $(ALL_D_FILES) $(DRUNTIME)
	$(DMD) $(DFLAGS) -lib -of$@ $(DRUNTIME) $(D_FILES) $(OBJS)

ifeq ($(MODEL),64)
DISABLED_TESTS =        \
	std/algorithm   \
	std/complex     \
	std/concurrency \
	std/conv        \
	std/datetime    \
	std/file        \
	std/format      \
	std/math        \
	std/mmfile      \
	std/numeric     \
	std/random      \
	std/range       \
	std/signals     \
	std/stdio       \
	std/stream      \
	std/variant     \
	std/zlib        \
	std/internal/math/biguintnoasm

$(addprefix $(ROOT)/unittest/,$(DISABLED_TESTS)) : 
	@echo Testing $@ - disabled
endif

$(ROOT)/unittest/%$(DOTEXE) : %.d $(LIB) $(ROOT)/emptymain.d
	@echo Testing $@
	@$(DMD) $(DFLAGS) -unittest $(LINKOPTS) $(subst /,$(PATHSEP),"-of$@") \
	 	$(ROOT)/emptymain.d $<
# make the file very old so it builds and runs again if it fails
	@touch -t 197001230123 $@
# run unittest in its own directory
	@$(RUN) $@
# succeeded, render the file new again
	@touch $@

# Disable implicit rule
%$(DOTEXE) : %$(DOTOBJ)

$(ROOT)/emptymain.d : $(ROOT)/.directory
	@echo 'void main(){}' >$@

$(ROOT)/.directory :
	mkdir -p $(ROOT) || exists $(ROOT)
	touch $@

clean :
	rm -rf $(ROOT_OF_THEM_ALL) $(ZIPFILE) $(DOC_OUTPUT_DIR)

zip :
	zip $(ZIPFILE) $(MAKEFILE) $(ALL_D_FILES) $(ALL_C_FILES)

install : release
	sudo cp $(LIB) /usr/lib/

$(DRUNTIME) :
	$(MAKE) -C $(DRUNTIME_PATH) -f posix.mak

###########################################################
# html documentation

$(DOC_OUTPUT_DIR)/%.html : %.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_%.html : std/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_%.html : std/c/%.d $(STDDOC)
	$(DDOC) $(DDOCFLAGS) -Df$@ $<

$(DOC_OUTPUT_DIR)/std_c_linux_%.html : std/c/linux/%.d $(STDDOC)
	wine dmd $(DDOCFLAGS) -Df$@ $<

$(STYLECSS_TGT) : $(STYLECSS_SRC)
	cp $< $@

html : $(addprefix $(DOC_OUTPUT_DIR)/, $(subst /,_,$(subst .d,.html,	\
	$(SRC_DOCUMENTABLES)))) $(STYLECSS_TGT)
	@$(MAKE) -f $(DOCSRC)/linux.mak -C $(DOCSRC) --no-print-directory

rsync-cutting-edge : html
	rsync -avz $(DOC_OUTPUT_DIR)/ d-programming@digitalmars.com:data/cutting-edge/phobos/