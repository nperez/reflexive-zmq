package Reflexive::ZmqSocket::ReplySocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_REP /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_REP }

__PACKAGE__->meta->make_immutable();

1;
