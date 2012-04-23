package Reflexive::ZmqSocket::DealerSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_DEALER /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_DEALER }

__PACKAGE__->meta->make_immutable();

1;
