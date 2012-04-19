package Reflexive::ZmqSocket::ZmqError;
use Moose;

extends 'Reflex::Event';

has errnum => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has errstr => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has errfun => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable();

1;
