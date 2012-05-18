package Reflexive::ZmqSocket;
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

has socket_type => (
    is => 'ro',
    isa => enum([ZMQ_REP, ZMQ_REQ, ZMQ_DEALER, ZMQ_ROUTER, ZMQ_PUB, ZMQ_SUB, ZMQ_PUSH, ZMQ_PULL, ZMQ_PAIR]),
    lazy => 1,
    builder => '_build_socket_type',
);

sub _build_socket_type { die 'This is a virtual method and should never be called' }

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

has endpoint_action => (
    is => 'ro',
    isa => enum([qw/bind connect/]),
    predicate => 'has_endpoint_action',
);

has socket_options => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
);

has active => ( is => 'rw', isa => 'Bool', default => 1 );

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

sub send {
    my ($self, $item) = @_;
    $self->enqueue_item($item);
    $self->resume_writing();
    return $self->buffer_count;
}

sub zmq_writable {
    my ($self, $args) = @_;

    while ($self->buffer_count) {
        
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
                            last;
                        }
                        elsif($rc == 0)
                        {
                            return;
                        }
                        elsif($rc == 1)
                        {
                            next;
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
