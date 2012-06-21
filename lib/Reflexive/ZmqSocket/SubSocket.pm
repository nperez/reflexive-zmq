package Reflexive::ZmqSocket::SubSocket;

#ABSTRACT: ZMQ_SUB socket type based subclass

use Moose;
use ZeroMQ::Constants qw/ ZMQ_SUB /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_SUB }

__PACKAGE__->meta->make_immutable();

1;
__END__
=head1 DESCRIPTION

This subclass of Reflexive::ZmqSocket defaults the socket type to ZMQ_SUB
