var canned = require('canned')
,   http = require('http')
,   opts = { cors: true, logger: process.stdout }

can = canned('api', opts)

http.createServer(can).listen(process.env.PORT || 4567)
