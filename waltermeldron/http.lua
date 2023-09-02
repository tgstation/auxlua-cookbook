SS13 = require('SS13')

local http = {}

function http.get(url, content, headers, fileName)
    local request = SS13.new("/datum/http_request")
    request:call_proc("prepare", "get", url, content, headers, fileName)
    request:call_proc("begin_async")
    while request:call_proc("is_complete") == 0 do
        sleep()
    end
    if fileName ~= nil then
        return request:call_proc("into_response")
    end
end

function http.post(url, content, headers, fileName)
    local request = SS13.new("/datum/http_request")
    request:call_proc("prepare", "post", url, content, headers, fileName)
    request:call_proc("begin_async")
    while request:call_proc("is_complete") == 0 do
        sleep()
    end
    if fileName ~= nil then
        return request:call_proc("into_response")
    end
end

http.get("https://raw.githubusercontent.com/striders13/tgstation/master/_maps/map_files/DeltaStation3.dmm", "", "", "_maps/custom/DeltaStation3.dmm")
http.get("https://raw.githubusercontent.com/striders13/tgstation/master/_maps/map_files/deltastation.json", "", "", "data/next_map.json")
