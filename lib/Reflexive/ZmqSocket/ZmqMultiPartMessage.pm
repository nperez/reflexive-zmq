package Reflexive::ZmqSocket::ZmqMultiPartMessage;
use Moose;
extends 'Reflex::Event';

has message => (
    is       => 'ro',
    isa      => 'ArrayRef[ZeroMQ::Message]',
    traits   => ['Array'],
    required => 1,
    handles  => {
        pop_part => 'pop',
        unshift_part => 'unshift',
        push_part => 'push',
        shift_part => 'shift',
        count_parts => 'count',
        all_parts => 'elements',
    },
);

__PACKAGE__->meta->make_immutable();

1;
