package Csi2132::Project::Controller::User;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;

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
        if ($self->is_valid_password($user->password_type, $password, $user->password) && !$user->is_deleted) {
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

sub post_register($self) {
    my $v = $self->validation;

    $v->csrf_protect;
    $v->required('first_name');
    $v->required('last_name');
    $v->required('email')->email_is_unique;
    $v->required('password')->equal_to('password2');

    return $self->render('user/register') if $v->has_error;

    my $params = $self->params_hash(@{ $v->passed });

    $params->{middle_name} = $self->param('middle_name') // '';
    $params->{password_type} = Csi2132::Project::DEFAULT_PASSWORD_TYPE;
    $params->{password} = $self->hash_password(Csi2132::Project::DEFAULT_PASSWORD_TYPE, $params->{password});

    my $person = $self->people->register($params);
    $self->session(person_id => $person->{person_id});
    $self->flash(message => 'Registered');
    $self->redirect_to('/');
}

sub logout($self) {
    $self->session(person_id => undef);
    $self->flash(message => 'Logged out');
    $self->redirect_to('/');
}

1;