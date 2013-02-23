package Reflexive::ZmqSocket;

#ABSTRACT: Provides a reflexy way to talk over ZeroMQ sockets

use Moose;
use Moose::Util::TypeConstraints('enum');
use Try::Tiny;
use Errno qw(EAGAIN EINTR);
use ZeroMQ::Context;
use ZeroMQ::Socket;
use ZeroMQ::Constants qw/
    ZMQ_FD
    ZMQ_NOBLOCK
    ZMQ_POLLIN
    ZMQ_POLLOUT
    ZMQ_EVENTS
    ZMQ_SNDMORE
    ZMQ_RCVMORE
    ZMQ_PUSH
    ZMQ_PULL
    ZMQ_PUB
    ZMQ_SUB
    ZMQ_REQ
    ZMQ_REP
    ZMQ_DEALER
    ZMQ_ROUTER
    ZMQ_PAIR
/;
use Reflexive::ZmqSocket::ZmqError;
use Reflexive::ZmqSocket::ZmqMessage;
use Reflexive::ZmqSocket::ZmqMultiPartMessage;

extends 'Reflex::Base';

=attribute_public socket_type

    is: ro, isa: enum, lazy: 1

This attribute holds what type of ZeroMQ socket should be built. It must be one
of the constants exported by the ZeroMQ::Constants package. The attribute is
populated by default in the various subclasses.

=cut

has socket_type => (
    is => 'ro',
    isa => enum([ZMQ_REP, ZMQ_REQ, ZMQ_DEALER, ZMQ_ROUTER, ZMQ_PUB, ZMQ_SUB,
        ZMQ_PUSH, ZMQ_PULL, ZMQ_PAIR]),
    lazy => 1,
    builder => '_build_socket_type',
);

sub _build_socket_type { die 'This is a virtual method and should never be called' }

=attribute_public endpoints

    is: ro, isa: ArrayRef[Str], traits: Array, predicate: has_endpoints

This attribute holds an array reference of all of the endpoints to which the
socket should either bind or connect.

The following methods are delegated to this attribute:

    endpoints_count
    all_endpoints

=cut

has endpoints => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    predicate => 'has_endpoints',
    handles => {
        endpoints_count => 'count',
        all_endpoints => 'elements',
    }
);

=attribute_public endpoint_action

    is: ro, isa: enum(bind, connect), predicate: has_endpoint_action

This attribute determines the socket action to take against the provided
endpoints. While ZeroMQ allows sockets to both connect and bind, this module
limits it to either/or. Patches welcome :)

=cut

has endpoint_action => (
    is => 'ro',
    isa => enum([qw/bind connect/]),
    predicate => 'has_endpoint_action',
);

=attribute_public 

    is: ro, isa: HashRef

This attribute has the options for the socket. Options are applied at BUILD
time but before any action is taken on the end points. This allows for things
like setting the ZMQ_IDENTITY

=cut

has socket_options => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
);

=attribute_protected active

    is: ro, isa: Bool, default: true

This attribute controls whether the socket is observed or not for reads/writes according to Reflex

=cut

has active => ( is => 'rw', isa => 'Bool', default => 1 );

=attribute_public context

    is: ro, isa: ZeroMQ::Context

This attribute holds the context that is required for building sockets. 

=cut

has context => (
    is => 'ro',
    isa => 'ZeroMQ::Context',
    lazy => 1,
    builder => '_build_context',
);

sub _build_context {
    my ($self) = @_;
    return ZeroMQ::Context->new();
}

=attribute_public socket

    is: ro, isa: ZeroMQ::Socket

This attribute holds the actual ZeroMQ socket created. The following methods
are delegated to this attribute:

    recv
    getsockopt
    setsockopt
    close
    connect
    bind

=cut

has socket => (
    is => 'ro',
    isa => 'ZeroMQ::Socket',
    lazy => 1,
    builder => '_build_socket',
    handles => [qw/
        recv
        getsockopt
        setsockopt
        close
        connect
        bind
    /]
);

after [qw/bind connect/] => sub {
    my ($self) = @_;
    $self->resume_reading() unless $self->active;
};

after close => sub {
    my ($self) = @_;
    $self->stop_reading if $self->active;
};

sub _build_socket {
    my ($self) = @_;

    my $socket = ZeroMQ::Socket->new(
        $self->context(),
        $self->socket_type(),
    );
    
    my $opts = $self->socket_options;

    foreach my $key (keys %$opts)
    {
        $socket->setsockopt($key, $opts->{$key});
    }

    return $socket;
}

=attribute_protected 

    is: ro, isa: FileHandle

This attribute contains a file handle built from the cloned file descriptor
from inside the ZeroMQ::Socket. This is where the magic happens in how we poll
for non-blocking IO.

