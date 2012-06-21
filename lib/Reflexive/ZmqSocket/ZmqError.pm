package Reflexive::ZmqSocket::ZmqError;

#ABSTRACT: The event emitted when errors occur

use Moose;

extends 'Reflex::Event';

=attribute_public errnum

    is: ro, isa: Int

This is the number version of the error ($!+0)

=cut

has errnum => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

=attribute_public errstr

    is: ro, isa: Str

This is the string version of the error ("$!")

=cut

has errstr => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=attribute_public errfun

    is: ro, isa: Str

This is the function that is the source of the error

=cut

has errfun => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable();

1;
__END__

=head1 DESCRIPTION

Reflexive::ZmqSocket::ZmqError is an event emitted when bad things happen to sockets.

