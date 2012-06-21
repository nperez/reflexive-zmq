package Reflexive::ZmqSocket::PairSocket;

#ABSTRACT: ZMQ_PAIR socket type based subclass

use Moose;
use ZeroMQ::Constants qw/ ZMQ_PAIR /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_PAIR }

__PACKAGE__->meta->make_immutable();

1;
__END__
=head1 DESCRIPTION

This subclass of Reflexive::ZmqSocket defaults the socket type to ZMQ_PAIR
