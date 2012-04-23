package Reflexive::ZmqSocket::PushSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_PUSH /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_PUSH }

__PACKAGE__->meta->make_immutable();

1;
