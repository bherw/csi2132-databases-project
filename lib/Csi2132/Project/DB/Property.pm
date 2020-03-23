package Csi2132::Project::DB::Property;
use Csi2132::Project::DB;
use DateTime;
use DateTime::Format::Pg;
use Scalar::Util qw(blessed);

use Mojo::Base -base, -signatures;

has 'pg';

sub unavailability($self, $property, $from, $to) {
    unless (ref $property) {
        $property = $self->pg->db->query(qq{
            SELECT property_id, advance_booking_allowed_for_num_months, days_of_notice_required
            FROM $PROPERTY
            WHERE property_id = ?}, $property)->hash;
    }
    $from = DateTime::Format::Pg->parse_datetime($from) unless blessed $from;
    $to = DateTime::Format::Pg->parse_datetime($to) unless blessed $to;

    my ($id, $advance, $notice) = @$property{qw(property_id advance_booking_allowed_for_num_months days_of_notice_required)};
    my %unavailablity;

    my $today = DateTime->today;
    my $notice_date = $today->clone->add(days => $notice);
    my $advance_date = defined $advance ? $today->clone->add(months => $advance) : undef;
    my $date = $from->clone;

    while ($date < $to) {
        my $ymd = $date->ymd('-');

        # Undef == available
        $unavailablity{$ymd} = ();

        if ($date < $notice_date) {
            $unavailablity{$ymd} //= 'Host requires more notice';
        }

        if ($advance && $date > $advance_date) {
            $unavailablity{$ymd} //= 'Too far in advance';
        }

        $date->add(days => 1);
    }

    # Blocked properties default to unavailable,
    # but have certain blocks marked available
    if (defined $advance && $advance == 0) {
        while ($date <= $to) {
            $unavailablity{$date->ymd('-')} //= 'Unavailable';
            $date->add(days => 1)
        }

        my $unblocked_dates = $self->pg->db->query(qq{
            SELECT starts_at, ends_at FROM $PROPERTY_AVAILABLE_DATE
            WHERE property_id = \$1
            AND starts_at <= \$3 AND ends_at >= \$2
            }, $id, $from, $to)->hashes;
        _for_date_ranges($unblocked_dates, $from, $to, sub {
            my $ymd = $_->ymd('-');
            if (defined $unavailablity{$ymd} && $unavailablity{$ymd} eq 'Unavailable') {
                $unavailablity{$ymd} = undef;
            }
        });
    }

    my $rentals = $self->pg->db->query(qq{
        SELECT starts_at, ends_at FROM $RENTAL_AGREEMENT
        WHERE property_id = \$1 AND starts_at <= \$3 AND ends_at >= \$2
        }, $id, $from, $to)->hashes;
    _for_date_ranges($rentals, $from, $to, sub {
        $unavailablity{$_->ymd('-')} = 'Rented';
    });

    return \%unavailablity;
}

sub _for_date_ranges($ranges, $from, $to, $cb) {
    for my $range (@$ranges) {
        my $date = DateTime::Format::Pg->parse_datetime($range->{starts_at});
        my $ends_at = DateTime::Format::Pg->parse_datetime($range->{ends_at});
        while ($date <= $ends_at) {
            local $_ = $date;
            if ($date <= $to && $date >= $from) {
                $cb->();
            }
            $date->add(days => 1);
        }
    }
}

1;
