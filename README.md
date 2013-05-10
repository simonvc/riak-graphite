riak-graphite
=============

Simple Riak-Graphite integration

This project allows you to quickly setup your Riak to send UDP stats to a carbon/graphite server, or service like HostedGraphite.

Usage: ./install_riak_graphite.sh domain_home graphite_prefix graphite_server

Domain_home should be where your Riak node lives. i.e. domain_home/etc/vm.args
For hosted graphite, put your API key as the graphite_prefix, otherwise put what ever you like, for example what you call your riak cluster
For hosted graphite the graphite server should be carbon.hostedgraphite.com



