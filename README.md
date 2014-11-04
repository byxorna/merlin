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
      atomic: true
      statics:
        config/examples/static/test.txt: test.txt
      check_cmd: echo "This is the check command <%= files.join(' ') %>"
      commit_cmd: echo "This is the commit command <%= dest %>"
    named:
      watch: /merlin/named/company.net
      templates:
        "config/examples/named/templates/jfk01.company.net.erb": jfk01.company.net
        "config/examples/named/templates/atl01.company.net.erb": atl01.company.net
        "config/examples/named/templates/sfo01.company.net.erb": sfo01.company.net
      destination: /tmp/named
      statics:
        config/examples/named/static/company.net: company.net
        config/examples/named/static/jfk01.company.net-custom: jfk01.company.net-custom
        config/examples/named/static/sfo01.company.net-custom: sfo01.company.net-custom
      check_cmd: named-checkconf -t <%= dest %>
      commit_cmd: service named reload

* ```watch```: What keyspace in etcd to watch for changes. The whole tree at ```watch``` will be passed to your templates as ```data```.
* ```templates```: Key is the path to a template in ERuby; the value is the path relative to ```destination``` you want the templated file to go.
* ```destination```: What directory should all of the output be relative to. If omitted, assumes output is relative to pwd.
* ```statics```: Additional static files that should be watched on the filesystem to trigger a config generation if modified. ```statics``` is a hash of input -> output, where output is relative to ```destination```.
* ```check_cmd```: Command to run to verify the output of the emitter is correct (i.e. service httpd configtest). If this fails, merlin will roll back the configs. Allows erb expansion.
* ```commit_cmd```: Command to commit results once checked (i.e. cd ... && git commit -am ... && git push origin HEAD). Allows erb expansion.
* ```atomic```: Boolean. If true, destination will be an atomic symlink to the generated files. The destinations created will not be cleaned up. If omitted, files are just copied from the staging directory into destination.

Additionally, both check_cmd and commit_cmd can use ERB to template in a handful of useful variables. i.e.

    check_cmd: "/usr/bin/check_files -d <%= destination %>"
    commit_cmd: "git add <%= outputs.join " " %> && git commit -m '...' && git push"

* ```dest```: Directory where template outputs and static files are written for this stage. (Check -> a temp directory, commit -> the destination directory)
* ```files```: Array of fully qualified files output by this stage. Includes static and templated files.

## Templates

A sample template using embedded Ruby. The data that you are watching for at "watch" will be available in ```data```.

    # this is a template
    <% data.children.each do |el| %>
      <%= el.key %>: <%= el.value %>
    <% end %>


## Usage

### Oneshot

