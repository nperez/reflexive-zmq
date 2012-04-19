package Reflexive::ZmqSocket::ReplySocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_REP /;
use Reflexive::ZmqError;
use Try::Tiny;

extends 'Reflexive::ZmqSocket';

sub socket_type { +ZMQ_REP }

sub BUILD {
    my ($self) = @_;
    
    foreach my $endpoint ($self->all_endpoints)
    {
        try
        {
            $self->bind($endpoint);
        }
        catch
        {
            $self->emit(
                -name => 'bind_error',
                -type => 'Reflexive::ZmqError',
                errnum => -1,
                errstr => "Failed to bind to endpoint: $endpoint",
                errfun => 'bind',
            );
        };
    }
}

__PACKAGE__->meta->make_immutable();

1;
