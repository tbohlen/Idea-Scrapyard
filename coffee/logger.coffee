# joshdulac.com logging function
fs = require("fs")
exports.log = (request, message) ->
    console.log(message)
    path = "log"
    now = new Date()
    dateAndTime = now.toUTCString()
    stream = fs.createWriteStream(path, {'flags': 'a+', 'encoding': 'utf8', 'mode': 0644})

    stream.write(dateAndTime + " ", 'utf8')
    if request
        stream.write(request.connection.remoteAddress + ": ", 'utf8')
        stream.write(request.method + " ", 'utf8')
        stream.write(request.url + "\n", 'utf8')
    else
        stream.write("<no address>" + ": ", 'utf8')
        stream.write("<no method>" + " ", 'utf8')
        stream.write("<no url>" + "\n", 'utf8')
    stream.end()