Used to just generate configs once, and then quit.

    $ bundle exec ./bin/merlin --oneshot -c config/examples/named.yaml -d -e 192.168.59.103:4001
    2014-11-01T17:21:33.885-0400 [named:etcd] DEBUG: Getting /merlin/named/company.net from 192.168.59.103:4001
    2014-11-01T17:21:33.896-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/jfk01.company.net.erb
    2014-11-01T17:21:33.896-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/atl01.company.net.erb
    2014-11-01T17:21:33.897-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/sfo01.company.net.erb
    2014-11-01T17:21:33.897-0400 [named:emitter] INFO: Reading static file config/examples/named/static/company.net
    2014-11-01T17:21:33.897-0400 [named:emitter] INFO: Reading static file config/examples/named/static/jfk01.company.net-custom
    2014-11-01T17:21:33.897-0400 [named:emitter] INFO: Reading static file config/examples/named/static/sfo01.company.net-custom
    2014-11-01T17:21:33.898-0400 [named:emitter] DEBUG: /tmp/named/jfk01.company.net SHA256: none, new contents: bff66a780bb74b5f870ee4cf5f1588da6f84628128c7614c34e9f1077878d1e7
    2014-11-01T17:21:33.898-0400 [named:emitter] INFO: /tmp/named/jfk01.company.net contents changed
    2014-11-01T17:21:33.898-0400 [named:emitter] DEBUG: Created tmp directory /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg
    2014-11-01T17:21:33.899-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/jfk01.company.net
    2014-11-01T17:21:33.899-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/atl01.company.net
    2014-11-01T17:21:33.899-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/sfo01.company.net
    2014-11-01T17:21:33.899-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/company.net
    2014-11-01T17:21:33.900-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/jfk01.company.net-custom
    2014-11-01T17:21:33.900-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/sfo01.company.net-custom
    2014-11-01T17:21:33.900-0400 [named:emitter] INFO: Running check command: echo "I would have run named-checkconf -t /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg"
    2014-11-01T17:21:33.902-0400 [named:emitter] DEBUG: Started pid 15380
    2014-11-01T17:21:33.903-0400 [named:emitter] INFO: I would have run named-checkconf -t /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg
    2014-11-01T17:21:33.904-0400 [named:emitter] DEBUG: Process exited: pid 15380 exit 0
    2014-11-01T17:21:33.904-0400 [named:emitter] INFO: Check succeeded
    2014-11-01T17:21:33.904-0400 [named:emitter] INFO: Moving outputs from /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg to /tmp/named
    2014-11-01T17:21:33.904-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/jfk01.company.net to /tmp/named/jfk01.company.net
    2014-11-01T17:21:33.904-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/atl01.company.net to /tmp/named/atl01.company.net
    2014-11-01T17:21:33.905-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/sfo01.company.net to /tmp/named/sfo01.company.net
    2014-11-01T17:21:33.905-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/company.net to /tmp/named/company.net
    2014-11-01T17:21:33.905-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/jfk01.company.net-custom to /tmp/named/jfk01.company.net-custom
    2014-11-01T17:21:33.905-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg/sfo01.company.net-custom to /tmp/named/sfo01.company.net-custom
    2014-11-01T17:21:33.905-0400 [named:emitter] INFO: Running commit command: echo "service named reload"
    2014-11-01T17:21:33.907-0400 [named:emitter] DEBUG: Started pid 15381
    2014-11-01T17:21:33.908-0400 [named:emitter] INFO: service named reload
    2014-11-01T17:21:33.909-0400 [named:emitter] DEBUG: Process exited: pid 15381 exit 0
    2014-11-01T17:21:33.909-0400 [named:emitter] INFO: Commit succeeded
    2014-11-01T17:21:33.909-0400 [named:emitter] DEBUG: Cleaning up /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15379-w5pdqg
    $ at /tmp/named/jfk01.company.net
    $ORIGIN jfk01.company.net.
    web2 IN A 10.2.1.2
    web3 IN A 10.2.1.3
    web4 IN A 10.2.1.4

### Watcher

