package Reflexive::ZmqSocket::DealerSocket;

#ABSTRACT: ZMQ_DEALER socket type based subclass

use Moose;
use ZeroMQ::Constants qw/ ZMQ_DEALER /;

extends 'Reflexive::ZmqSocket';

sub _build_socket_type { +ZMQ_DEALER }

__PACKAGE__->meta->make_immutable();

1;
__END__
=head1 DESCRIPTION

This subclass of Reflexive::ZmqSocket defaults the socket type to ZMQ_DEALER

