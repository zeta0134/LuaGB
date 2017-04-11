--
--    ____            _                         _____      _              _
--   / __ \          (_)                       / ____|    | |            | |
--  | |  | |_ __ ___  _  ___ _ __ ___  _ __   | |    _   _| |__   ___  __| |
--  | |  | | '_ ` _ \| |/ __| '__/ _ \| '_ \  | |   | | | | '_ \ / _ \/ _` |
--  | |__| | | | | | | | (__| | | (_) | | | | | |___| |_| | |_) |  __/ (_| |
--   \____/|_| |_| |_|_|\___|_|  \___/|_| |_|  \_____\__,_|_.__/ \___|\__,_|
--
--[[ Copyright (c) 2015-2016, Dr. Charles Mallah; omicroncubed.com ]]
--[[ MIT Licence granted: http://www.opensource.org/licenses/mit-license.php ]]
-- LOVE profiler v1.0
-------------------------------------------------------------------------------|
--
-- Code performance profiling for LOVE.
--
-- Original concept from:
--   ProFi v1.3, by Luke Perkin 2012.
--   MIT Licence http://www.opensource.org/licenses/mit-license.php
--   https://gist.github.com/perky/2838755
--
-- The initial reason for this project was to remove any misinterpretations of
-- code profiling caused by the lengthy measurement time of the ProFi profiler;
-- and to remove the self-profiler functions from the output report.
--
-- I would like note that the profiler code has been substantially rewritten
-- to remove dependence to the quasi 'class' definition, and repetitions in code;
-- thus this profiler has a smaller code footprint and substantially reduced
-- execution time in the range of hundreds of percent to 900% faster.
--
-- The second purpose was to allow slight customisation of the output report,
-- which I have parametrised the output report and rewritten.
--
-- Thirdly, I didn't understand the original memory polling method, so I wrote my
-- own one, and as this is for LOVE programmers, this will use LOVE to measure
-- the vram as well. The polling system is supplied as an example code snippet.
--
-- Caveat, I didn't include an 'inspection' function that ProFi had.
--
--
---------------------------------------|
-- Usage examples:
--
--
-- Print a profile report of a <code> block;
--
--    luagb.require("profiler") -- Run this once per program only
--
--    profilerStart()
--
--    <Code>
--    ... -- Code to profile, code block and/or called functions
--    </Code>
--
--    profilerStop()
--
--    profilerReport("profiler.log")
--
--
-- Profile a <code> block and allow mirror print to a custom print function;
--
--    luagb.require("profiler")
--    function exampleConsolePrint()
--      ... -- A custom thing to print to another file or a console stack
--    end
--
--    attachPrintFunction(exampleConsolePrint, true) -- Function and verbose output
--
--    profilerStart()
--    <Code>
--    ...
--    </Code>
--    profilerStop()
--    profilerReport("profiler.log") -- exampleConsolePrint will be called from this
--
--
-- Profile a <code> block and record system ram usage;
--
--    luagb.require("profiler")
--    profilerStart()
--    <Code>
--    ...
--    </Code>
--    profilerStop()
--    profilerCheckMemory()
--    profilerCheckGraphicsMemory()
--    profilerReport("profiler.log")
--
--
-- Monitor ram and vram usage;
--
--    luagb.require("profiler")
--    function exampleConsolePrint()
--      ... -- A custom thing to print to another file or a console stack
--    end
--
--    attachPrintFunction(exampleConsolePrint, true) -- Function and verbose output
--
--    -- Prepare monitor
--    local profileMonitor  = true
--    local profileInterval = 3 -- Set a polling interval
--    local profileTimer    = profileInterval
--
--    -- Love update
--    function love.update(dt)
--      if profileMonitor == true then
--        profileTimer = profileTimer - dt
--        if profileTimer <= 0 then
--          profilerCheckMemory()
--          profilerCheckGraphicsMemory()
--           profilerPrintMemory()
--           profileTimer = profileInterval
--         end
--       end
--    end
--
--
---------------------------------------|
-- Close:
-- Please configure the profiler output in following section, particularly the
-- location of the profiler source file (if not in the 'main' root source directory).
--
--
-------------------------------------------------------------------------------|


---------------------------------------|
--- Configuration
--
---------------------------------------|

local PROFILER_FILENAME                = "vendor/profiler.lua" -- Location and name of profiler (to remove itself from reports);
                                                        -- if this is in a 'tool' folder, name this as: "tool/profiler.lua"

local EMPTY_TIME                       = "0.0000"       -- Detect empty time, replace with tag below
local emptyToThis                      = "~"

local fileWidth                        = 33
local funcWidth                        = 33
local lineWidth                        = 8
local timeWidth                        = 8
local relaWidth                        = 8
local callWidth                        = 8


---------------------------------------|
--- Performance binds
--
---------------------------------------|

local getTime                          = os.clock
local string                           = string
local debug                            = debug
local table                            = table
local debug                            = debug
local collectgarbage                   = collectgarbage
local filesystem                       = love.filesystem
local getStats                         = love.graphics.getStats


---------------------------------------|
--- Locals
--
---------------------------------------|

local formatOutputHeader               = "| %-" .. fileWidth .. "s: %-" .. funcWidth .. "s: %-" .. lineWidth .. "s: %-" .. timeWidth .. "s: %-" .. relaWidth .. "s: %-" .. callWidth .. "s|\r\n"
local formatOutputTitle                = "%-" .. fileWidth .. "." .. fileWidth .. "s: %-" .. funcWidth .. "." .. funcWidth .. "s: %-" .. lineWidth .. "s" -- File / Function / Line count
local formatOutput                     = "| %s: %-" .. timeWidth .. "s: %-" .. relaWidth .. "s: %-" .. callWidth .. "s|\r\n" -- Time / Relative / Called
local formatTotalTime                  = "TOTAL TIME   = %f s\r\n"
local formatFunLine                    = "%" .. (lineWidth-2) .. "i"
local formatFunTime                    = "%04.4f"
local formatFunRelative                = "%03.2f"
local formatFunCount                   = "%7i"
local formatMemory 	                   = "%s\r\n"
local format2MB  		                   = "%i" -- "%0.1f"
local Header                           = string.format(formatOutputHeader, "FILE", "FUNCTION", "LINE", "TIME", "%", "#")

local TABL_REPORT_CACHE                = {}
local TABL_REPORTS                     = {}
local reportCount                      = 0
local memoryUsage                      = ""
local graphicsMemoryUsage              = ""
local systemInformation                = nil
local startTime                        = 0
local stopTime                         = 0

local printFun                         = nil
local verbosePrint                     = false

---
--
local function functionReport(information)
	local title                          = string.format(formatOutputTitle,
                                            information.short_src or "<C>",
                                            information.name or "Anon",
                                            string.format(formatFunLine, information.linedefined or 0))

	local funcReport                     = TABL_REPORT_CACHE[title]

	if not funcReport then
    funcReport                         = {
                                            title      = string.format(formatOutputTitle,
                                                                       information.short_src or "<C>",
                                                                       information.name or "Anon",
                                                                       string.format(formatFunLine, information.linedefined or 0)),
                                            count      = 0,
                                            timer      = 0,
                                          }

		TABL_REPORT_CACHE[title]          = funcReport
    reportCount                       = reportCount + 1
    TABL_REPORTS[reportCount]         = funcReport
	end

	return funcReport
end

---
--
local onDebugHook = function(hookType)
  local information     = debug.getinfo(2, "nS")
  if hookType == "call" then
    local funcReport    = functionReport(information)
    funcReport.callTime = getTime()
    funcReport.count    = funcReport.count + 1
  elseif hookType == "return" then
    local funcReport    = functionReport(information)
    if funcReport.callTime and funcReport.count > 0 then
      funcReport.timer  = funcReport.timer + (getTime() - funcReport.callTime)
    end
  end
end

--- Return a string of n characters
--
local function charRepetition(n, character)
  local s = ""
  local character = character or " "
  for i = 1, n do
    s = s .. character
  end
  return s
end

---
--
local function singleSearchReturn(str, search)
  for _ in string.gmatch(str, search) do
    printThis = false
    do return true end
  end
  return false
end

local divider = charRepetition(#Header-1, "-") .. "\r\n"


---------------------------------------|
--- Functions
--
---------------------------------------|

--- Attach a print function to the profiler, to receive a single string parameter
--
function attachPrintFunction(fn, verbose)
  printFun = fn
  if verbose ~= nil then
    verbosePrint = verbose
  end
end

---
--
function profilerCheckInformation()
  systemInformation   = getStats()
end

---
--
function profilerCheckMemory(interval)
  memoryUsage         = string.format(formatMemory, string.format(format2MB, collectgarbage("count") / 1024) .. " MB")
end

---
--
function profilerCheckGraphicsMemory()
  systemInformation   = getStats()
  graphicsMemoryUsage = string.format(formatMemory, string.format(format2MB, systemInformation.texturememory / 1024 / 1024) .. " MB")
end

---
--
function profilerPrintMemory(file, divider)
	if memoryUsage ~= "" then
    local outLine = "ram used " .. memoryUsage

    if printFun ~= nil then
      printFun(outLine)
    end

    if graphicsMemoryUsage ~= "" then
      outLine = outLine .. "vram used " .. graphicsMemoryUsage
      if printFun ~= nil then
        printFun("vram used " .. graphicsMemoryUsage)
      end
    end

    if file ~= nil then
      file:write("\r\n" .. divider)
      file:write(outLine)
    end

  end
end
local profilerPrintMemory = profilerPrintMemory

---
--
function profilerAccessInformation()
  return systemInformation
end

---
--
function profilerAccessMemory()
  return memoryUsage
end

---
--
function profilerAccessGraphicsMemory()
  return graphicsMemoryUsage
end

---
--
function profilerStart()
  TABL_REPORT_CACHE                    = {}
	TABL_REPORTS                         = {}
  reportCount                          = 0
	startTime                            = getTime()
	stopTime                             = nil
	debug.sethook(onDebugHook, "cr", 0)
end

---
--
function profilerStop()
	stopTime = getTime()
	debug.sethook()
end

--- Writes the profile report to file
--
function profilerReport(filename)

  if stopTime == nil then
    profilerStop()
  end

	if reportCount > 0 then
		filename                = filename or "profiler.log"

		table.sort(TABL_REPORTS, function(a, b) return a.timer > b.timer end)

    local file              = filesystem.newFile(filename)
    file:open("w")

    if reportCount > 0 then

      local divide          = false
      local totalTime       = stopTime - startTime
      local totalTimeOutput =  string.format(formatTotalTime, totalTime)

      file:write("\r\n" .. divider)
      file:write(totalTimeOutput)
      if printFun ~= nil then
        printFun(totalTimeOutput)
      end
      profilerPrintMemory(file, divider)
      file:write("\r\n" .. divider)
      file:write(Header)
      file:write(divider)

      for i = 1, reportCount do
        local funcReport = TABL_REPORTS[i]

        if funcReport.count > 0 and funcReport.timer <= totalTime then
          local printThis = true

          if PROFILER_FILENAME ~= "" then
            if singleSearchReturn(funcReport.title, PROFILER_FILENAME) then
              printThis = false
            end
          end

          -- Remove line if not needed
          if printThis == true then
            if singleSearchReturn(funcReport.title, "[[C]]") then
              printThis = false
            end
          end

          if printThis == true then
            local count         = string.format(formatFunCount, funcReport.count)
            local timer         = string.format(formatFunTime, funcReport.timer)
            local relTime 		  = string.format(formatFunRelative, (funcReport.timer / totalTime) * 100)
            if divide == false and timer == EMPTY_TIME then
              file:write(divider)
              divide            = true
            end

            -- Replace
            if timer == EMPTY_TIME then
              timer             = emptyToThis
              relTime           = emptyToThis
            end

            -- Build final line
            local outputLine    = string.format(formatOutput, funcReport.title, timer, relTime, count)
            file:write(outputLine)

            -- This is a verbose print to the printFun, however maybe make this smaller for on screen debug?
            if printFun ~= nil and verbosePrint == true then
              printFun(outputLine)
            end

          end
        end
      end

      file:write(divider)

    end

    file:flush()
    file:close()

    if printFun ~= nil then
      printFun("    Report saved to '" .. filename .. "'")
    end

	end

  --
  memoryUsage                      = ""
  graphicsMemoryUsage              = ""

end
