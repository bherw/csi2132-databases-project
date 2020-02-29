package Csi2132::Project;
use Carp qw(croak);
use Digest::SHA qw(sha512_base64);
use List::Util qw(sum);
use Mojo::Base 'Mojolicious';
use Mojo::Pg;
use Mojo::Util qw(secure_compare);
use Csi2132::Project::DB;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Config
    my $config = $self->plugin('Config');

    if (!defined $config->{secrets} || @{$config->{secrets}} < 1) {
        print "Insecure configuration: missing random value for secrets\n";
        exit 1;
    }
    $self->secrets($config->{secrets});

    # Salted hash
    $self->helper(hash_password => sub {
        my ($self, $type, $password) = @_;
        croak "Invalid password hash type: $type" if $type ne 'sha512_base64';
        return _hash_password($type, $config->{secrets}->[0], $password);
    });

    # Validate salted hash
    $self->helper(is_valid_password => sub {
        my ($self, $type, $password, $from_database) = @_;
        croak "Invalid password hash type: $type" if $type ne 'sha512_base64';

        # Check all salts to prevent timing attacks
        return 0 < sum 0, map { secure_compare $from_database, _hash_password($type, $_, $password) } @{$config->{secrets}};
    });

    # Commands
    push @{$self->commands->namespaces}, 'Csi2132::Project::Command';

    # Model
    my $pg = Mojo::Pg->new($config->{pg});
    $pg->database_class('Csi2132::Project::DB');
    $self->helper(pg => sub {$pg});
    $self->helper(db => sub {$pg->db});

    # Migrate to latest version if necessary
    my $migrations_sql
        = $self
        ->home
        ->child('migrations')
        ->list
        ->sort
        ->map(sub {shift->slurp})
        ->join("\n");
    $pg->auto_migrate(1)->migrations->name('project')->from_string($migrations_sql);
    $pg->db;

    # Router
    my $r = $self->routes;
    $r->namespaces([ 'Csi2132::Project::Controller' ]);

    # Normal route to controller
    $r->get('/')->to('example#welcome');

    # Test Queries
    $r->get('/test')->to('test_queries#index');
    $r->get('/test/one')->to('test_queries#query_one');
    $r->get('/test/two')->to('test_queries#query_two');
    $r->get('/test/three')->to('test_queries#query_three');
    $r->get('/test/four')->to('test_queries#query_four');
    $r->get('/test/five')->to('test_queries#query_five');
    $r->get('/test/six')->to('test_queries#query_six');
    $r->get('/test/seven')->to('test_queries#query_seven');
    $r->get('/test/eight')->to('test_queries#query_eight');
    $r->get('/test/nine')->to('test_queries#query_nine');
    $r->get('/test/ten')->to('test_queries#query_ten');
}

sub _hash_password {
    my ($type, $salt, $password) = @_;
    my $salted_password = $salt . $password;
    return sha512_base64($salted_password);
}

1;