=cut

has filehandle => (
    is => 'ro',
    isa => 'FileHandle',
    lazy => 1,
    builder => '_build_filehandle',
);

sub _build_filehandle {
    my ($self) = @_;
    
    my $fd = $self->getsockopt(ZMQ_FD)
        or die 'Unable retrieve file descriptor';

    open(my $zmq_fh, "+<&" . $fd)
        or die "filehandle creation failed: $!";

    return $zmq_fh;
}

=attribute_protected buffer

    is: ro, isa: ArrayRef, traits: Array

Thie attribute is an internal buffer used for non-blocking writes.

The following methods are delegated to this attribute:

    buffer_count
    dequeue_item
    enqueue_item
    putback_item

=cut

has buffer => (
    is => 'ro',
    isa => 'ArrayRef',
    traits => ['Array'],
    default => sub { [] },
    handles => {
        buffer_count => 'count',
        dequeue_item => 'shift',
        enqueue_item => 'push',
        putback_item => 'unshift',
    }
);

with 'Reflex::Role::Readable' => {
    att_active    => 'active',
    att_handle    => 'filehandle',
    cb_ready      => 'zmq_readable',
    method_pause  => 'pause_reading',
    method_resume => 'resume_reading',
    method_stop   => 'stop_reading',
};

with 'Reflex::Role::Writable' => {
    att_active    => 'active',
    att_handle    => 'filehandle',
    cb_ready      => 'zmq_writable',
    method_pause  => 'pause_writing',
    method_resume => 'resume_writing',
    method_stop   => 'stop_writing',
};

sub BUILD {
    my ($self) = @_;

    if($self->active)
    {
        $self->initialize_endpoints();
    }
}

=protected_method initialize_endpoints

This method attempts the defined L</endpoint_action> against the provided
L</endpoints>. This method is called at BUILD if L</active> is true. To defer
initialization, simply set L</active> to false.

If the provided action against a particular endpoint fails, a connect_error
event will be emitted

=cut

