#!/usr/local/bin/perl
use strict;
use lib "../lib";
use Test;
use Test::More tests=>35;
#use Test::More tests=>'noplan';
#use Test::MockObject::Extends;

# these are for mocking Net::SMTP
my $data_sub = sub {
    my $self = shift;
    if (@_) {
        $self->reset() 
    } else {
        return 1;
    }
};

my $dataend_sub = sub {
    my $self = shift;
    $self->reset();
    return 1;
};

my $config_found;
my $to;
my $good_server;
eval {
    require Net::SMTP::Retryable::ConfigData;
    $config_found = 1;
    $to = Net::SMTP::Retryable::ConfigData->config('to-address');
    $good_server = Net::SMTP::Retryable::ConfigData->config('smtp-server');
};

require_ok('Net::SMTP::Retryable');

my $smtp;
my $bad_server = 'silly-server-name-which-doesnt-exist';
my $from = 'mprewitt@flatiron.org';

ok(!defined Net::SMTP::Retryable->new(bless [$bad_server], 'puppy'), 
        'bad mail host non-array ref ref');

ok(!defined Net::SMTP::Retryable->new([$bad_server], retryfactor => 0.1), 
        'bad mail host no retries');

ok(!defined Net::SMTP::Retryable->new([$bad_server], retryfactor => 0.1, connectretries => 5), 
        'bad mail host');

SKIP: {
    skip "No config info, smtp server or to address defined", 31 unless $good_server && $to && $config_found;

    isa_ok($smtp = Net::SMTP::Retryable->new([$bad_server, $good_server]), 'Net::SMTP::Retryable', 'constructor 2 hosts');
    isa_ok($smtp = Net::SMTP::Retryable->new([$bad_server, $good_server], retryfactor => 0.1, connectretries=>1, sendretries=>1), 'Net::SMTP::Retryable', 'constructor with retries');

    isa_ok($smtp = Net::SMTP::Retryable->new($good_server), 'Net::SMTP::Retryable', 'constructor 1');
#$smtp = mock_me($smtp);
    is($smtp->host($from), $good_server, 'host');

    for my $method ( qw( to cc bcc recipient ) ) {
        ok($smtp->mail($from), 'mail');
        ok($smtp->$method($to), $method);
        ok($smtp->data("This is a test with $method"), 'data');
    }

    ok($smtp->mail($from), 'mail');
    ok(!$smtp->data("Data without recipient"), 'data before recip');

    isa_ok($smtp = Net::SMTP::Retryable->new($good_server), 'Net::SMTP::Retryable', 'constructor 2');
    ok($smtp->mail($from), 'mail');
    ok($smtp->to($from), 'bad to address');

    isa_ok($smtp = Net::SMTP::Retryable->new($good_server), 'Net::SMTP::Retryable', 'constructor 3');

#$smtp = mock_me($smtp);

    ok($smtp->SendMail(mail=>$from, to=>$to, data=>'test 1'), 'SendMail');
    ok($smtp->SendMail(mail=>$from, to=>$to, data=>'test 2'), 'SendMail');
    ok($smtp->SendMail(mail=>[$from, Bits=>7], to=>$to, data=>'test 3'), 'SendMail');
    ok($smtp->SendMail(mail=>[$from, Bits=>7], to=>$to ), 'SendMail');
    ok($smtp->data(), 'blank data');
    ok($smtp->datasend("Testing datasend"), 'datasend');
    ok($smtp->dataend(), 'dataend');

    use_ok('MIME::Entity');
    my $mail = MIME::Entity->build(
        Subject => 'test',
        From => $from,
        Sender => $from,
        To => $to,
        'Reply-To' => $from,
        Type => 'text/plain',
        Data => 'test MIME::Entity send',
    );

    ok($mail->smtpsend($smtp), 'mime::entity->smtpsend');
};

sub mock_me {
    my $smtp = shift;
    my $mock_smtp = Test::MockObject::Extends->new($smtp);
    $mock_smtp->mock( 'data', $data_sub );
    $mock_smtp->set_true( 'datasend' );
    $mock_smtp->mock( 'dataend', $dataend_sub );
    return $mock_smtp;
}
