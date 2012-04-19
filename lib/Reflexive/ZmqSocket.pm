package Reflexive::ZmqSocket;
use Moose;
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
/;
use Reflexive::ZmqSocket::ZmqError;
use Reflexive::ZmqSocket::ZmqMessage;

extends 'Reflex::Base';

sub socket_type { die 'This is a virtual method and should never be called' }

has endpoints => (
	is => 'ro',
	isa => 'ArrayRef[Str]',
    traits => ['Array'],
	required => 1,
    handles => {
        endpoints_count => 'count',
        all_endpoints => 'elements',
    }
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

sub _build_socket {
    my ($self) = @_;

    return ZeroMQ::Socket->new(
        $self->context(),
        $self->socket_type(),
    );
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
        
        my $ret = $self->socket->send($item);
        if($ret == 0)
        {
            if(my $msg = $self->recv(ZMQ_NOBLOCK)) {
                $self->emit(
                    -name => 'message',
                    -type => 'Reflexive::ZmqSocket::ZmqMessage',
                    message => $msg,
                );
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
}

sub zmq_readable {
	my ($self, $args) = @_;
	
    MESSAGE: while (1) {
        
        unless($self->getsockopt(ZMQ_EVENTS) & ZMQ_POLLIN)
        {
            return;
        }
        
	    if(my $msg = $self->recv(ZMQ_NOBLOCK)) {
			$self->emit(
				-name => 'message',
				-type => 'Reflexive::ZmqSocket::ZmqMessage',
				message => $msg,
			);
            return;
		}

		if($! == EAGAIN or $! == EINTR)
        {
            next MESSSAGE;
        }
        
		$self->pause_reading();

		$self->emit(
            -name => 'socket_error',
            -type => 'Reflexive::ZmqSocket::ZmqError',
            errnum => ($! + 0),
            errstr => "$!",
            errfun => 'recv',
		);

		return;
	}
}

__PACKAGE__->meta->make_immutable();

1;
