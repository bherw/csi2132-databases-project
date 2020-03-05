package Csi2132::Project::Controller::User;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub post_login($self) {
    my $email = $self->param('email');
    my $password = $self->param('password');

    unless (defined $email and defined $password) {
        $self->flash(error => 'Missing email and password');
        $self->redirect_to('/user/login');
        return;
    }

    my $user = $self->people->load_by_email($email);
    if ($user) {
        if ($self->is_valid_password($user->password_type, $password, $user->password)) {
            $self->session(person_id => $user->person_id);
            $self->redirect_to('/');
            return;
        }
    } else {
        # Prevent timing attacks
        $self->is_valid_password(Csi2132::Project::DEFAULT_PASSWORD_TYPE, $password, 'foobar');
    }

    $self->flash(error => 'Invalid email or password');
    $self->redirect_to('/user/login');
}

sub logout($self) {
    $self->session(person_id => undef);
    $self->flash(message => 'Logged out');
    $self->redirect_to('/');
}

1;