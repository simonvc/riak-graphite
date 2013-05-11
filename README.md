riak-graphite
=============

Simple Riak-Graphite integration

This project allows you to quickly setup your Riak to send UDP stats to a carbon/graphite server, or service like HostedGraphite.

Usage: ./install_riak_graphite.sh domain_home graphite_prefix graphite_server

* Domain_home should be where your Riak node lives. i.e. domain_home/etc/vm.args
* For hosted graphite, put your API key as the graphite_prefix, otherwise put what ever you like, for example what you call your riak cluster
* For hosted graphite the graphite server should be carbon.hostedgraphite.com

If the script completes successfully then you can start sending stats with the command bin/start-sending-graphite.sh

To stop sending stats to graphite, use the command bin/stop-sending-graphite.sh

To automate the sending of stats whenever the Riak node is running add the command:

-s  riak_graphite start ["mygraphiteprefix", "my.graphite.com"]

to your vm.args


