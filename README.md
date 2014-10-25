# Merlin

Inspired by https://github.com/kelseyhightower/confd, this tool allows you to generate configuration files from data in etcd.

## Usage

### Oneshot

Used to just generate configs once, and then quit.

```$ merlin -c config/example/config.yaml --debug --oneshot
D, [2014-10-24T23:10:46.280916 #88800] DEBUG -- : Getting /merlin/testing
I, [2014-10-24T23:10:46.290773 #88800]  INFO -- : Templating config/examples/templates/testing.conf.erb
D, [2014-10-24T23:10:46.291585 #88800] DEBUG -- : /tmp/testing/testing.conf SHA256: none, new contents: a52e73aa22f7840c4abaa92349552d1a264b45be245cd522fad9a4a330d98c01
I, [2014-10-24T23:10:46.291628 #88800]  INFO -- : Writing /tmp/testing/testing.conf
I, [2014-10-24T23:10:46.291862 #88800]  INFO -- : No check command specified, skipping check
I, [2014-10-24T23:10:46.291898 #88800]  INFO -- : No commit command specified, skipping check
$cat /tmp/testing/testing.conf
This is a template
  /merlin/testing/key1: hello
  /merlin/testing/newkey: world
This is the end of the template
```

### Watcher

```$ merlin -c config/example/config.yaml -d
D, [2014-10-24T23:12:17.415651 #89409] DEBUG -- : Watching /merlin/testing with index nil
I, [2014-10-24T23:12:49.974194 #89409]  INFO -- : Watch fired for /merlin/testing: set /merlin/testing/whooo with modified index 151
D, [2014-10-24T23:12:49.974258 #89409] DEBUG -- : Getting /merlin/testing
I, [2014-10-24T23:12:49.978052 #89409]  INFO -- : Templating config/examples/templates/testing.conf.erb
D, [2014-10-24T23:12:49.986011 #89409] DEBUG -- : /tmp/testing/testing.conf SHA256: a52e73aa22f7840c4abaa92349552d1a264b45be245cd522fad9a4a330d98c01, new contents: e790c96c5ab002129426d26b7a475334a9f1e8df34f67d01a56292878af98bde
D, [2014-10-24T23:12:49.986099 #89409] DEBUG -- : Moving /tmp/testing/testing.conf to /tmp/testing/testing.conf.bak
I, [2014-10-24T23:12:49.986417 #89409]  INFO -- : Writing /tmp/testing/testing.conf
I, [2014-10-24T23:12:49.986857 #89409]  INFO -- : No check command specified, skipping check
I, [2014-10-24T23:12:49.986896 #89409]  INFO -- : No commit command specified, skipping check
I, [2014-10-24T23:13:24.354541 #89409]  INFO -- : Watch fired for /merlin/testing: set /merlin/testing/anotherone with modified index 152
D, [2014-10-24T23:13:24.354607 #89409] DEBUG -- : Getting /merlin/testing
I, [2014-10-24T23:13:24.364658 #89409]  INFO -- : Templating config/examples/templates/testing.conf.erb
D, [2014-10-24T23:13:24.365068 #89409] DEBUG -- : /tmp/testing/testing.conf SHA256: e790c96c5ab002129426d26b7a475334a9f1e8df34f67d01a56292878af98bde, new contents: c4edcb107fcf8275f8e7252c449e49e30afee81ce01425e46e52370c7fe225b5
D, [2014-10-24T23:13:24.365119 #89409] DEBUG -- : Moving /tmp/testing/testing.conf to /tmp/testing/testing.conf.bak
I, [2014-10-24T23:13:24.365353 #89409]  INFO -- : Writing /tmp/testing/testing.conf
I, [2014-10-24T23:13:24.365582 #89409]  INFO -- : No check command specified, skipping check
I, [2014-10-24T23:13:24.365617 #89409]  INFO -- : No commit command specified, skipping check
^C
$ cat /tmp/testing/testing.conf
This is a template
  /merlin/testing/anotherone: aww yea
  /merlin/testing/newkey: 3
  /merlin/testing/whooo: 123
This is the end of the template
```