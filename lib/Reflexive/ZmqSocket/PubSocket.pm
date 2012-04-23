package Reflexive::ZmqSocket::PubSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_PUB /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_PUB }

__PACKAGE__->meta->make_immutable();

1;
