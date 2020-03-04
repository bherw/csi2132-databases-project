package Csi2132::Project::Model::Person;
use v5.20;
use Mojo::Base -base, -signatures;

has 'person_id';
has 'first_name';
has 'middle_name';
has 'last_name';
has 'password';
has 'password_type';
has 'street_address';
has 'city';
has 'state';
has 'country';
has 'postal_code';
has 'email';
has 'is_email_verified';
has 'is_address_verified';
has 'is_deleted';

# Just Employee for now
has 'roles';

sub full_name($self) {
    $self->{first_name} . ' ' . $self->{last_name}
}

sub is_employee($self) {
    exists $self->{roles}{employee}
}

1;