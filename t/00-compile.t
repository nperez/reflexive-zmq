use warnings;
use strict;
use Test::More;

use_ok('Reflexive::ZmqSocket');
use_ok('Reflexive::ZmqSocket::ZmqError');
use_ok('Reflexive::ZmqSocket::ZmqMessage');
use_ok('Reflexive::ZmqSocket::ReplySocket');
use_ok('Reflexive::ZmqSocket::RequestSocket');
use_ok('Reflexive::ZmqSocket::PullSocket');
use_ok('Reflexive::ZmqSocket::PushSocket');
use_ok('Reflexive::ZmqSocket::DealerSocket');
use_ok('Reflexive::ZmqSocket::RouterSocket');
use_ok('Reflexive::ZmqSocket::PairSocket');
use_ok('Reflexive::ZmqSocket::PubSocket');
use_ok('Reflexive::ZmqSocket::SubSocket');

done_testing();
