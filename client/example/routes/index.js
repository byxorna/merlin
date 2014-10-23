var backends = require('../lib/backends');
exports.index = function(req,res){
  res.render('index', { backends: backends.load() });
}
