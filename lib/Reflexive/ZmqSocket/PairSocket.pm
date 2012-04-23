package Reflexive::ZmqSocket::PairSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_PAIR /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_PAIR }

__PACKAGE__->meta->make_immutable();

1;
