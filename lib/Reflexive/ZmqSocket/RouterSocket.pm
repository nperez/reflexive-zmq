package Reflexive::ZmqSocket::RouterSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_ROUTER /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_ROUTER }

__PACKAGE__->meta->make_immutable();

1;
