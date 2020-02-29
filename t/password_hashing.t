#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use Test::Mojo;
use Test::Fatal;

use constant MODE => 'sha512_base64';

my $t = Test::Mojo->new('Csi2132::Project');
my $app = $t->app;

subtest 'validates hash type' => sub {
    like exception { $app->hash_password('foobar', 'password') }, qr/Invalid password hash type/;
    like exception { $app->is_valid_password('foobar', 'password') }, qr/Invalid password hash type/;
};

my $hash = $app->hash_password(MODE, 'password');
my $hash2 = $app->hash_password(MODE, 'password2');

subtest 'hashes passwords properly' => sub {
    isnt $hash, 'password';
    isnt $hash, $hash2;
};

subtest 'validates hashes' => sub {
    ok $app->is_valid_password(MODE, 'password', $hash);
    ok !$app->is_valid_password(MODE, 'password', $hash2);
};

unshift @{$app->secrets}, 'new secret';

subtest 'validates hashes with old secrets' => sub {
    ok $app->is_valid_password(MODE, 'password', $hash);
    ok !$app->is_valid_password(MODE, 'password', $hash2);
};

subtest 'uses latest secrets for hashing' => sub {
    isnt $app->hash_password(MODE, 'password'), $hash;
};

done_testing();
