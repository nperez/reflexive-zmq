use warnings;
use strict;

use Test::More;

{
    package App::Test;
    use Moose;
    extends 'Reflex::Base';
    use Reflex::Trait::Watched qw/ watches /;
    use Reflexive::ZmqSocket::ReplySocket;
    use Reflexive::ZmqSocket::RequestSocket;

    watches request => (
        isa => 'Reflexive::ZmqSocket::RequestSocket',
        clearer => 'clear_request',
        predicate => 'has_request',
    );

    watches reply => (
        isa => 'Reflexive::ZmqSocket::ReplySocket',
        clearer => 'clear_reply',
        predicate => 'has_reply',
    );
    
    for(qw/ping pong/)
    {
        has "$_"  => (
            is => 'ro',
            isa => 'Bool',
            traits => ['Bool'],
            handles => { "toggle_$_" => 'toggle' },
        );
    }

    sub init {
        my ($self) = @_;

        my $rep = Reflexive::ZmqSocket::ReplySocket->new(
            endpoints => [ 'tcp://127.0.0.1:54321' ],
            endpoint_action => 'connect'
        );

        my $req = Reflexive::ZmqSocket::RequestSocket->new(
            endpoints => [ 'tcp://127.0.0.1:54321' ],
            endpoint_action => 'bind',
        );

        $self->request($req);
        $self->reply($rep);
    }

    sub clear {
        my ($self) = @_;
        $self->ignore($self->request) if $self->has_request;
        $self->ignore($self->reply) if $self->has_reply;
        $self->clear_request;
        $self->clear_reply;
    }

    sub BUILD {
        my ($self) = @_;
        
        $self->clear();
        $self->init();
    }

    sub on_reply_message {
        my ($self, $msg) = @_;
        $self->toggle_ping;
        $self->reply->send($msg->data + 1);
    }

    sub on_request_message {
        my ($self, $msg) = @_;
        $self->toggle_pong;
        $self->clear;
    }

    sub on_reply_socket_error {
        my ($self, $msg) = @_;
        BAIL('There should never be a socket error');
    }

    sub on_request_socket_error {
        my ($self, $msg) = @_;
        BAIL('There should never be a socket error');
    }

    sub on_reply_bind_error {
        my ($self, $msg) = @_;
        BAIL('There should never be a socket error');
    }

    sub on_request_connect_error {
        my ($self, $msg) = @_;
        BAIL('There should never be a socket error');
    }

    __PACKAGE__->meta->make_immutable();
}

my $app = App::Test->new();
$app->request->send(1);
$app->run_all();

ok($app->ping, 'Successfully set ping');
ok($app->pong, 'Successfully set pong');

done_testing();

