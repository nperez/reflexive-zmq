package Reflexive::ZmqSocket::ReplySocket;

#ABSTRACT: ZMQ_REP socket type based subclass

use Moose;
use ZeroMQ::Constants qw/ ZMQ_REP /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_REP }

__PACKAGE__->meta->make_immutable();

1;
__END__
=head1 DESCRIPTION

This subclass of Reflexive::ZmqSocket defaults the socket type to ZMQ_REP
