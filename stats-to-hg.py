import json
from urllib2 import urlopen, URLError
import socket
from time import sleep

UDP_ADDRESS = "carbon.hostedgraphite.com"
UDP_PORT = 2003
RIAK_STATS_URL='http://localhost:8098/stats'
RIAK_EE_STATS_URL='http://localhost:8098/riak-repl/stats' #Leave this blank if you're not using Riak EE

HG_API_KEY='b2a69431-10f0-4b38-b51c-220d26d6e587'

try:
  stats=json.load(urlopen(RIAK_STATS_URL))
except URLError:
  print 'Could not load the statistics from %s' % RIAK_STATS_URL 
  exit(1)

try:
  if RIAK_EE_STATS_URL:
    eestats=json.load(urlopen(RIAK_EE_STATS_URL))
except URLError:
  print 'Could not load the Riak Replication statistics from %s' % RIAK_EE_STATS_URL 

nn = stats['nodename'].replace('.', '-')
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP# Internet 

for k in stats:
  if type(1) == type(stats[k]):
    message='%s.%s.%s %s' % (HG_API_KEY,nn,k,stats[k])
    sock.sendto(message, (UDP_ADDRESS, UDP_PORT))
    #sleep(0.1)
    print message
print 'Sent %s' % len(stats)

print eestats

if RIAK_EE_STATS_URL:
  for k in eestats:
    if type(1) == type(eestats[k]):
      message='%s.%s.%s %s' % (HG_API_KEY,nn,k,eestats[k])
      sock.sendto(message, (UDP_ADDRESS, UDP_PORT))
      print message
  print 'Sent %s Riak EE stats' % len(stats)
