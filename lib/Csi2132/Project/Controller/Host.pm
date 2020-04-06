package Csi2132::Project::Controller::Host;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;
use Csi2132::Project::DB;
use Data::GUID qw(guid);
use Csi2132::Project::Model::Property;

has property => sub($self) {
    my $property_id = $self->param('property_id');
    my $property = $self->db->query(q{
        SELECT
            property.*,
            person.first_name || ' ' || person.last_name as owner_name
        FROM property
        JOIN person ON host_id=person_id
        WHERE property_id=?}, $property_id)->hash;
    if (!$property) {
        $self->reply->not_found;
        return;
    }
    $self->stash(property => $property);
    return $property;
};

has amenities => sub($self) {
    my $property_id = $self->param('property_id');
    my $amenities = $self->db->query(q{SELECT amenity FROM property_amenity WHERE property_id=?}, $property_id)->arrays->flatten;
    $self->stash(amenities => $amenities);
    return $amenities;
};

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
    my $rental_agreements = $self->db->query(qq{
        SELECT
            RA.*,
            person.first_name || ' ' || person.last_name AS guest_name,
            $PROPERTY.title
        FROM $RENTAL_AGREEMENT RA
        JOIN $PERSON USING ("person_id")
        JOIN $PROPERTY USING ("property_id")
        WHERE host_id = ?
        AND ends_at >= current_date
        ORDER BY title ASC, starts_at ASC
        }, $person->person_id)->hashes;

    for (@$properties) {
        $_->{can_publish} = $self->properties->can_publish($_);
    }

    $self->stash(properties => $properties);
    $self->stash(rental_requests => $rental_requests);
    $self->stash(rental_agreements => $rental_agreements);
}

sub create($self) {
}

sub post_create($self) {
    my $v = $self->validate_listing;
    return $self->render('host/create') if $v->has_error;

    my $property_id = guid();
    my $attrs = $self->listing_attributes(property_id => $property_id);

    my $db = $self->db;
    my $tx = $db->begin;
    $db->insert($PROPERTY, $attrs);
    $db->insert_all($PROPERTY_AMENITY, [ map { +{ property_id => $property_id, amenity => $_ } } @{ $self->every_param('amenities') } ], { autocommit => 0});
    $tx->commit;

    $self->flash(messages => ['Created new property listing']);
    $self->redirect_to($self->url_for('/host'));
}

sub edit($self) {
    $self->property;
    $self->amenities;
}

sub post_edit($self) {
    my $v = $self->validate_listing;
    if ($v->has_error) {
        $self->property;
        $self->amenities;
        $self->render('host/edit');
        return;
    }

    my $property_id = $self->param('property_id');
    my $attrs = $self->listing_attributes();

    my $db = $self->db;
    my $tx = $db->begin;
    $db->update($PROPERTY, $attrs, { property_id => $property_id });
    $self->db->delete($PROPERTY_AMENITY, { property_id => $property_id });
    $self->db->insert_all($PROPERTY_AMENITY, [ map { +{ property_id => $property_id, amenity => $_ } } @{ $self->every_param('amenities') } ], { autocommit => 0});
    $tx->commit;

    $self->flash(messages => ['Updated ' . $attrs->{title}]);
    $self->redirect_to($self->url_for('/host'));
}

sub publish($self) {
    my $property = $self->property;

    if (!$self->properties->can_publish($property)) {
        $self->add_error("Can't publish $property->{title} yet, please finish filling it out");
        $self->redirect_to('/host');
        return;
    }

    $self->db->update($PROPERTY, { is_published => 1 }, { property_id => $property->{property_id}});
    $self->flash(messages => ["Published $property->{title}"]);
    $self->redirect_to('/host');
}

sub unpublish($self) {
    my $property = $self->property;

    $self->db->update($PROPERTY, { is_published => 0 }, { property_id => $property->{property_id}});
    $self->flash(messages => ["Unpublished $property->{title}"]);
    $self->redirect_to('/host');
}

sub delete($self) {
    $self->property;
}

sub confirm_delete($self) {
    my $property = $self->property;

    $self->properties->delete($property);
    $self->flash(messages => ["Deleted $property->{title}"]);
    $self->redirect_to('/host');
}

sub validate_listing($self) {
    my $v = $self->validation;
    $v->csrf_token;
    $v->required('title');
    $v->required('street_address');
    $v->required('city');
    $v->required('state');
    $v->required('country');
    $v->required('postal_code');
    $v->required('property_type');
    $v->required('room_type');
    $v->required('num_bathrooms');
    $v->required('num_bedrooms');
    $v->required('num_beds');
    $v->required('checkin_time_from');
    $v->required('checkin_time_to');
    $v->required('checkout_time_from');
    $v->required('checkout_time_to');
    $v->required('base_price');
    $v->required('currency');
    $v->required('summary');
    $v->required('advance_booking_allowed_for_num_months');
    return $v;
}

sub listing_attributes($self, %defaults) {
    my $advance_booking_allowed_for_num_months =
        $self->param('blocked_booking') ? 0
            : $self->param('advance_booking_allowed_for_num_months') > 0 ? $self->param('advance_booking_allowed_for_num_months')
            : undef;

    return {
        %defaults,
        host_id                                => $self->current_user->person_id,
        min_price                              => $self->param('base_price'),
        max_price                              => $self->param('base_price'),
        advance_booking_allowed_for_num_months => $advance_booking_allowed_for_num_months,
        $self->params_hash(qw(title street_address city state country postal_code property_type
            room_type num_bathrooms num_bedrooms num_beds checkin_time_from checkin_time_to
            checkout_time_from checkout_time_to base_price currency summary))->%*,
    };
}

1;
