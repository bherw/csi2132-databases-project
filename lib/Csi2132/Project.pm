package Csi2132::Project;
use Carp qw(croak);
use Digest::SHA qw(sha512_base64);
use List::Util qw(sum);
use Mojo::Base 'Mojolicious', -signatures;
use Mojo::Pg;
use Mojo::Util qw(secure_compare);
use Csi2132::Project::DB;

use constant DEFAULT_PASSWORD_TYPE => 'sha512_base64';

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

    $self->helper(current_user => sub {
        my ($self) = @_;
        return unless my $person_id = $self->session('person_id');
        if (my $current_user = $self->stash('current_user')) {
            return $current_user;
        }
        my $current_user = $self->people->load_by_id($person_id);
        $self->stash(current_user => $current_user);
        $current_user
    });

    $self->helper(add_error => sub($self, $error) {
        my $errors = $self->flash('errors') // do {
            $self->flash(errors => (my $e = []));
            $e
        };
        if (my $old_error = $self->flash('error')) {
            $self->flash(error => undef);
            push @$errors, $old_error;
        }
        push @$errors, $error;
    });

    # Commands
    push @{$self->commands->namespaces}, 'Csi2132::Project::Command';

    # Model
    my $pg = Mojo::Pg->new($config->{pg});
    $pg->database_class('Csi2132::Project::DB');
    $self->helper(pg => sub {$pg});
    $self->helper(db => sub {$pg->db});
    $self->helper(people => sub {
        require Csi2132::Project::DB::Person;
        state $people = Csi2132::Project::DB::Person->new(pg => $pg)
    });

    # Migrate to latest version if necessary
    my $migrations_sql
        = $self
        ->home
        ->child('migrations')
        ->list
        ->sort
        ->map(sub {shift->slurp})
        ->join("\n");
    $pg->migrations->name('project')->from_string($migrations_sql);

    # Router
    my $r = $self->routes;
    $r->namespaces([ 'Csi2132::Project::Controller' ]);

    $r->add_condition(user_access => sub($route, $c, $captures, $access_type) {
        my $user = $c->current_user;
        if (!$user || ref $access_type eq 'CODE' && !$access_type->($c, $user)) {
            $c->render(status => 403, template => 'errors/forbidden');
            return;
        }

        return 1;
    });

    # Normal route to controller
    $r->get('/')->to('example#welcome');

    # Test Queries
    # TODO: replace with proper RBAC
    my $test = $r->any('/test')->over(user_access => sub($c, $user) { $user->is_employee })->to('test_queries#');
    $test->get('/')->to('#index');
    $test->get('/one')->to('#query_one');
    $test->get('/two')->to('#query_two');
    $test->get('/three')->to('#query_three');
    $test->get('/four')->to('#query_four');
    $test->get('/five')->to('#query_five');
    $test->get('/six')->to('#query_six');
    $test->get('/seven')->to('#query_seven');
    $test->get('/eight')->to('#query_eight');
    $test->get('/nine')->to('#query_nine');
    $test->get('/ten')->to('#query_ten');

    $r->get('/user')->over(user_access => 'user/view self')->to('user#show');
    $r->get('/user/login')->to('user#login');
    $r->post('/user/login')->to('user#post_login');
    $r->get('/user/logout')->to('user#logout');
}

sub _hash_password {
    my ($type, $salt, $password) = @_;
    my $salted_password = $salt . $password;
    return sha512_base64($salted_password);
}

1;
