package Reflexive::ZmqSocket::ZmqMessage;

#ABSTRACT: The event emitted when a single message is received

use Moose;
extends 'Reflex::Event';

=attribute_public message

    is: ro, isa: ZeroMQ::Message

This attribute holds the actual message received from the socket. The following
methods are delegated to this attribute:

    data

=cut

has message => (
    is       => 'ro',
    isa      => 'ZeroMQ::Message',
    required => 1,
    handles => [qw/data/],
);

__PACKAGE__->meta->make_immutable();

1;
