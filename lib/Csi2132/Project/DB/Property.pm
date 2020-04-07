package Csi2132::Project::DB::Property;
use Csi2132::Project::DB;
use DateTime;
use DateTime::Format::Pg;
use Scalar::Util qw(blessed);

use Mojo::Base -base, -signatures;

has 'pg';

# Returns true if the property is fully specified and can be published, i.e.,
# all required values are not null.
# Since AirBnB uses a wizard to setup the massive number of attributes,
# many attributes will be null during setup, but must not be null once the property
# is published.
# Params: a loaded property hashref or a property_id
sub can_publish($self, $property) {
    if (!ref $property) {
        $property = $self->pg->db->query('SELECT * FROM property WHERE property_id = ?', $property)->hash;
    }

    return !$property->{is_published}
        && $property->{street_address}
        && $property->{state}
        && $property->{country}
        && $property->{postal_code}
        && defined $property->{checkin_time_from}
        && defined $property->{checkin_time_to}
        && defined $property->{checkout_time_from}
        && defined $property->{checkout_time_to}
        && defined $property->{checkin_time_from}
        && $property->{base_price}
        && $property->{min_price}
        && $property->{max_price}
        && $property->{currency};
}

# Flags a property as deleted and deletes any pending rental requests.
# Params: a loaded property hashref
sub delete($self, $property) {
    my $db = $self->pg->db;
    my $tx = $db->begin;
    $db->update($PROPERTY, { is_published => 0 }, { property_id => $property->{property_id} });
    $db->update($PROPERTY, { is_deleted => 1 }, { property_id => $property->{property_id} });
    $db->delete($RENTAL_REQUESTS, { property_id => $property->{property_id} });
    $tx->commit;
}

# Loads a rental request corresponding to a given property and person.
# property and person may be loaded hashrefs or simply the ids.
sub rental_request($self, $property, $person) {
    my $property_id = ref $property ? $property->{property_id} : $property;
    my $person_id = ref $person ? $person->{person_id} : $person;
    return unless $person_id;

    return $self->pg->db->query(qq{
        SELECT * FROM $RENTAL_REQUESTS
        WHERE property_id = ? AND person_id = ?
        }, $property_id, $person_id)->hash;
}

# Computes the availability of a property in between two dates, inclusive.
# Params:
# $property: A loaded hashref with property_id, advance_booking_allowed_for_num_months, days_of_notice_required or a property_id
# $from: The starting date
# $to: The ending date
#
# Returns: A hashref in the following format: {'2020-01-01' => undef, '2020-01-02' => 'Unavailable'}
# where each key is a day in the range $from, $to, inclusive, and the value is undef if the property
# is availabile, or a string value giving the reason for unavailability otherwise.
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

    for (my $date = $from->clone; $date <= $to; $date->add(days => 1)) {
        my $ymd = $date->ymd('-');

        # Undef == available
        $unavailablity{$ymd} = ();

        if ($date < $today) {
            $unavailablity{$ymd} //= 'Date is in the past';
        }

        if ($date < $notice_date) {
            $unavailablity{$ymd} //= 'Host requires more notice';
        }

        if ($advance && $date > $advance_date) {
            $unavailablity{$ymd} //= 'Too far in advance';
        }
    }

    # Blocked properties default to unavailable,
    # but have certain blocks marked available
    if (defined $advance && $advance == 0) {
        for (my $date = $from->clone; $date <= $to; $date->add(days => 1)) {
            $unavailablity{$date->ymd('-')} //= 'Unavailable';
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
        for (; $date <= $ends_at; $date->add(days => 1)) {
            local $_ = $date;
            if ($date <= $to && $date >= $from) {
                $cb->();
            }
        }
    }
}

1;
