package Reflexive::ZmqSocket::RequestSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_REQ /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_REQ }

__PACKAGE__->meta->make_immutable();

1;
