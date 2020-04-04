package Csi2132::Project::Controller::Host;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;
use Csi2132::Project::DB;

sub index($self) {
    my $person = $self->current_user;
    my $properties = $self->db->query(qq{
        SELECT * FROM $PROPERTY WHERE host_id = ? AND NOT is_deleted
        }, $person->{person_id})->hashes;
    my $rental_requests = $self->db->query(qq{
        SELECT $RENTAL_REQUESTS.*,
            person.first_name || ' ' || person.last_name AS guest_name,
            property.title
        FROM $RENTAL_REQUESTS
        JOIN $PERSON USING ("person_id")
        JOIN $PROPERTY USING ("property_id")
        WHERE host_id = ?
        }, $person->{person_id})->hashes;

    for (@$properties) {
        $_->{can_publish} = !$_->{is_published}
            && $_->{street_address}
            && $_->{state}
            && $_->{country}
            && $_->{postal_code}
            && defined $_->{checkin_time_from}
            && defined $_->{checkin_time_to}
            && defined $_->{checkout_time_from}
            && defined $_->{checkout_time_to}
            && defined $_->{checkin_time_from}
            && $_->{base_price}
            && $_->{min_price}
            && $_->{max_price}
            && $_->{currency};
    }

    $self->stash(properties => $properties);
    $self->stash(rental_requests => $rental_requests);
}

1;