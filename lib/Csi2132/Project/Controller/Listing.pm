package Csi2132::Project::Controller::Listing;
use Csi2132::Project::DB;
use DateTime;
use DateTime::Format::Pg;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;

sub index($self) {
    my $for_date = DateTime->now;

    if (my $specified_date = $self->param('date')) {
        if ($specified_date =~ /^\d{4,}-\d{2}-\d{2}$/) {
            $for_date = DateTime::Format::Pg->parse_datetime($specified_date);
        }
        else {
            $self->stash('errors' => ['Invalid date. Expected YYYY-MM-DD']);
        }
    }

    my $city = $self->param('city');
    my $where_city = $city ? " AND city = ? " : '';

    my $listings = $self->db->query(qq{
        SELECT property_id, title, base_price, city
        FROM $PROPERTY
        WHERE property_id NOT IN (
            SELECT property_id FROM $RENTAL_AGREEMENT WHERE ? BETWEEN starts_at AND ends_at
        )
        $where_city
        }, $for_date->ymd('-'), ($city ? $city : ()))->hashes;

    $self->stash(listings => $listings);
}

1;
