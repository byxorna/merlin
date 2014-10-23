var fs = require('fs');
var yaml = require('js-yaml');

exports.load = function(){
  return yaml.load(fs.readFileSync('/tmp/example.json'));
}
