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
local uv = require('uv')

local threshold = 1024*100

require('tap')(function(test)
  local logger = require('..')

  local BufferLogger = logger.Logger:extend()
  function BufferLogger:initialize(options)
    logger.Logger.initialize(self, options or {})
    self._cache = {}
  end

  function BufferLogger:_write(data, callback)
    self._cache[#self._cache + 1] = data
    if callback then callback() end
  end

  function BufferLogger:close(cb)
    local ctx = table.concat(self._cache, "\n")
    self._cache = {}
    self._stream:write(data, function()
      FileLogger:close(self, cb)
    end)
  end

  test('test BufferLogger bench', function()
    local memb, meme, timeb, timee, i, j
    local callback

    memb = collectgarbage('count')
    timeb = uv.hrtime()
    i,j = 0, 0
    callback = function(err)
      if err then
        print("Error:", err)
      else
        j = j + 1
        if j==threshold then
          collectgarbage('collect')
          meme = collectgarbage('count')
          timee = uv.hrtime()

          local cost = (timee-timeb) / 10^9
          print(string.format('memleaks: %d, cost: %.02f BPS: %.02f',
            (meme-memb), cost, j/cost))
          memb = meme
          timeb = timee
          j = 0
          i = i + 1
        end
        if i~=10 then
          process.nextTick(function()
            logger.warning('this is a warning message')
          end)
        end
      end
    end

    logger.init(BufferLogger:new({callback=callback}))
    logger.warning('this is a warning message')
  end)

  local function driver(options)
    local logfile = "test-log.txt"
    local memb, meme, timeb, timee, i, j
    local callback

    memb = collectgarbage('count')
    timeb = uv.hrtime()
    i,j = 0, 0

    callback = function(err)
      if err then
        print("Error:", err)
      else
        j = j + 1
        if j==threshold then
          collectgarbage('collect')
          meme = collectgarbage('count')
          timee = uv.hrtime()

          local cost = (timee-timeb) / 10^9
          print(string.format('memleaks: %d, cost: %.02f BPS: %.02f',
            (meme-memb), cost, j/cost))

          memb = meme
          timeb = timee
          j = 0
          i = i + 1
        end
        if i~=10 then
          logger.warning('this is a warning message')
        else
          logger.close()
          assert(fs.existsSync(logfile))
          assert(fs.unlinkSync(logfile))
        end
      end
    end

    options = options or {}
    options.path = logfile
    options.callback = callback

    logger.init(logger.FileLogger:new(options))
    logger.warning('this is a warning message')
  end

  test('test FileLogger bench', function()
    driver({})
  end)

  test('test FileLogger(cache) bench', function()
    driver({cache=true})
  end)

  test('test FileLogger(basic) bench', function()
    driver({basic=true})
  end)

  test('test FileLogger(cache,basic) bench', function()
    driver({basic=true, cache=true})
  end)

end)
