package Csi2132::Project::Controller::Listing;
use Csi2132::Project::DB;
use DateTime;
use DateTime::Format::Pg;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;

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

sub index($self) {
    if ($self->param('from_date')) {
        my $v = $self->validation;
        $v->required('from_date')->date;
        if ($self->param('to_date')) {
            $v->optional('to_date')->date->gte('from_date');
        }

        return $self->stash(listings => []) unless $v->is_valid;
    }

    my $today = DateTime->today->ymd('-');
    my $from_date = $self->param('from_date') || $today;
    my $to_date = $self->param('to_date') || $from_date;
    $self->stash(today => $today);
    $self->stash(from_date => $from_date);
    $self->stash(to_date => $to_date);
    my $city = $self->param('city');
    my $where_city = $city ? ' AND city = $3 ' : '';

    my $listings = $self->db->query(qq{
        SELECT property_id, title, base_price, city
        FROM $PROPERTY P
        WHERE is_published
        AND property_id NOT IN (
            SELECT property_id FROM $RENTAL_AGREEMENT WHERE \$1 BETWEEN starts_at AND ends_at
        )
        AND NOT EXISTS (
            SELECT 1 FROM $RENTAL_AGREEMENT R
            WHERE R.property_id=P.property_id
            AND starts_at BETWEEN \$1 AND \$2)
        AND \$1 >= current_date + days_of_notice_required
        AND (
            advance_booking_allowed_for_num_months IS NULL
            OR advance_booking_allowed_for_num_months > 0 AND
                \$1 <= current_date + (advance_booking_allowed_for_num_months || ' months')::interval
            OR advance_booking_allowed_for_num_months = 0 AND EXISTS (
                SELECT 1 FROM property_available_date AD
                    WHERE P.property_id=AD.property_id
                    AND \$1 BETWEEN starts_at AND ends_at
                    AND \$2 BETWEEN starts_at AND ends_at
            )
        )
        $where_city
        }, $from_date, $to_date, ($city ? $city : ()))->hashes;

    $self->stash(listings => $listings);
}

sub show($self) {
    my $property = $self->property or return;
    my $property_id = $property->{property_id};
    $self->stash(rental_request => scalar $self->properties->rental_request($property, $self->current_user));

    my $amenities = $self->db->query(qq{SELECT amenity FROM $PROPERTY_AMENITY WHERE property_id = ?}, $property_id)->arrays->flatten;
    $self->stash(amenities => $amenities);

    my $today = DateTime->today;
    my $from = $self->param('availability_from');
    $from = $from ? DateTime::Format::Pg->parse_datetime($from) : $today;
    my $to = $from->clone->add(months => 1)->subtract(days => 1);
    $self->stash(availability_from => $from);
    $self->stash(availability_to => $to);
    $self->stash(availability_prev => $from->clone->subtract(months => 1));
    $self->stash(availability_next => $to->clone->add(days => 1));
    $self->stash(unavailability => $self->properties->unavailability($property, $from, $to));
}

sub rent($self) {
    $self->property;
}

sub create_rental_request($self) {
    my $property = $self->property;
    my $person = $self->current_user;

    # Validate
    if ($self->param('from_date')) {
        my $v = $self->validation;
        $v->required('from_date')->date;
        if ($self->param('to_date')) {
            $v->optional('to_date')->date->gte('from_date');
        }

        return $self->render('user/register') if $v->has_error;

        if ($self->properties->rental_request($property, $person)) {
            $self->add_error('You already have a pending rental request');
            $self->redirect_to($self->url_for("/listing/$property->{property_id}"));
            return;
        }
    }

    $self->db->insert($RENTAL_REQUESTS, {
        property_id => $property->{property_id},
        person_id   => $person->{person_id},
        starts_at   => $self->param('from_date'),
        ends_at     => $self->param('to_date'),
    });
    $self->flash(message => "Requested a rental, please wait for the host to confirm your rental request.");
    $self->redirect_to($self->url_for("/listing/$property->{property_id}"));
}

1;
