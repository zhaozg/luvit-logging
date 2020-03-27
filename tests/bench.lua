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
  end

  function BufferLogger:_write(data, callback)
    callback()
  end

  test('test BufferLogger bench', function()
    local memb, meme, i, j
    local callback

    memb = collectgarbage('count')
    i,j = 0, 0
    callback = function(err)
      if err then
        print("Error:", err)
      else
        j = j + 1
        if j==10000 then
          collectgarbage('collect')
          meme = collectgarbage('count')
          print('memleaks',(meme-memb))
          memb = meme
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

  test('test FileLogger bench', function()
    local logfile = "test-log.txt"
    local memb, meme, i, j
    local callback

    memb = collectgarbage('count')
    i,j = 0, 0
    callback = function(err)
      if err then
        print("Error:", err)
      else
        j = j + 1
        if j==10000 then
          collectgarbage('collect')
          meme = collectgarbage('count')
          print('memleaks',(meme-memb))
          memb = meme
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

    logger.init(logger.FileLogger:new({path = logfile, callback=callback}))
    logger.warning('this is a warning message')
  end)

end)
