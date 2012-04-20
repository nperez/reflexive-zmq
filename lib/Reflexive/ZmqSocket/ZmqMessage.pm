package Reflexive::ZmqSocket::ZmqMessage;
use Moose;
extends 'Reflex::Event';

has message => (
    is       => 'ro',
    isa      => 'ZeroMQ::Message',
    required => 1,
    handles => [qw/data/],
);

__PACKAGE__->meta->make_immutable();

1;
