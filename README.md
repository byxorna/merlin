# Merlin

Inspired by https://github.com/kelseyhightower/confd, this tool allows you to generate configuration files from data in etcd.

[![Build Status](https://travis-ci.org/byxorna/merlin.png?branch=master)](https://travis-ci.org/byxorna/merlin) 

## Configuration

A sample config looks like this:

    ---
    testing:
      watch: /merlin/testing
      templates:
        "config/examples/templates/testing.conf.erb": testing.conf
      destination: /tmp/testing/
      static_files:
        - config/examples/static/test.txt
      check_cmd: echo "Check command"
      commit_cmd: echo "Commit command"
    haproxy:
      watch: /merlin/haproxy
      templates:
        "config/haproxy/haproxy.conf.erb": haproxy.cfg
      destination: /etc/haproxy
      check_cmd: haproxy -f /etc/haproxy/haproxy.cfg -c
      commit_cmd: service haproxy reload

* ```watch```: What keyspace in etcd to watch for changes. The whole tree at ```watch``` will be passed to your templates as ```data```.
* ```templates```: Key is the path to a template in ERuby; the value is the path relative to ```destination``` you want the templated file to go.
* ```destination```: What directory should all of the output be relative to. If omitted, assumes output is relative to pwd.
* ```static_files```: Additional static files that should be watched on the filesystem to trigger a config generation if modified.
* ```check_cmd```: Command to run to verify the output of the emitter is correct (i.e. service httpd configtest). If this fails, merlin will roll back the configs.
* ```commit_cmd```: Command to commit results once checked (i.e. cd ... && git commit -am ... && git push origin HEAD)

Additionally, both check_cmd and commit_cmd can use ERB to template in a handful of useful variables. i.e.

    check_cmd: "/usr/bin/check_files -d <%= destination %>"
    commit_cmd: "git add <%= outputs.join " " %> && git commit -m '...' && git push"

* ```destination```: Directory where template outputs and static files are written for this stage.
* ```outputs```: Array of fully qualified files output by this stage. Includes static and templated files.
* ```static_outputs```: Array of fully qualified static files.
* ```dynamic_outputs```: Array of fully qualified template output files.

## Templates

A sample template using embedded Ruby. The data that you are watching for at "watch" will be available in ```data```.

    # this is a template
    <% data.children.each do |el| %>
      <%= el.key %>: <%= el.value %>
    <% end %>


## Usage

### Oneshot

Used to just generate configs once, and then quit.

    $ merlin -c config/example/config.yaml --debug --oneshot
    D, [2014-10-24T23:10:46.280916 #88800] DEBUG -- : Getting /merlin/testing
    I, [2014-10-24T23:10:46.290773 #88800]  INFO -- : Templating config/examples/templates/testing.conf.erb
    D, [2014-10-24T23:10:46.291585 #88800] DEBUG -- : /tmp/testing/testing.conf SHA256: none, new contents: a52e73aa22f7840c4abaa92349552d1a264b45be245cd522fad9a4a330d98c01
    I, [2014-10-24T23:10:46.291628 #88800]  INFO -- : Writing /tmp/testing/testing.conf
    I, [2014-10-24T23:10:46.291862 #88800]  INFO -- : No check command specified, skipping check
    I, [2014-10-24T23:10:46.291898 #88800]  INFO -- : No commit command specified, skipping check
    $ cat /tmp/testing/testing.conf
    This is a template
      /merlin/testing/key1: hello
      /merlin/testing/newkey: world
    This is the end of the template

### Watcher

Watch and react to changes in etcd and emit new configs. Both the ```watch``` path in your config, as well as any static files and templates will be watched for changes, and a new set of configs will be emitted whenever any of those change. You can also trigger a refresh by sending the process ```SIGHUP``` or ```SIGUSR1```.

    $ merlin -c config/example/config.yaml
    I, [2014-10-27T08:29:10.309085 #56169]  INFO -- : Starting up emitter for testing
    D, [2014-10-27T08:29:10.309208 #56169] DEBUG -- : Getting /merlin/testing
    D, [2014-10-27T08:29:10.330709 #56169] DEBUG -- : Started etcd watch thread at /merlin/testing with index 170
    D, [2014-10-27T08:29:10.330778 #56169] DEBUG -- : Awaiting index 170 at /merlin/testing
    D, [2014-10-27T08:29:10.330642 #56169] DEBUG -- : Watching for changes to config/examples/static/test.txt
    D, [2014-10-27T08:29:10.331188 #56169] DEBUG -- : Starting listener
    I, [2014-10-27T08:29:10.337268 #56169]  INFO -- : Watch fired for /merlin/testing: delete /merlin/testing/new with etcd index 170 and modified index 170
    D, [2014-10-27T08:29:10.337374 #56169] DEBUG -- : Getting /merlin/testing
    I, [2014-10-27T08:29:10.351636 #56169]  INFO -- : Templating config/examples/templates/testing.conf.erb
    D, [2014-10-27T08:29:10.353350 #56169] DEBUG -- : Watching for changes to config/examples/templates/testing.conf.erb
    D, [2014-10-27T08:29:10.353486 #56169] DEBUG -- : /tmp/testing/testing.conf SHA256: a6f0141ba90bc9d4cba7e648b812312de754f90766ce7ea165debb57a55dd44e, new contents: a6f0141ba90bc9d4cba7e648b812312de754f90766ce7ea165debb57a55dd44e
    I, [2014-10-27T08:29:10.353941 #56169]  INFO -- : No change to /tmp/testing/testing.conf
    D, [2014-10-27T08:29:10.353994 #56169] DEBUG -- : Awaiting index 171 at /merlin/testing
    D, [2014-10-27T08:29:10.353874 #56169] DEBUG -- : Starting listener
    I, [2014-10-27T08:29:40.763007 #56169]  INFO -- : Watch fired for /merlin/testing: set /merlin/testing/new_key with etcd index 170 and modified index 171
    D, [2014-10-27T08:29:40.763115 #56169] DEBUG -- : Getting /merlin/testing
    I, [2014-10-27T08:29:40.770235 #56169]  INFO -- : Templating config/examples/templates/testing.conf.erb
    D, [2014-10-27T08:29:40.770806 #56169] DEBUG -- : /tmp/testing/testing.conf SHA256: a6f0141ba90bc9d4cba7e648b812312de754f90766ce7ea165debb57a55dd44e, new contents: 02de2483631fa790c2b8cac77442790f868c93add860a2aba508ed99ff757b42
    D, [2014-10-27T08:29:40.770857 #56169] DEBUG -- : Copying /tmp/testing/testing.conf to /tmp/testing/testing.conf.bak
    I, [2014-10-27T08:29:40.771117 #56169]  INFO -- : Writing /tmp/testing/testing.conf
    I, [2014-10-27T08:29:40.771253 #56169]  INFO -- : Running check command: echo "Checking..."
    D, [2014-10-27T08:29:40.772959 #56169] DEBUG -- : Started pid 56422
    D, [2014-10-27T08:29:40.774881 #56169] DEBUG -- : Checking...
    D, [2014-10-27T08:29:40.775252 #56169] DEBUG -- : Process exited: pid 56422 exit 0
    I, [2014-10-27T08:29:40.775331 #56169]  INFO -- : Check succeeded
    I, [2014-10-27T08:29:40.775392 #56169]  INFO -- : Running commit command: echo "This is the commit command"
    D, [2014-10-27T08:29:40.776808 #56169] DEBUG -- : Started pid 56424
    D, [2014-10-27T08:29:40.779286 #56169] DEBUG -- : This is the commit command
    D, [2014-10-27T08:29:40.779640 #56169] DEBUG -- : Process exited: pid 56424 exit 0
    I, [2014-10-27T08:29:40.779743 #56169]  INFO -- : Commit succeeded
    D, [2014-10-27T08:29:40.779797 #56169] DEBUG -- : Awaiting index 172 at /merlin/testing
    W, [2014-10-27T08:30:14.548725 #56169]  WARN -- : Received reload request
    D, [2014-10-27T08:30:14.548872 #56169] DEBUG -- : Getting /merlin/testing
    I, [2014-10-27T08:30:14.562458 #56169]  INFO -- : Templating config/examples/templates/testing.conf.erb
    D, [2014-10-27T08:30:14.562974 #56169] DEBUG -- : /tmp/testing/testing.conf SHA256: 02de2483631fa790c2b8cac77442790f868c93add860a2aba508ed99ff757b42, new contents: 02de2483631fa790c2b8cac77442790f868c93add860a2aba508ed99ff757b42
    I, [2014-10-27T08:30:14.563004 #56169]  INFO -- : No change to /tmp/testing/testing.conf
    ^CD, [2014-10-27T08:30:35.857303 #56169] DEBUG -- : Terminating watchers for testing
    $ cat /tmp/testing/testing.conf
    This is a template
      /merlin/testing/anotherone: aww yea
      /merlin/testing/newkey: 3
      /merlin/testing/whooo: 123
    This is the end of the template

## Static files

You can observe static files that change on the filesystem, as well as changes to etcd. This enables static files that are managed by another system (i.e. human configs from a config management system) to trigger merlin to generate configs and take action. It uses https://github.com/guard/listen under the hood, so if your filesystem doesnt suck, it will use something like inotify instead of polling.

## Hacking

Use bundler to install the dependencies: ```bundle install```, then hack away and test with ```bundle exec bin/merlin```!

## Testing

```bundle exec rake rspec```

## TODO

* Pick a new name! Merlin is already a rubygem (http://rubygems.org/gems/merlin)
* make sure filewatcher is converting to absolute path
* static_files should have a destination as well, and be copied into ```destination``` when changed. Also should trigger commit check
* Is Etcd::Client thread safe? (bin/merlin)
* Finish test suite! write tests for the CLI.
* Thread watching multiple template groups (needs to support logging to separate files?) (bin/merlin)
* Config validation (bin/merlin)
* Support coalescing watches within an interval, so we dont fire a regeneration every change (watch/etcd)


