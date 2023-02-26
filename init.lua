--[[
Copyright 2015 Virgo Agent Toolkit Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
local Emitter = require('core').Emitter
local fs = require('fs')
local timer = require('timer')
local format = require('string').format
local los = require('los')
local table = require('table')
local utils = require('utils')

-------------------------------------------------------------------------------

local reverseMap = function(t)
  local res = {}
  for k, v in pairs(t) do
    res[v] = k
  end
  return res
end

-------------------------------------------------------------------------------

local controls
local theme = {}
local useColors = false
local defaultTheme

local themes = {
  -- nice color theme using 16 ansi colors
  [16] = {
    property     = "0;37", -- white
    sep          = "1;30", -- bright-black
    braces       = "1;30", -- bright-black

    ["nil"]      = "1;30", -- bright-black
    boolean      = "0;33", -- yellow
    number       = "1;33", -- bright-yellow
    string       = "0;32", -- green
    quotes       = "1;32", -- bright-green
    escape       = "1;32", -- bright-green
    ["function"] = "0;35", -- purple
    thread       = "1;35", -- bright-purple

    table        = "1;34", -- bright blue
    userdata     = "1;36", -- bright cyan
    cdata        = "0;36", -- cyan

    err          = "1;31", -- bright red
    success      = "1;33;42", -- bright-yellow on green
    failure      = "1;33;41", -- bright-yellow on red
    highlight    = "1;36;44", -- bright-cyan on blue
  },
  -- nice color theme using ansi 256-mode colors
  [256] = {
    property     = "38;5;253",
    braces       = "38;5;247",
    sep          = "38;5;240",

    ["nil"]      = "38;5;244",
    boolean      = "38;5;220", -- yellow-orange
    number       = "38;5;202", -- orange
    string       = "38;5;34",  -- darker green
    quotes       = "38;5;40",  -- green
    escape       = "38;5;46",  -- bright green
    ["function"] = "38;5;129", -- purple
    thread       = "38;5;199", -- pink

    table        = "38;5;27",  -- blue
    userdata     = "38;5;39",  -- blue2
    cdata        = "38;5;69",  -- teal

    err          = "38;5;196", -- bright red
    success      = "38;5;120;48;5;22",  -- bright green on dark green
    failure      = "38;5;215;48;5;52",  -- bright red on dark red
    highlight    = "38;5;45;48;5;236",  -- bright teal on dark grey
  },
}

local special = {
  [7] = 'a',
  [8] = 'b',
  [9] = 't',
  [10] = 'n',
  [11] = 'v',
  [12] = 'f',
  [13] = 'r'
}

local color, colorize, loadColors

function loadColors(index)
  if index == nil then index = defaultTheme end

  -- Remove the old theme
  for key in pairs(theme) do
    theme[key] = nil
  end

  if index then
    local new = themes[index]
    if not new then error("Invalid theme index: " .. tostring(index)) end
    -- Add the new theme
    for key in pairs(new) do
      theme[key] = new[key]
    end
    useColors = true
  else
    useColors = false
  end

  --[[
  quote    = colorize('quotes', "'", 'string')
  quote2   = colorize('quotes', "'")
  dquote   = colorize('quotes', '"', 'string')
  dquote2  = colorize('quotes', '"')
  obrace   = colorize('braces', '{ ')
  cbrace   = colorize('braces', '}')
  obracket = colorize('property', '[')
  cbracket = colorize('property', ']')
  comma    = colorize('sep', ', ')
  equals   = colorize('sep', ' = ')
  --]]

  controls = {}
  for i = 0, 31 do
    local c = special[i]
    if not c then
      if i < 10 then
        c = "00" .. tostring(i)
      else
        c = "0" .. tostring(i)
      end
    end
    controls[i] = colorize('escape', '\\' .. c, 'string')
  end
  controls[92] = colorize('escape', '\\\\', 'string')
  controls[34] = colorize('escape', '\\"', 'string')
  controls[39] = colorize('escape', "\\'", 'string')
  for i = 128, 255 do
    local c
    if i < 100 then
      c = "0" .. tostring(i)
    else
      c = tostring(i)
    end
    controls[i] = colorize('escape', '\\' .. c, 'string')
  end

end

function color(colorName)
  return '\27[' .. (theme[colorName] or '0') .. 'm'
end

function colorize(colorName, string, resetName)
  return useColors and
    (color(colorName) .. tostring(string) .. color(resetName)) or
    tostring(string)
end
-------------------------------------------------------------------------------


local EOL

if los.type() == 'win32' then
  EOL = '\r\n'
else
  EOL = '\n'
end

local Logger = Emitter:extend()

Logger.LEVELS = {
  ['nothing'] = 0,
  ['critical'] = 1,
  ['error'] = 2,
  ['warning'] = 3,
  ['info'] = 4,
  ['debug'] = 5,
  ['everything'] = 6,
}

Logger.LEVEL_STRS = {
  [1] = ' CRT: ',
  [2] = ' ERR: ',
  [3] = ' WRN: ',
  [4] = ' INF: ',
  [5] = ' DBG: ',
  [6] = ' UNK: ',
}

Logger.REVERSE_LEVELS = reverseMap(Logger.LEVELS)

function Logger:initialize(options)
  self.options = options or {}
  if type(self.log_level)=='string' then
    self.log_level = Logger.LEVELS[self.log_level]
  end
  self.log_level = self.options.log_level or self.LEVELS['info']
  self.callback = options.callback
  if options.cache then
    self.cached = {}
    self.cached[0] = options.threshold or 100
  end
end

function Logger:rotate() end

function Logger:setLogLevel(level)
  self.log_level = level
end

function Logger:getLogLevel()
  return self.log_level
end

function Logger:_log_buf(str)
  if str then
    self:_write(str, self.callback)
  elseif self.callback then
    timer.setImmediate(self.callback)
  end
end

function Logger:_log_format(level, str)
  local bufs = {}
  table.insert(bufs, os.date('%a %b %d %X %Y'))
  table.insert(bufs, self.LEVEL_STRS[level])
  table.insert(bufs, str)
  table.insert(bufs, EOL)

  return table.concat(bufs)
end

function Logger:log(level, str)
  if self.log_level < level then
    return
  end

  if #str == 0 then
    return
  end

  local bufs =  self:_log_format(level, str)

  if self.cached then
    if #self.cached >= self.cached[0] then
      local ival = self.cached[0]
      local str = table.concat(self.cached, '\n')
      self:_log_buf(str)
      self.cached = {}
      self.cached[0] = ival
    else
      self.cached[#self.cached+1] = bufs
      self:_log_buf() -- fire callback
    end
  else
    self:_log_buf(bufs)
  end

  if level == self.LEVELS['critical'] then
    io.stderr:write(bufs)
  end
end

function Logger:logf(level, fmt, ...)
  self:log(level, format(fmt, ...))
end

-------------------------------------------------------------------------------

local FileLogger = Logger:extend()
function FileLogger:initialize(options)
  Logger.initialize(self, options)
  assert(self.options.path, "path is missing")
  self._path = self.options.path
  self.options.flags = self.options.flags or 'a+'
  if options.basic then
    self._stream = assert(io.open(self._path, self.options.flags))
  else
    self._stream = fs.WriteStream:new(self._path, self.options)
  end
  self:on('finish', utils.bind(self.close, self))
end

function FileLogger:close(cb)
  if self.options.basic then
    self._stream:close()
    if cb then cb() end
  else
    self._stream:_end(cb)
  end
end

function FileLogger:_write(data, callback)
  if self.options.basic then
    self._stream:write(data)

    if callback then
      timer.setImmediate(callback)
    end
  else
    self._stream:write(data, callback)
  end
end

function FileLogger:rotate()

  if self.options.basic then
    self._stream:flush()
    self._stream:close()
    self._stream = assert(io.open(self._path, self.options))
  else
    local function reopenCallback()
      self._stream:uncork()
      self:emit('rotated')
    end

    self._stream:cork() -- buffer writes
    self._stream:once('open', reopenCallback)
    self._stream:open() -- reopen file
  end
end

-------------------------------------------------------------------------------

--[[
options:
  fd: {integer?} file descriptor
--]]

local ConsoleLogger = Logger:extend()
function ConsoleLogger:initialize(options)
  assert(type(options)=='table')
  assert(options.fd==1 or options.fd==2)
  loadColors()

  ConsoleLogger.LEVEL_STRS = {
    [1] = colorize('err', ' CRT: '),
    [2] = colorize('err', ' ERR: '),
    [3] = colorize('failure', ' WRN: '),
    [4] = colorize('success', ' INF: '),
    [5] = colorize('highlight', ' DBG: '),
    [6] = colorize('highlight', ' UNK: '),
  }
  Logger.initialize(self, options)
end

function ConsoleLogger:close(cb)
  if cb then cb() end
end

function ConsoleLogger:_write(data, callback)
  io.stdout:write(data)
  io.stdout:flush()
  if callback then callback() end
end

local StdoutLogger = ConsoleLogger:extend()
function StdoutLogger:initialize(options)
  options = options or {}
  options.fd = options.fd or 1
  ConsoleLogger.initialize(self, options)
end

local StderrLogger = ConsoleLogger:extend()
function StderrLogger:initialize(options)
  options = options or {}
  options.fd = options.fd or 2
  ConsoleLogger.initialize(self, options)
end
-------------------------------------------------------------------------------

local M = {}
local function init(stream)
  for k, i in pairs(stream.LEVELS) do
    M[k] = utils.bind(stream.log, stream, i)
    M[k .. 'f'] = utils.bind(stream.logf, stream, i)
    M[k:upper()] = i
  end
  M.log = utils.bind(stream.log, stream)
  M.logf = utils.bind(stream.logf, stream)
  M.rotate = utils.bind(stream.rotate, stream)
  M.instance = stream
end

local function close()
  if M.instance then
    M.instance:close()
    M.instance = nil
  end
end

-------------------------------------------------------------------------------

M.LEVELS = Logger.LEVELS

-- Default Logger
M.DefaultLogger = StdoutLogger:new()

-- Base Logger
M.Logger = Logger

-- File Logger
M.FileLogger = FileLogger

-- Stderr Logger
M.StdoutLogger = StdoutLogger

-- Sets up M[LOGGER_LEVELS] for easy logging
M.init = init

-- Close stream inited
M.close = close

init(M.DefaultLogger)

return M

