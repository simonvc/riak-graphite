#!/bin/sh

function usage {
  echo Usage: ./install_riak_graphite.sh domain_home graphite_prefix graphite_server
  echo        Domain_home should be where your Riak node lives. i.e. domain_home/etc/vm.args
  echo        For hosted graphite, put your API key as the graphite_prefix, otherwise put what ever you like, for example what you call your riak cluster
  echo        For hosted graphite the graphite server should be carbon.hostedgraphite.com
  exit 1
}


DH=$1
GP=$2
GS=$3

if [ x = x$DH ];then
  usage
fi
if [ x = x$GP ];then
  usage
fi
if [ x = x$GS ];then
  usage
fi


# first find the erlc
erlc=`find $DH -name erlc | head -1`
if [ x = x$erlc ];then
  echo "Could not find erlc in $DH"
  exit 1
fi


# second compile the beam
$erlc riak_graphite.erl
if [ $? -ne 0 ]; then
  echo "erlc did not compile the riak_graphite.erl into a beam file"
  exit 1
fi

# move the beam into basho-patches
cp riak_graphite.beam $(find $DH -name basho-patches -type d)
if [ $? -ne 0 ]; then
  echo "Could not copy riak_graphite.beam into basho-patches"
  exit 1
fi


# erl_call -a 'riak_graphite start ["aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "carbon.hostedgraphite.com"]' -c riak -n dev1@127.0.0.1
# create the start and stop scripts in bin
if [ -f $DH/bin/start-sending-graphite.sh ];then
  echo $DH/bin/start-sending-graphite.sh already exists.
  exit 1
fi
echo erl_call -a \'riak_graphite start [\"xGP\", \"xGS\"]\' -c riak -n xNN > $DH/bin/start-sending-graphite.sh
if [ $? -ne 0 ]; then
  echo "Could not create the bin/start-sending-graphite.sh script"
  exit 1
fi
sed -i s/xGP/$GP/ $DH/bin/start-sending-graphite.sh
sed -i s/xGS/$GS/ $DH/bin/start-sending-graphite.sh
sed -i s/xNN/$(grep name $DH/etc/vm.args | awk '{print $2}')/ $DH/bin/start-sending-graphite.sh
chmod +x $DH/bin/start-sending-graphite.sh

if [ -f $DH/bin/stop-sending-graphite.sh ];then
  echo $DH/bin/stop-sending-graphite.sh already exists.
  exit 1
fi
echo erl_call -a \'riak_graphite stop -c riak -n xNN > $DH/bin/stop-sending-graphite.sh
if [ $? -ne 0 ]; then
  echo "Could not create the bin/stop-sending-graphite.sh script"
  exit 1
fi
chmod +x $DH/bin/stop-sending-graphite.sh


# ask if you want to auto start riak 
# put the -s flag into vm.args


