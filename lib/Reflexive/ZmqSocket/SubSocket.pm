package Reflexive::ZmqSocket::SubSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_SUB /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_SUB }

__PACKAGE__->meta->make_immutable();

1;
