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


-- Set all the device flag setting commands from the block headers

local function selectors_get(path)
	local selector = ""
	for l in io.lines(path) do
		if l:sub(1, 3) == "--@" then
			local pos = l:find(",")
			selector = selector .. l:sub(pos+1) .. "\n"
		end
	end
	return selector
end

local selectors =
		selectors_get(MAME_DIR .. "scripts/src/cpu.lua") ..
		selectors_get(MAME_DIR .. "scripts/src/sound.lua") ..
		selectors_get(MAME_DIR .. "scripts/src/video.lua") ..
		selectors_get(MAME_DIR .. "scripts/src/machine.lua") ..
		selectors_get(MAME_DIR .. "scripts/src/bus.lua") ..
		selectors_get(MAME_DIR .. "scripts/src/formats.lua")

--------------------------------------------------
-- Specify all the CPU cores necessary
--------------------------------------------------

CPUS["Z80"] = true
CPUS["Z180"] = true
-- Additional cores required by optional helpers (disassemblers referenced by linked libs)
CPUS["M6800"] = true
CPUS["M6805"] = true
CPUS["M6809"] = true
CPUS["MCS48"] = true
CPUS["MCS51"] = true
CPUS["MC68HC11"] = true
CPUS["FR"] = true
CPUS["IE15"] = true

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
MACHINES["WATCHDOG"] = true
MACHINES["Z80CTC"] = true
MACHINES["Z80DAISY"] = true
MACHINES["Z80PIO"] = true
MACHINES["Z80SIO"] = true
-- IDE helper
MACHINES["I8255"] = true
-- Intel flash for ROM/RAM
MACHINES["INTELFLASH"] = true

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

-- After setting flags, load selectors to pull in sources (incl. disassemblers)
load(selectors)()


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

