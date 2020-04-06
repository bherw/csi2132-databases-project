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
    $self->helper(hash_password => sub($self, $type, $password) {
        croak "Invalid password hash type: $type" if $type ne 'sha512_base64';
        return _hash_password($type, $config->{secrets}->[0], $password);
    });

    # Validate salted hash
    $self->helper(is_valid_password => sub($self, $type, $password, $from_database) {
        croak "Invalid password hash type: $type" if $type ne 'sha512_base64';

        # Check all salts to prevent timing attacks
        return 0 < sum 0, map { secure_compare $from_database, _hash_password($type, $_, $password) } @{$config->{secrets}};
    });

    $self->helper(current_user => sub($self) {
        return undef unless my $person_id = $self->session('person_id');
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

    $self->helper(errors_for => sub($self, $name, %errors) {
        my $e = $self->helpers->validation->error($name);
        return unless $e;
        $errors{required} //= 'This field is required';
        return $self->helpers->tag(p => (class => 'form-error') => $errors{$e->[0]});
    });

    $self->helper(selected_options => sub ($self, $options, $selected) {
        my %selected;
        @selected{(ref $selected ? @$selected : $selected)} = ();
        [map {
            my $o = ref $_ ? $_ : [$_ => $_];
            [@$o, (exists $selected{$o->[1]} ? (selected => 'selected') : ())]
        } @$options]
    });

    my $v = $self->validator;
    $v->add_check(email_is_unique => sub($v, $name, $value) {
        return !!$self->people->load_by_email($value);
    });

    $v->add_check(date => sub($v, $name, $value) {
        return $value !~ /^\d{4,}-\d{2}-\d{2}$/;
    });

    $v->add_check(gte => sub($v, $name, $value, $to) {
        return 1 unless defined(my $other = $v->input->{$to});
        return $value lt $other;
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
    $self->helper(properties => sub {
        require Csi2132::Project::DB::Property;
        state $properties = Csi2132::Project::DB::Property->new(pg => $pg);
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
    $r->get('/')->to('home#home');

    # Test Queries (not to be included in the application)
    # TODO: replace with proper RBAC
    # Left as example of access control
    # my $test = $r->any('/test')->over(user_access => sub($c, $user) { $user->is_employee })->to('test_queries#');

    # Listings
    $r->get('/listing')->to('listing#index');
    $r->get('/listing/:property_id')->to('listing#show');
    $r->get('/listing/:property_id/rent')->over(user_access => 'listing/rent')->to('listing#rent');
    $r->post('/listing/:property_id/rent')->over(user_access => 'listing/rent')->to('listing#create_rental_request');

    # Host
    $r->get('/host')->over(user_access => 'host/index')->to('host#index');
    $r->get('/host/create')->over(user_access => 'host/create')->to('host#create');
    $r->post('/host/create')->over(user_access => 'host/create')->to('host#post_create');
    $r->get('/host/:property_id/edit')->over(user_access => 'host/edit')->to('host#edit');
    $r->post('/host/:property_id/edit')->over(user_access => 'host/edit')->to('host#post_edit');
    $r->post('/host/:property_id/publish')->over(user_access => 'host/publish')->to('host#publish');
    $r->post('/host/:property_id/unpublish')->over(user_access => 'host/unpublish')->to('host#unpublish');
    $r->post('/host/:property_id/delete')->over(user_access => 'host/delete')->to('host#delete');
    $r->delete('/host/:property_id')->over(user_access => 'host/delete')->to('host#confirm_delete');

    # Employee page
    $r->get('/employee')->over(user_access => sub($c, $user) { $user->is_employee })->to('employee#index');

    # Messages
    $r->get('/message')->over(user_access => 'message/index')->to('message#index');

    # Users
    $r->get('/user')->over(user_access => 'user/view self')->to('user#show');
    $r->get('/user/login')->to('user#login');
    $r->post('/user/login')->to('user#post_login');
    $r->get('/user/logout')->to('user#logout');
    $r->get('/user/register')->to('user#register');
    $r->post('/user/register')->to('user#post_register');
}

sub _hash_password($type, $salt, $password) {
    my $salted_password = $salt . $password;
    return sha512_base64($salted_password);
}

1;
