--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

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

local fs = require('fs')

require('tap')(function(test)
  local logger = require('..')

  local BufferLogger = logger.Logger:extend()
  function BufferLogger:initialize(options)
    logger.Logger.initialize(self, options or {})
    self:_clear()
  end

  function BufferLogger:_clear()
    self._buffer = {}
  end

  function BufferLogger:_write(data, callback)
    table.insert(self._buffer, data)
    if callback then callback() end
  end

  test('test simple writes', function()
    local lg

    lg = BufferLogger:new()
    logger.init(lg)
    logger.nothing('All the world\'s a stage')
    logger.critical('and all the men and women merely players')
    logger.error('they have their exits and their entrances;')
    logger.warning('and one man in his time plays many parts, his')
    logger.info('acts being seven ages.')
    logger.debug('William Shakespeare')
    assert(#lg._buffer == 5)

    lg = BufferLogger:new({ log_level = logger.LEVELS['everything'] })
    logger.init(lg)
    logger.nothing('All the world\'s a stage')
    logger.critical('and all the men and women merely players')
    logger.error('they have their exits and their entrances;')
    logger.warning('and one man in his time plays many parts, his')
    logger.info('acts being seven ages.')
    logger.debug('William Shakespeare')
    assert(#lg._buffer == 6)
  end)

  test('test formatted writes', function()
    local lg, extra_str

    lg = BufferLogger:new()
    logger.init(lg)
    logger.nothingf('All the world\'s a stage')
    logger.criticalf('and all the men and women merely players')
    logger.errorf('they have their exits and their entrances;')
    logger.warningf('and one man in his time plays many parts, his')
    logger.infof('acts being seven ages.')
    logger.debugf('William Shakespeare')
    assert(#lg._buffer == 5)

    extra_str = "hello world"

    lg = BufferLogger:new({ log_level = logger.LEVELS['everything'] })
    logger.init(lg)
    logger.nothingf('All the world\'s a stage: %s', extra_str)
    logger.criticalf('and all the men and women merely players: %s', extra_str)
    logger.errorf('they have their exits and their entrances;: %s', extra_str)
    logger.warningf('and one man in his time plays many parts, his, %s', extra_str)
    logger.infof('acts being seven ages. %s', extra_str)
    logger.debugf('William Shakespeare: %s', extra_str)
    assert(#lg._buffer == 6)
    for _, line in pairs(lg._buffer) do
      assert(line:find(extra_str) > -1)
    end
  end)

  test('test FileLogger', function()
    local logfile = "test-log.txt"
    local flog = logger.FileLogger:new({path = logfile})
    flog:log(logger.LEVELS.error, 'this is an error message')
    flog:log(logger.LEVELS.warning, 'this is a warning message')
    flog:on('close', function()
      assert(fs.existsSync(logfile))
      assert(fs.unlinkSync(logfile))
    end)
    flog:close()
  end)

  test('test StdoutLogger', function()
    logger.init(logger.StdoutLogger:new({log_level=logger.LEVELS.everything}))
    logger.error('this is an error message')
    logger.warning('this is a warning message')
    logger.nothingf('All the world\'s a stage')
    logger.criticalf('and all the men and women merely players')
    logger.errorf('they have their exits and their entrances;')
    logger.warningf('and one man in his time plays many parts, his')
    logger.infof('acts being seven ages.')
    logger.debugf('William Shakespeare')
    logger.close()
  end)

end)
