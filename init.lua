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
end

function Logger:rotate() end

function Logger:setLogLevel(level)
  self.log_level = level
end

function Logger:getLogLevel()
  return self.log_level
end

function Logger:_log_buf(str)
  self:_write(str, self.callback)
end

function Logger:log(level, str)
  if self.log_level < level then
    return
  end

  if #str == 0 then
    return
  end

  local bufs = {}
  table.insert(bufs, os.date('%a %b %d %X %Y'))
  table.insert(bufs, self.LEVEL_STRS[level])
  table.insert(bufs, str)
  table.insert(bufs, EOL)

  bufs = table.concat(bufs)
  self:_log_buf(bufs)

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
  self._stream = fs.WriteStream:new(self._path, self.options)
  self:on('finish', utils.bind(self.close, self))
end

function FileLogger:close()
  self._stream:_end()
end

function FileLogger:_write(data, callback)
  self._stream:write(data, callback)
end

function FileLogger:rotate()
  local reopenCallback

  function reopenCallback()
    self._stream:uncork()
    self:emit('rotated')
  end

  self._stream:cork() -- buffer writes
  self._stream:once('open', reopenCallback)
  self._stream:open() -- reopen file
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
  local colorize = require'pretty-print'.colorize

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

function ConsoleLogger:close()
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

