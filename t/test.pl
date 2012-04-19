use warnings;
use strict;

{
    package App::Test;
    use Moose;
    extends 'Reflex::Base';
    use Reflex::Trait::Watched qw/ watches /;
    use Reflexive::ZmqSocket::ReplySocket;
    use Reflexive::ZmqSocket::RequestSocket;

    watches request => (
        isa => 'Reflexive::ZmqSocket::RequestSocket'
    );

    watches reply => (
        isa => 'Reflexive::ZmqSocket::ReplySocket'
    );

    sub BUILD {
        my ($self) = @_;
        warn 'building reply socket';
        my $rep = Reflexive::ZmqSocket::ReplySocket->new(endpoints => [ 'tcp://127.0.0.1:54321' ]);
        warn 'building request socket';
        my $req = Reflexive::ZmqSocket::RequestSocket->new(endpoints => [ 'tcp://127.0.0.1:54321' ]);

        $self->request($req);
        $self->reply($rep);
    }

    sub on_reply_message {
        my ($self, $msg) = @_;
#        warn "REPLY MESSAGE: \n" . $msg->dump();
        warn "REPLY DATA: ${\$msg->message->data} \n";
        $self->reply->send($msg->message->data + 1);
        warn 'sent reply';
    }

    sub on_request_message {
        my ($self, $msg) = @_;
#        warn "REQUEST MESSAGE: \n" . $msg->dump();
        warn "REQUEST DATA: ${\$msg->message->data} \n";
        $self->request->send($msg->message->data + 1);
    }

    sub on_reply_socket_error {
        my ($self, $msg) = @_;
        warn "REPLY SOCKET_ERROR: \n" . $msg->dump();
    }

    sub on_request_socket_error {
        my ($self, $msg) = @_;
        warn "REQUEST SOCKET_ERROR: \n" . $msg->dump();
    }

    sub on_reply_bind_error {
        my ($self, $msg) = @_;
        warn "REPLY BIND_ERROR: \n" . $msg->dump();
    }

    sub on_request_connect_error {
        my ($self, $msg) = @_;
        warn "REQUEST MESSAGE: \n" . $msg->dump();
    }

    __PACKAGE__->meta->make_immutable();
}

my $app = App::Test->new();
$app->request->send(2);
$app->run_all();

