package Csi2132::Project::Controller::Listing;
use Csi2132::Project::DB;
use DateTime;
use DateTime::Format::Pg;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;

sub index($self) {
    if ($self->param('from_date')) {
        my $v = $self->validation;
        $v->required('from_date')->date;
        $v->required('to_date')->date->gte('from_date');

        return $self->stash(listings => []) unless $v->is_valid;
    }

    my $from_date = $self->param('from_date') || DateTime->now->ymd('-');
    my $to_date = $self->param('to_date') || $from_date;
    my $city = $self->param('city');
    my $where_city = $city ? ' AND city = $3 ' : '';

    my $listings = $self->db->query(qq{
        SELECT property_id, title, base_price, city
        FROM $PROPERTY P
        WHERE property_id NOT IN (
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
    my $property_id = $self->param('property_id');
    my $property = $self->db->query(q{
        SELECT
            property.*,
            person.first_name || ' ' || person.last_name as owner_name
        FROM property
        JOIN person ON host_id=person_id
        WHERE property_id=?}, $property_id)->hash;

    return $self->reply->not_found unless $property;

    $self->stash(property => $property);
}

1;
