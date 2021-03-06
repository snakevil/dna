local DnaServer, DnaAgents, DnaCache

local DNA = setmetatable({
        _VERSION = 'DNA 0.1.0-beta1'
    }, {
        --- DNA() - Configs and runs
        -- @param ... Runtime options
        -- @return self object
        __call = function (DNA, ...)
            local triggers, config = require('dna.triggers'), require('dna.config')({
                host = '127.0.0.1',
                port = 53,
                mode = 'tcp',
                timeout = 3,
                upstreams = {},
                log = {
                    path = 'stderr',
                    level = 'notice'
                },
                cache = 600
            }, ... )
            if 'help' == config then
                DNA.help(require('dna.listener')(triggers, require('dna.logger')('stderr', 'emergency')))
            elseif 'version' == config then
                DNA.version(require('dna.listener')(triggers, require('dna.logger')('stderr', 'emergency')))
            elseif 'table' ==type(config) then
                if 0 == #config.upstreams then
                    config.upstreams = {
                        {
                            host = '8.8.4.4',
                            port = 53
                        },
                        {
                            host = '8.8.8.8',
                            port = 53
                        }
                    }
                end
                DNA.serve(config, require('dna.listener')(triggers, require('dna.logger')(config.log.path, config.log.level)))
            end
        end
    })

--- DNA.help() - Prints help
function DNA.help(listener)
    listener:fire('dna.help', DNA)
end

--- DNA.version() - Prints version
function DNA.version(listener)
    listener:fire('dna.version', DNA)
end

--- DNA.serve() - Serves as a daemon
-- @param config Table of configs
-- @param listener Event listener
function DNA.serve(config, listener)
    listener:fire('dna.setup', {
        DNA = DNA,
        config = config
    })
    local tunnel, index = {}, 0
    if config.tunnel then
        for index = 1, #config.upstreams do
            tunnel[index] = config.upstreams[index].host
        end
    end
    local server = DNA.server(config, require('dna.route')(config.gateway, tunnel, listener))
    repeat
        DNA.agent(config, listener):appease(DNA.cache(config, listener):hit(server:request()))
    until nil
    listener:fire('dna.shutdown', server)
end

--- DNA.server() - Retrieves the only server
-- @param config Table of configs
-- @param listener Event listener
-- @return DnaServer object
function DNA.server(config, listener)
    if not DnaServer then
        DnaServer = require('dna.server')(config.host, config.port, listener)
    end
    return DnaServer
end

--- DNA.agent() - Picks a random agent
-- @param config Table of configs
-- @param listener Event listener
-- @return DNaAgent object
function DNA.agent(config, listener)
    local index, worker, counter
    if not DnaAgents then
        DnaAgents = {}
        for index = 1, #config.upstreams do
            DnaAgents[index] = require('dna.agent')(config.upstreams[index].host, config.upstreams[index].port, config.mode, config.timeout, listener)
        end
    end
    for index = 1, #DnaAgents do
        if not counter or DnaAgents[index].counter < counter then
            worker = DnaAgents[index]
            counter = worker.counter
        end
    end
    return worker
end

--- DNA.cache() - Retrieves the cache object
-- @param config Table of configs
-- @param listener Event listener
-- @return DnaCache object
function DNA.cache(config, listener)
    if not DnaCache then
        DnaCache = require('dna.cache')(config.cache, listener)
    end
    return DnaCache
end

return DNA
