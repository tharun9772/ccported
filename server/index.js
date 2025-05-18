var Transform = require('stream').Transform;
var express = require('express')
var Unblocker = require('unblocker');
var app = express();
var fs = require('fs');
var path = require('path');
const morgan = require("morgan");
console.log("STARTING");

// load the client script in memory
var clientScript = fs.readFileSync(path.join(__dirname, '../', 'static/big_game_script.js'), 'utf8');
var config = {
    prefix: "/p/",
    responseMiddleware: [
        injectScript
    ]
}
var unblocker = new Unblocker(config);

function injectScript(data) {
    return;
    console.log("INJECTING SCRIPT" + data.url);
    if (data.stream) {
        var injected = false;
        var injectTransform = new Transform({
            decodeStrings: false,
            transform: function (chunk, encoding, next) {
                if (!injected && chunk.toString().toLowerCase().includes('<head>')) {
                    var script = '<script>'+clientScript+'</script>';
                    chunk = chunk.toString().replace(/<head>/i, '<head>' + script);
                    injected = true;
                }
                this.push(chunk);
                next();
            }
        });
        data.stream = data.stream.pipe(injectTransform);
    } else if (data.body) {
        var script = '<script>'+clientScript+'</script>';
        data.body = data.body.toString().replace(/<head>/i, '<head>' + script);
    }
}


// this must be one of the first app.use() calls and must not be on a subdirectory to work properly
app.use(unblocker);

app.use(morgan("dev"))
// the upgrade handler allows unblocker to proxy websockets
app.listen(process.env.PORT || 3000,()=>{
    console.log("SERVER STARTED ON PORT 3000 (F->80)")
}).on('upgrade', unblocker.onUpgrade);
