package Csi2132::Project::DB;
use Mojo::Base 'Mojo::Pg::Database';
use Const::Fast;

const our $PERSON => 'person';
const our $PERSON_PHONE_NUMBER => 'person_phone_number';

# This is basically just a less flexible version of the Mojo::Pg::Database->insert
# method which it's overriding, but this course is about using SQL,
# so let's reinvent the wheel just to prove we can.
sub insert {
    my ($self, $table, $values) = @_;
    my $attributes = join ',', map {quotemeta $_} keys %$values;
    my $placeholders = substr ',?' x scalar(keys %$values), 1;
    $self->query("INSERT INTO $table ($attributes) VALUES($placeholders)", values %$values);
}

sub import {
    my $caller = caller;
    for (qw(PERSON PERSON_PHONE_NUMBER)) {
        no strict 'refs';
        *{"${caller}::$_"} = *$_;
    }
}

1;