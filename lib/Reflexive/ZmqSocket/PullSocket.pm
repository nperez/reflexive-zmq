package Reflexive::ZmqSocket::PullSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_PULL /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_PULL }

__PACKAGE__->meta->make_immutable();

1;
