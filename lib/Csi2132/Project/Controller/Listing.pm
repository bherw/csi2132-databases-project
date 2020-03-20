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
        $where_city
        }, $from_date, $to_date, ($city ? $city : ()))->hashes;

    $self->stash(listings => $listings);
}

1;