Watch and react to changes in etcd and emit new configs. Both the ```watch``` path in your config, as well as any static files and templates will be watched for changes, and a new set of configs will be emitted whenever any of those change. You can also trigger a refresh by sending the process ```SIGHUP``` or ```SIGUSR1```.

    $ bundle exec ./bin/merlin -c config/examples/named.yaml -e 192.168.59.103:4001
    2014-11-01T17:31:10.853-0400 [named:cli] INFO: Creating emitter for named
    2014-11-01T17:31:11.006-0400 [named:cli] INFO: Running initial emitter with data etcd index 206 and modified index 179
    2014-11-01T17:31:11.007-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/jfk01.company.net.erb
    2014-11-01T17:31:11.007-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/atl01.company.net.erb
    2014-11-01T17:31:11.008-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/sfo01.company.net.erb
    2014-11-01T17:31:11.008-0400 [named:emitter] INFO: Reading static file config/examples/named/static/company.net
    2014-11-01T17:31:11.008-0400 [named:emitter] INFO: Reading static file config/examples/named/static/jfk01.company.net-custom
    2014-11-01T17:31:11.008-0400 [named:emitter] INFO: Reading static file config/examples/named/static/sfo01.company.net-custom
    2014-11-01T17:31:11.009-0400 [named:emitter] INFO: No change to /tmp/named/jfk01.company.net
    2014-11-01T17:31:11.009-0400 [named:emitter] INFO: No change to /tmp/named/atl01.company.net
    2014-11-01T17:31:11.010-0400 [named:emitter] INFO: No change to /tmp/named/sfo01.company.net
    2014-11-01T17:31:11.010-0400 [named:emitter] INFO: No change to /tmp/named/company.net
    2014-11-01T17:31:11.010-0400 [named:emitter] INFO: No change to /tmp/named/jfk01.company.net-custom
    2014-11-01T17:31:11.010-0400 [named:emitter] INFO: No change to /tmp/named/sfo01.company.net-custom
    2014-11-01T17:31:11.010-0400 [named:emitter] INFO: No changes detected; skipping check and commit
    2014-11-01T17:31:11.016-0400 [named:etcd] INFO: Watch fired for /merlin/named/company.net: set /merlin/named/company.net/sfo01/gabetesting with etcd index 206 and modified index 206
    2014-11-01T17:31:11.025-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/jfk01.company.net.erb
    2014-11-01T17:31:11.025-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/atl01.company.net.erb
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/sfo01.company.net.erb
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: Reading static file config/examples/named/static/company.net
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: Reading static file config/examples/named/static/jfk01.company.net-custom
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: Reading static file config/examples/named/static/sfo01.company.net-custom
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: No change to /tmp/named/jfk01.company.net
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: No change to /tmp/named/atl01.company.net
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: No change to /tmp/named/sfo01.company.net
    2014-11-01T17:31:11.026-0400 [named:emitter] INFO: No change to /tmp/named/company.net
    2014-11-01T17:31:11.027-0400 [named:emitter] INFO: No change to /tmp/named/jfk01.company.net-custom
    2014-11-01T17:31:11.027-0400 [named:emitter] INFO: No change to /tmp/named/sfo01.company.net-custom
    2014-11-01T17:31:11.027-0400 [named:emitter] INFO: No changes detected; skipping check and commit
    2014-11-01T17:31:47.163-0400 [named:etcd] INFO: Watch fired for /merlin/named/company.net: set /merlin/named/company.net/jfk01/admin01 with etcd index 206 and modified index 207
    2014-11-01T17:31:47.177-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/jfk01.company.net.erb
    2014-11-01T17:31:47.178-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/atl01.company.net.erb
    2014-11-01T17:31:47.179-0400 [named:emitter] INFO: Expanding template config/examples/named/templates/sfo01.company.net.erb
    2014-11-01T17:31:47.179-0400 [named:emitter] INFO: Reading static file config/examples/named/static/company.net
    2014-11-01T17:31:47.179-0400 [named:emitter] INFO: Reading static file config/examples/named/static/jfk01.company.net-custom
    2014-11-01T17:31:47.179-0400 [named:emitter] INFO: Reading static file config/examples/named/static/sfo01.company.net-custom
    2014-11-01T17:31:47.180-0400 [named:emitter] INFO: /tmp/named/jfk01.company.net contents changed
    2014-11-01T17:31:47.180-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/jfk01.company.net
    2014-11-01T17:31:47.181-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/atl01.company.net
    2014-11-01T17:31:47.181-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/sfo01.company.net
    2014-11-01T17:31:47.183-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/company.net
    2014-11-01T17:31:47.183-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/jfk01.company.net-custom
    2014-11-01T17:31:47.183-0400 [named:emitter] INFO: Writing /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/sfo01.company.net-custom
    2014-11-01T17:31:47.184-0400 [named:emitter] INFO: Running check command: echo "I would have run named-checkconf -t /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i"
    2014-11-01T17:31:47.190-0400 [named:emitter] INFO: I would have run named-checkconf -t /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i
    2014-11-01T17:31:47.191-0400 [named:emitter] INFO: Check succeeded
    2014-11-01T17:31:47.191-0400 [named:emitter] INFO: Moving outputs from /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i to /tmp/named
    2014-11-01T17:31:47.191-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/jfk01.company.net to /tmp/named/jfk01.company.net
    2014-11-01T17:31:47.192-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/atl01.company.net to /tmp/named/atl01.company.net
    2014-11-01T17:31:47.193-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/sfo01.company.net to /tmp/named/sfo01.company.net
    2014-11-01T17:31:47.193-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/company.net to /tmp/named/company.net
    2014-11-01T17:31:47.194-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/jfk01.company.net-custom to /tmp/named/jfk01.company.net-custom
    2014-11-01T17:31:47.194-0400 [named:emitter] INFO: Moving /var/folders/x5/ctzm07zs1tl233zx19xzdyzr0000gq/T/.merlin-named-20141101-15907-u3ic2i/sfo01.company.net-custom to /tmp/named/sfo01.company.net-custom
    2014-11-01T17:31:47.195-0400 [named:emitter] INFO: Running commit command: echo "service named reload"
    2014-11-01T17:31:47.199-0400 [named:emitter] INFO: service named reload
    2014-11-01T17:31:47.199-0400 [named:emitter] INFO: Commit succeeded




## Static files

You can observe static files that change on the filesystem, as well as changes to etcd. This enables static files that are managed by another system (i.e. human configs from a config management system) to trigger merlin to generate configs and take action. It uses https://github.com/guard/listen under the hood, so if your filesystem doesnt suck, it will use something like inotify instead of polling.

## Hacking

Use bundler to install the dependencies: ```bundle install```, then hack away and test with ```bundle exec bin/merlin```!

## Testing

```bundle exec rake rspec```

## TODO

* Pick a new name! Merlin is already a rubygem (http://rubygems.org/gems/merlin)
* test and document coalescing updates
* when performing atomic deploys, we dont clean up the old directories. We should
* Add helpers to ERubis to get key name instead of full value, find path, etc.
* Finish test suite! write tests for the CLI.