sub initialize_endpoints {
    my ($self) = @_;
    
    die 'No endpoint_action defined when attempting to intialize endpoints'
        unless $self->has_endpoint_action;

    die 'No endpoints defind when attempting to initialize endpoints'
        unless $self->has_endpoints && $self->endpoints_count > 0;

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

=method_public send

This method is for sending messages through the L</socket>. It is non-blocking
and will return the current buffer count.

=cut

sub send {
    my ($self, $item) = @_;
    $self->enqueue_item($item);
    $self->resume_writing();
    return $self->buffer_count;
}


=method_private zmq_writable

This method is used internally to handle when the ZeroMQ socket is ready for
writing. This method can emit socket_error for various issues.

=cut

sub zmq_writable {
    my ($self, $args) = @_;

    MESSAGE: while ($self->buffer_count) {
        
        unless($self->getsockopt(ZMQ_EVENTS) & ZMQ_POLLOUT)
        {
            return;
        }
        
        my $item = $self->dequeue_item;

        if(ref($item) eq 'ARRAY')
        {
            my $socket = $self->socket;

            my $first_part = shift(@$item);
            my $ret = $self->socket->send($first_part, ZMQ_SNDMORE);
            if($ret == 0)
            {
                for(0..$#$item)
                {
                    my $part = $item->[$_];
                    if($_ == $#$item)
                    {
                        $socket->send($part);
                        my $rc = $self->do_read();

                        if($rc == -1)
                        {
                            $self->pause_reading();

                            $self->emit(
                                -name => 'socket_error',
                                -type => 'Reflexive::ZmqSocket::ZmqError',
                                errnum => ($! + 0),
                                errstr => "$!",
                                errfun => 'recv',
                            );
                            last MESSAGE;
                        }
                        elsif($rc == 0)
                        {
                            return;
                        }
                        elsif($rc == 1)
                        {
                            next MESSAGE;
                        }
                    }
                    else
                    {
                        $socket->send($part, ZMQ_SNDMORE);
                    }
                }
            }
            elsif($ret == -1)
            {
                if($! == EAGAIN)
                {
                    unshift(@$item, $first_part);
                    $self->putback_item($item);
                    next;
                }
                else
                {
                    last;
                }
            }
        }
        
        my $ret = $self->socket->send($item);
        if($ret == 0)
        {
            my $rc = $self->do_read();

            if($rc == -1)
            {
                $self->pause_reading();

                $self->emit(
                    -name => 'socket_error',
                    -type => 'Reflexive::ZmqSocket::ZmqError',
                    errnum => ($! + 0),
                    errstr => "$!",
                    errfun => 'recv',
                );
            }
            elsif($rc == 1)
            {
                next;
            }
        }
        elsif($ret == -1)
        {
            if($! == EAGAIN)
            {
                $self->putback_item($item);
            }
            else
            {
                last;
            }
        }
    }

    $self->pause_writing();
    
    if($! != EAGAIN)
    {
        $self->emit(
            -name => 'socket_error',
            -type => 'Reflexive::ZmqSocket::ZmqError',
            errnum => ($! + 0),
            errstr => "$!",
            errfun => 'send',
        );
    }
    else
    {
        $self->emit(-name => 'socket_flushed');
    }
}

=method_private zmq_readable

This method is used internally by reflex to actually read from the ZeroMQ socket when it is readable. This method can emit socket_error when problems occur. For successful reads, either message or multipart_message will be emitted.

=cut

sub zmq_readable {
    my ($self, $args) = @_;
    
    MESSAGE: while (1) {
        
        unless($self->getsockopt(ZMQ_EVENTS) & ZMQ_POLLIN)
        {
            return;
        }
        
        my $ret = $self->do_read();

        if($ret == -1)
        {
            $self->pause_reading();

            $self->emit(
                -name => 'socket_error',
                -type => 'Reflexive::ZmqSocket::ZmqError',
                errnum => ($! + 0),
                errstr => "$!",
                errfun => 'recv',
            );
        }
        elsif($ret == 0)
        {
            next MESSAGE;
        }
        elsif($ret == 1)
        {
            return;
        }
    }
}

=method_private do_read

This private method does the actual reading from the socket.

=cut

sub do_read {
    my ($self) = @_;

    if(my $msg = $self->recv(ZMQ_NOBLOCK)) {
        if($self->getsockopt(ZMQ_RCVMORE))
        {
            my $messages = [$msg];
            
            do
            {
                push(@$messages, $self->recv());
            }
            while ($self->getsockopt(ZMQ_RCVMORE));

            $self->emit(
                -name => 'multipart_message',
                -type => 'Reflexive::ZmqSocket::ZmqMultiPartMessage',
                message => $messages
            );
            return 1;
        }
        $self->emit(
            -name => 'message',
            -type => 'Reflexive::ZmqSocket::ZmqMessage',
            message => $msg,
        );
        return 1;
    }

    if($! == EAGAIN or $! == EINTR)
    {
        return 0;
    }

    return -1;
}

__PACKAGE__->meta->make_immutable();

1;
__END__

=head1 SYNOPSIS

    package App::Test;
    use Moose;
    extends 'Reflex::Base';
    use Reflex::Trait::Watched qw/ watches /;
    use Reflexive::ZmqSocket::RequestSocket;
    use ZeroMQ::Constants(':all');

    watches request => (
        isa => 'Reflexive::ZmqSocket::RequestSocket',
        clearer => 'clear_request',
        predicate => 'has_request',
    );

    sub init {
        my ($self) = @_;

        my $req = Reflexive::ZmqSocket::RequestSocket->new(
            endpoints => [ 'tcp://127.0.0.1:54321' ],
            endpoint_action => 'bind',
            socket_options => {
                +ZMQ_LINGER ,=> 1,
            },
        );

        $self->request($req);
    }

    sub BUILD {
        my ($self) = @_;
        
        $self->init();
    }

    sub on_request_message {
        my ($self, $msg) = @_;
    }

    sub on_request_multipart_message {
        my ($self, $msg) = @_;
        my @parts = map { $_->data } $msg->all_parts;
    }

    sub on_request_socket_flushed {
        my ($self) = @_;
    }
    
    sub on_request_socket_error {
        my ($self, $msg) = @_;
    }

    sub on_request_connect_error {
        my ($self, $msg) = @_;
    }

    sub on_request_bind_error {
        my ($self, $msg) = @_;
    }

    __PACKAGE__->meta->make_immutable();

=head1 DESCRIPTION

Reflexive::ZmqSocket provides a reflexy way to participate in ZeroMQ driven applications. A number of events are emitted from the instantiated objects of this class and its subclasses. On successful reads, either L</message> or L</multipart_message> is emitted. For errors, L</socket_error> is emitted. See L</EMITTED_EVENTS> for more informations.

=cut

=emitted_event message

message is emitted when a successful read occurs on the socket. When this event is emitted, the payload is a single message (in terms of ZeroMQ this is the result of the other end sending a message wuthout using SNDMORE). See L<Reflexive::ZmqSocket::ZmqMessage> for more information.

=cut

=emitted_event multipart_message

multipart_message is emitted when multipart message is read from the socket.  See L<Reflexive::ZmqSocket::ZmqMultiPartMessage> for more information.

=cut

=head1 ACKNOWLEDGEMENTS

This module was originally developed for Booking.com and through their gracious approval, we've released this module to CPAN.

