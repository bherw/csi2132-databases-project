package Csi2132::Project::DB;
use v5.20;
use Const::Fast;
use List::Util qw(min);
use Mojo::Base 'Mojo::Pg::Database', -signatures;

const our $BRANCH => 'branch';
const our $EMPLOYEE => 'employee';
const our $MESSAGE => 'message';
const our $PERSON => 'person';
const our $PERSON_PHONE_NUMBER => 'person_phone_number';
const our $POSTGRES_PLACEHOLDER_LIMIT => 65535;
const our $PROPERTY => 'property';
const our $PROPERTY_AVAILABLE_DATE => 'property_available_date';
const our $PROPERTY_ACCESSIBILITY => 'property_accessibility';
const our $PROPERTY_AMENITY => 'property_amenity';
const our $PROPERTY_BEDROOM => 'property_bedroom';
const our $PROPERTY_CUSTOM_HOUSE_RULE => 'property_custom_house_rule';
const our $PROPERTY_HOST_LANGUAGE => 'property_host_language';
const our $RENTAL_AGREEMENT => 'rental_agreement';
const our $RENTAL_REQUESTS => 'rental_requests';
const our $REVIEWS => 'reviews';
const our $PAYMENT => 'payment';

# This is basically just a less flexible version of the Mojo::Pg::Database->insert
# method which it's overriding, but this course is about using SQL,
# so let's reinvent the wheel just to prove we can.
sub insert($self, $table, $values) {
    # Note: the ordering of keys/values with respect to each other is guaranteed
    # to be mutually stable if the hash has not been modified.
    my $attributes = join ',', map {quotemeta $_} keys %$values;
    my $placeholders = substr ',?' x scalar(keys %$values), 1;
    $self->query("INSERT INTO $table ($attributes) VALUES($placeholders)", values %$values);
}

# Insert many rows into the db at once.
# values should be an arrayref of hashrefs.
# Assumes that all rows have the same attributes.
sub insert_all($self, $table, $values, $options = {}) {
    my @values = @$values;
    $options->{autocommit} //= 1;
    return unless @values;
    my @attributes = keys %{ $values[0] };
    my $attributes_str = join ',', map {quotemeta $_} @attributes;
    my $placeholders_for_one = '(' . substr(',?' x @attributes, 1) . ')';
    my $tx = $self->begin if $options->{autocommit};

    while (@values) {
        my $row_count = min(int($POSTGRES_PLACEHOLDER_LIMIT / @attributes), scalar(@values));
        my @rows = @values[0..$row_count-1];
        @values = @values[$row_count..$#values];
        my $placeholders = substr(("," . $placeholders_for_one) x $row_count, 1);
        my @bind_values = map { @$_{@attributes} } @rows;
        $self->query("INSERT INTO $table ($attributes_str) VALUES $placeholders", @bind_values);
    }

    $tx->commit if $options->{autocommit};
}

# A helper function for making very basic UPDATE queries. Again, this is roughly
# equivalent to the SQL::Abstract version, just much less flexible.
sub update($self, $table, $values, $where) {
    my $attributes = join ',', map { quotemeta($_) . '=?' } keys %$values;
    my $where_clause = join ' AND ', map { quotemeta($_) . '=?' } keys %$where;
    $self->query("UPDATE $table SET $attributes WHERE $where_clause", values %$values, values %$where);
}

# A helper function for making very basic DELETE queries. Again, this is roughly
# equivalent to the SQL::Abstract version, just much less flexible.
sub delete($self, $table, $where) {
    my $where_clause = join ' AND ', map { quotemeta($_) . '=?' } keys %$where;
    $self->query("DELETE FROM $table WHERE $where_clause", values %$where);
}

# This class method exports the relation names as constants into packages which
# import this package, which allows relations to be renamed without need for codebase changes.
# Warning: Contains mild levels of perl magic.
sub import {
    my $caller = caller;
    for (qw(BRANCH EMPLOYEE PAYMENT PERSON PERSON_PHONE_NUMBER PROPERTY
        PROPERTY_AVAILABLE_DATE PROPERTY_ACCESSIBILITY PROPERTY_AMENITY
        PROPERTY_BEDROOM PROPERTY_CUSTOM_HOUSE_RULE PROPERTY_HOST_LANGUAGE
        RENTAL_AGREEMENT RENTAL_REQUESTS REVIEWS MESSAGE
    )) {
        no strict 'refs';
        *{"${caller}::$_"} = *$_;
    }
}

1;