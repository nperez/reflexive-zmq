package Reflexive::ZmqSocket::PubSocket;

#ABSTRACT: ZMQ_PUB socket type based subclass

use Moose;
use ZeroMQ::Constants qw/ ZMQ_PUB /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_PUB }

__PACKAGE__->meta->make_immutable();

1;
__END__
=head1 DESCRIPTION

This subclass of Reflexive::ZmqSocket defaults the socket type to ZMQ_PUB
