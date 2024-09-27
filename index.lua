-- libraries
local http  = require('coro-http')
local json  = require('json')
local timer = require('timer')
-- shortcuts
local read  = io.read
local write = io.write
local open  = io.open
local req   = http.request
local sleep = timer.sleep
-- containers
local base = 'https://discord.com/api/v10'

-- check for pre-existing config
local file = open('config.txt', 'r')
local config = {}
local token
local channel

-- check for file
if file then
    -- acknowledge file
    print('# config file already exists; using it')

    -- read file
    for l in file:lines() do
        -- pattern test line(s)
        local k, v = l:match("(%w+)%s*=%s*(%S+)")

        -- check for key and respective value
        if k and v then
            -- add to config memory
            config[k] = v
        end
    end

    -- close file
    file:close()

    -- assign values accordingly
    token = config['token']
    channel = config['channel']
else
    -- acknowledge lack of file
    print("# no config file found; making one")

    -- open file
    file = open('config.txt', 'w')
  
    local default = "token=\nchannel="

    -- update file with default config and close
    file:write(default)
    file:close()

    -- send them back
    return print("# config file established; please complete it")
end

-- validate config values
if not (token and channel) then
    return print('# config file exists, but is not completed')
end

-- get info from token
local tdata, tbody = req('GET', (base ..'/users/@me'),
{
    {'Content-Type', 'application/json'},
    {'User-Agent', 'MyWebhookClient'},
    {'Authorization', token}  
})

local my = json.decode(tbody)

-- validate token
if my.message then
    return print('... token invalid')
end

-- collect messages
local msgs = {}
local offset = 0

while true do
    -- request message logs
    local data, body = req(
        'GET', ('%s/channels/%s/messages/search?author_id=%s&include_nsfw=true&offset=%s')
               :format(base, channel, my.id, offset), 
        {
            {'Content-Type', 'application/json'},
            {'User-Agent', 'MyWebhookClient'},
            {'Authorization', token}
        }
    )

    -- decode result
    local mbody = json.decode(body)

    -- validate result
    if not mbody then
        break
    end

    local messages = mbody.messages

    -- validate message logs
    if not messages or #messages <= 0 then
        break
    end

    -- go through messages
    for i, v in pairs(messages) do
        -- collect
        msgs[#msgs + 1] = v[1].id
    end

    -- increase offset for next page
    offset = offset + 25

    -- ratelimit
    sleep(300)
end

-- relay necessary info
os.execute('cls')
print(([[
.--------------------------.
  msgs being deleted: %d  
  estimated time:     %ds 
*--------------------------*
]]):format(#msgs, (#msgs * 0.525)))

-- go through msgs
for i, v in pairs(msgs) do
    -- delete message
    local data, body = req(
        'DELETE', ('%s/channels/%s/messages/%s')
               :format(base, channel, v), 
        {
            {'Content-Type', 'application/json'},
            {'User-Agent', 'MyWebhookClient'},
            {'Authorization', token}
        }
    )

    -- validate deletion status
    if data.code == 204 then
        -- relay successful deletion
        print('deleted  #' .. i)
        -- ratelimit
        sleep(525)
    end
end
