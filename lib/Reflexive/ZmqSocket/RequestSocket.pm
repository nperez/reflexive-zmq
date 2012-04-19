package Reflexive::ZmqSocket::RequestSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_REQ /;
use Reflexive::ZmqError;
use Try::Tiny;

extends 'Reflexive::ZmqSocket';

sub socket_type { +ZMQ_REQ }

sub BUILD {
    my ($self) = @_;

    foreach my $endpoint ($self->all_endpoints)
    {
        try
        {
            $self->connect($endpoint);
        }
        catch
        {
            $self->emit(
                -name => 'connect_error',
                -type => 'Reflexive::ZmqError',
                errnum => -1,
                errstr => "Failed to connect to endpoint: $endpoint",
                errfun => 'connect',
            );
        };
    }
}

__PACKAGE__->meta->make_immutable();

1;
