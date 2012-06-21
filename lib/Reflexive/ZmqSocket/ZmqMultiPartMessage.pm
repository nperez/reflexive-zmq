package Reflexive::ZmqSocket::ZmqMultiPartMessage;

#ABSTRACT: The event emitted when a multipart message is received

use Moose;
extends 'Reflex::Event';

=attribute_public message

    is: ro, isa: ArrayRef[ZeroMQ::Message], traits: Array

message is the attribute that holds the array reference of all of the message
parts received from the socket.

The following methods are delgated to this attribute:

    pop_part
    unshift_part
    push_part
    shift_part
    count_parts
    all_parts

=cut

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
__END__
=head1 DESCRIPTION

Reflexive::ZmqSocket::ZmqMultiPartMessage is the event that contains all of the
messages received from the socket that were sent using SNDMORE.

A common idiom for gathering all of the data together is:

    my @data = map { $_->data } $msg->all_parts();


