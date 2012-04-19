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
use Reflexive::ZmqError;
use Reflexive::ZmqMessage;

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
    /,
#   'send',
    ]
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
    warn 'enqued item ' . $self->meta->name;
    return $self->buffer_count;
}

sub zmq_writable {
	my ($self, $args) = @_;

	MESSAGE: while (1) {
        
        if($self->buffer_count == 0)
        {
            warn 'no buffer, pausing writing ' . $self->meta->name;
            $self->pause_writing();
            return;
        }
		
        unless($self->getsockopt(ZMQ_EVENTS) & ZMQ_POLLOUT)
        {
            warn 'Not ready for WRITE? ' . $self->meta->name;
            return;
        }
        
        my $item = $self->dequeue_item;
        warn 'item dequeued ' . $self->meta->name;
        
        warn 'sending message ' . $self->meta->name;
        $! = 0;
        my $ret = $self->socket->send($item);
        if($ret == 0)
        {
            warn 'successfully sent message ' . $self->meta->name;
            next MESSAGE;
        }
        elsif($ret == -1)
        {
            if($! == EAGAIN)
            {
                warn 'failed to send. message putback ' . $self->meta->name;
                $self->putback_item($item);
                next MESSAGE;
            }
        }

        $self->pause_writing();

        $self->emit(
            -name => 'socket_error',
            -type => 'Reflexive::ZmqError',
            errnum => ($! + 0),
            errstr => "$!",
            errfun => 'send',
        );

		return;
	}
}

sub zmq_readable {
	my ($self, $args) = @_;

	MESSAGE: while (1) {
        
        unless($self->getsockopt(ZMQ_EVENTS) & ZMQ_POLLIN)
        {
            warn 'Not ready for READ? ' . $self->meta->name;
            return;
        }
        
        warn 'attempting to read message ' . $self->meta->name;
	    if(my $msg = $self->recv(ZMQ_NOBLOCK)) {
        warn 'got message ' . $self->meta->name;
			$self->emit(
				-name => 'message',
				-type => 'Reflexive::ZmqMessage',
				message => $msg,
			);
            warn 'trying to read more ' . $self->meta->name;
			next MESSAGE;
		}

		if($! == EAGAIN or $! == EINTR)
        {
            warn 'got either EAGAIN or EINTR';
            return ;
        }
        
        warn 'pausing reading due to error' . $self->meta->name;
		$self->pause_reading();

		$self->emit(
            -name => 'socket_error',
            -type => 'Reflexive::ZmqError',
            errnum => ($! + 0),
            errstr => "$!",
            errfun => 'recv',
		);

		return;
	}
}

__PACKAGE__->meta->make_immutable();

1;
