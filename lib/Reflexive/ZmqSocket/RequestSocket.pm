package Reflexive::ZmqSocket::RequestSocket;
use Moose;
use ZeroMQ::Constants qw/ ZMQ_REQ /;
use Reflexive::ZmqSocket::ZmqError;
use Try::Tiny;

extends 'Reflexive::ZmqSocket';

sub socket_type { +ZMQ_REQ }

sub BUILD {
    my ($self) = @_;

    foreach my $endpoint ($self->all_endpoints)
    {
        my $action = $self->endpoint_action;
        
        try
        {
            $self->$action($endpoint);
        }
        catch
        {
            $self->emit(
                -name => 'connect_error',
                -type => 'Reflexive::ZmqSocket::ZmqError',
                errnum => -1,
                errstr => "Failed to $action to endpoint: $endpoint",
                errfun => $action,
            );
        };
    }
}

__PACKAGE__->meta->make_immutable();

1;
