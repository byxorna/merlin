Agent is something that pushes state into etcd, and listens to other trees in etcd for changes and acts on them.
Contains target specific knowledge about state (i.e. haproxy should be degraded if /status takes > 400ms, or load > 100).
