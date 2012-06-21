package Reflexive::ZmqSocket::RequestSocket;

#ABSTRACT: ZMQ_REQ socket type based subclass

use Moose;
use ZeroMQ::Constants qw/ ZMQ_REQ /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_REQ }

__PACKAGE__->meta->make_immutable();

1;
__END__
=head1 DESCRIPTION

This subclass of Reflexive::ZmqSocket defaults the socket type to ZMQ_REQ
