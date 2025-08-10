-- license:BSD-3-Clause
-- copyright-holders:MAMEdev Team

---------------------------------------------------------------------------
--
--   rc2014.lua
--
--   RC2014 driver-specific makefile
--   Use make SUBTARGET=rc2014 to build
--
---------------------------------------------------------------------------


--------------------------------------------------
-- Specify all the CPU cores necessary
--------------------------------------------------

CPUS["Z80"] = true
CPUS["Z180"] = true

--------------------------------------------------
-- Specify all the sound cores necessary
--------------------------------------------------

SOUNDS["YM2149"] = true
SOUNDS["AY8910"] = true
SOUNDS["SAMPLES"] = true
SOUNDS["DAC"] = true
SOUNDS["SPEAKER"] = true

--------------------------------------------------
-- specify available video cores
--------------------------------------------------


--------------------------------------------------
-- specify available machine cores
--------------------------------------------------

MACHINES["6850ACIA"] = true
MACHINES["8255"] = true
MACHINES["BANKDEV"] = true
MACHINES["DS1302"] = true
MACHINES["GEN_LATCH"] = true
MACHINES["INPUT_MERGER"] = true
MACHINES["OUTPUT_LATCH"] = true
MACHINES["UPD765"] = true
MACHINES["WATCHDOG"] = true
MACHINES["WD_FDC"] = true
MACHINES["Z80CTC"] = true
MACHINES["Z80DAISY"] = true
MACHINES["Z80PIO"] = true
MACHINES["Z80SIO"] = true

--------------------------------------------------
-- specify available bus cores
--------------------------------------------------

BUSES["RC2014"] = true
BUSES["ATA"] = true
BUSES["RS232"] = true
BUSES["CENTRONICS"] = true

--------------------------------------------------
-- specify available formats
--------------------------------------------------

FORMATS["FLOPPY"] = true


--------------------------------------------------
-- This is the list of files that are necessary
-- for building the RC2014 driver
--------------------------------------------------

function createProjects_mame_rc2014(_target, _subtarget)
	project ("mame_rc2014")
	targetsubdir(_target .. "_" .. _subtarget)
	kind (LIBTYPE)
	uuid (os.uuid("drv-mame-rc2014"))
	addprojectflags()
	precompiledheaders_novs()

	includedirs {
		MAME_DIR .. "src/osd",
		MAME_DIR .. "src/emu",
		MAME_DIR .. "src/devices",
		MAME_DIR .. "src/mame/shared",
		MAME_DIR .. "src/lib",
		MAME_DIR .. "src/lib/util",
		MAME_DIR .. "3rdparty",
		GEN_DIR  .. "mame/layout",
	}

files{
	MAME_DIR .. "src/mame/homebrew/rc2014.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/cf.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/clock.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/edge.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/fdc.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/ide.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/micro.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/modules.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/ram.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/rc2014.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/rom.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/romram.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/rtc.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/serial.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/sound.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/z180cpu.cpp",
	MAME_DIR .. "src/devices/bus/rc2014/z80cpu.cpp",
}
end

function linkProjects_mame_rc2014(_target, _subtarget)
	links {
		"mame_rc2014",
	}
end

