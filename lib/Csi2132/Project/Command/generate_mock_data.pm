package Csi2132::Project::Command::generate_mock_data;
use Const::Fast;
use Csi2132::Project::DB;
use Data::Faker;
use DateTime;
use Text::Lorem;
use Mojo::Base 'Mojolicious::Command', -signatures;

use constant EMPLOYEE_COUNT => 1000;
use constant PROPERTY_COUNT => 1000;
use constant USER_COUNT => 1000;
use constant USER_DELETED_CHANCE => 0.05;
use constant USER_AVERAGE_PHONE_NUMBERS => 1.5;
use constant HASH_TYPE => 'sha512_base64';
use constant MAX_BEDROOMS => 6;
use constant MAX_BATHROOMS => 4;
use constant BEDROOM_BED_FACTOR => 2;
use constant MAX_DAYS_OF_NOTICE_REQUIRED => 7;
use constant SAMEDAY_BOOKING_CHANCE => 0.8;
use constant MAX_ADVANCE_BOOKING => 6;
use constant MIN_STAY_LONGER_THAN_ONE_CHANCE => 0.2;
use constant MAX_MIN_STAY => 30;
use constant MAX_STAY_LENGTH_GT_MIN_STAY_CHANCE => 0.8;
use constant MAX_STAY_LENGTH => 365;
use constant BASE_PRICE_MEAN => 60;
use constant BASE_PRICE_SD => 30;
use constant MAX_WEEKLY_DISCOUNT => 20;
use constant MAX_MONTHLY_DISCOUNT => 20;
use constant PROPERTY_DELETED_CHANCE => 0.05;
use constant PROPERTY_PUBLISHED_CHANCE => 0.95;
use constant ALLOW_INDEFINITE_FUTURE_BOOKING_CHANCE => 0.2;
use constant BLOCKED_PROPERTIES_GENERATE_DAYS => 365;
use constant PROPERTY_ACCESSIBILITY_CHANCE => 0.1;

const my @ACCESSIBILITY_TYPES => ('No stairs or steps to enter', 'Wide entrance for guests', 'Well-lit path to entrance', 'Step-free path to entrance');
const my @COUNTRIES => qw(USA Canada Germany UK France Mexico Japan China);
const my @PROPERTY_TYPES => (
    # Apartment
    'Apartment', 'Condominium', 'Casa particular (Cuba)', 'Loft', 'Serviced apartment',

    # House
    'House', 'Bungalow', 'Cabin', 'Chalet', 'Cottage', 'Cycladic house (Greece)', 'Dammuso (Italy)', 'Dome house', 'Earth house', 'Farm stay', 'Houseboat', 'Hut', 'Lighthouse', 'Pension (South Korea)', 'Shepherds Hut (U.K., France)', 'Tiny house', 'Townhouse', 'Trullo (Italy)', 'Villa',

    # Secondary unit
    'Guesthouse', 'Guest suite',

    # Unique space
    'Barn', 'Boat', 'Bus', 'Camper/RV', 'Campsite', 'Castle', 'Cave', 'Igloo', 'Island', 'Plane', 'Tent', 'Teepee', 'Train', 'Treehouse', 'Windmill', 'Yurt',

    # Bed and breakfast
    'Minsu (Taiwan)', 'Nature lodge', 'Ryokan (Japan)',

    # Boutique hotel
    'Boutique hotel', 'Aparthotel', 'Heritage hotel (India)', 'Hostel', 'Hotel', 'Resort', 'Kezhan (China)'
);
const my @ROOM_TYPES => ('Entire place', 'Private room', 'Hotel room', 'Shared room');
const my @CURRENCY_TYPES => ('CAD', 'USD');

my $faker = Data::Faker->new;
my $lorem = Text::Lorem->new;

has people => sub { shift->generate_people };
has peoples_phone_numbers => sub { shift->generate_peoples_phone_numbers };
has employees => sub { shift->generate_employees };
has properties => sub { shift->generate_properties };
has properties_available_dates => sub { shift->generate_property_available_dates };
has properties_accessibility => sub { shift->generate_property_accessibility };

sub run {
    my ($self, @argv) = @_;
    STDOUT->autoflush(1);

    $self->people;
    $self->peoples_phone_numbers;
    $self->employees;
    $self->properties;
    $self->properties_available_dates;
    $self->properties_accessibility;
}

sub generate_people($self) {
    my $db = $self->app->db;
    print "Generating " . USER_COUNT . " users...";

    if ($db->query("SELECT 1 FROM $PERSON LIMIT 1")->rows) {
        say " already populated, skipping.";
        return { map { ($_->{person_id} => $_) } @{ $db->query("SELECT * FROM $PERSON")->hashes } };
    }

    # People
    my @user_emails = ('test@user.com', $self->_generate_unique_emails(USER_COUNT -1));

    my $people = {};
    for my $id (1 .. USER_COUNT) {
        $people->{$id} = $self->_generate_person(
            person_id => $id,
            email     => shift @user_emails,
        );
    }
    $db->insert_all($PERSON, [ values %$people ]);
    print " done.\n";
    return $people;
}

sub generate_peoples_phone_numbers($self) {
    my $db = $self->app->db;
    my $people = $self->people;
    print "Generating approximately " . (USER_COUNT * USER_AVERAGE_PHONE_NUMBERS) . " phone numbers...";

    if ($db->query("SELECT 1 FROM $PERSON_PHONE_NUMBER LIMIT 1")->rows) {
        say " already populated, skipping.";
        return;
    }

    my @phone_numbers;
    for my $id (1 .. USER_COUNT) {
        my $phone_count = int(rand(USER_AVERAGE_PHONE_NUMBERS)) + 1;
        $people->{$id}{phone_numbers} = [];
        for my $i (1 .. $phone_count) {
            my $number = $faker->phone_number;
            push @{$people->{$id}{phone_numbers}}, $number;
            push @phone_numbers, { person_id => $id, phone_number => $number };
        }
    }
    $db->insert_all($PERSON_PHONE_NUMBER, \@phone_numbers);
    print " done.\n";
    return \@phone_numbers;
}

sub generate_employees($self) {
    my $db = $self->app->db;

    # Branches with managers
    print "Generating " . EMPLOYEE_COUNT . " employees for " . scalar(@COUNTRIES) . ' countries...';
    my $person_id = USER_COUNT +1;
    my $employees_person = {};
    my $employees = {};
    my $branches = {};

    if ($db->query('SELECT 1 FROM employee LIMIT 1')->rows) {
        say " already populated, skipping.";
        return;
    }

    my $ceo_id = $person_id++;
    $employees_person->{ceo} = $self->_generate_person(
        person_id => $ceo_id,
        email     => 'ceo@nisebnb.com',
    );

    $employees->{ceo} = {
        person_id  => $ceo_id,
        manager_id => undef,
        position   => 'ceo',
        workplace  => 'USA',
        salary     => 1000000,
    };

    # Branches and managers
    for my $country (@COUNTRIES) {
        my $manager_id = $person_id++;
        $branches->{$country} = {
            country    => $country,
            manager_id => $manager_id
        };
        $employees_person->{$manager_id} = $self->_generate_person(
            person_id => $manager_id,
            email     => "manager-$country\@nisebnb.com",
        );
        $employees->{$manager_id} = {
            person_id  => $manager_id,
            manager_id => $ceo_id,
            position   => 'manager',
            workplace  => $country,
            salary     => 100000 + int(rand(100000)),
        };
    }

    # Employees
    for (1 .. EMPLOYEE_COUNT) {
        my $employee_id = $person_id++;
        my $country = _random_country();
        $employees_person->{$employee_id} = $self->_generate_person(
            person_id => $employee_id,
            email     => "employee-$employee_id\@nisebnb.com",
        );
        $employees->{$employee_id} = {
            person_id  => $employee_id,
            manager_id => $branches->{$country}{manager_id},
            position   => 'staff',
            workplace  => $country,
            salary     => 40000 + int(rand(25000)),
        };
    }

    {
        my $tx = $db->begin;
        $db->query('SET CONSTRAINTS branch_manager_id_fkey DEFERRED');
        $db->insert_all($BRANCH, [ values %$branches ], { autocommit => 0 });
        $db->insert_all($PERSON, [ values %$employees_person ], { autocommit => 0 });
        $db->insert_all($EMPLOYEE, [ values %$employees ], { autocommit => 0 });
        $tx->commit;
    }
    say ' done.';
    return $employees;
}

sub generate_properties($self) {
    my $db = $self->app->db;
    my $people = $self->people;
    print "Generating @{[ PROPERTY_COUNT ]} properties...";

    if ($db->query("SELECT 1 FROM $PROPERTY LIMIT 1")->rows) {
        say " already populated, skipping.";
        return { map { ($_->{property_id} => $_) } @{ $db->query("SELECT * FROM $PROPERTY")->hashes } };
    }

    my $properties = {};
    for my $property_id (1 .. PROPERTY_COUNT) {
        my $owner = _random_person($people);
        my $property_type = _random_element(@PROPERTY_TYPES);
        my $num_bedrooms = int(rand(MAX_BEDROOMS));
        my $checkin_time_from = int(rand(24));
        my $checkin_time_to = $checkin_time_from + int(rand(24 - $checkin_time_from));
        my $checkout_time_from = int(rand(24));
        my $checkout_time_to = $checkout_time_from + int(rand(24 - $checkout_time_from));
        my $min_stay_length = 1 + (rand() < MIN_STAY_LONGER_THAN_ONE_CHANCE ? int(rand(MAX_MIN_STAY)) : 0);
        my $max_stay_length = $min_stay_length + (rand() < MAX_STAY_LENGTH_GT_MIN_STAY_CHANCE ? int(rand(MAX_STAY_LENGTH -$min_stay_length)) : 0);

        # This calculation is wrong, but it could be fixed later. At least the constants are named properly.
        my $base_price = BASE_PRICE_MEAN +(rand() > 0.5 ? -1 : 1) * BASE_PRICE_SD;

        $properties->{$property_id} = {
            property_id                            => $property_id,
            title                                  => "$owner->{first_name}'s $property_type",
            street_address                         => $faker->street_address,
            city                                   => $faker->city,
            state                                  => $faker->us_state,
            country                                => $owner->{country},
            postal_code                            => $faker->us_zip_code,
            is_published                           => rand() < PROPERTY_PUBLISHED_CHANCE ? 1 : 0,
            is_dedicated_guest_space               => rand() < 0.5 ? 1 : 0,
            is_instant_book_enabled                => rand() < 0.5 ? 1 : 0,
            property_type                          => $property_type,
            room_type                              => _random_element(@ROOM_TYPES),
            neighborhood                           => rand() < 0.5 ? $faker->city : '',
            num_bathrooms                          => int(rand(MAX_BATHROOMS)),
            num_bedrooms                           => $num_bedrooms,
            num_beds                               => $num_bedrooms + int(rand($num_bedrooms * (BEDROOM_BED_FACTOR -1))),
            checkin_time_from                      => sprintf('%02d:00', $checkin_time_from),
            checkin_time_to                        => sprintf('%02d:00', $checkin_time_to),
            checkout_time_from                     => sprintf('%02d:00', $checkout_time_from),
            checkout_time_to                       => sprintf('%02d:00', $checkout_time_to),
            requires_guest_id_validation           => 0,
            requires_guest_good_reputation         => 0,
            summary                                => $lorem->paragraphs(int(rand(1)) + 1),
            your_space                             => $lorem->paragraphs(int(rand(1)) + 1),
            your_availability                      => $lorem->paragraphs(int(rand(1)) + 1),
            your_neighborhood                      => $lorem->paragraphs(int(rand(1)) + 1),
            getting_around                         => $lorem->paragraphs(int(rand(1)) + 1),
            days_of_notice_required                => int(rand(MAX_DAYS_OF_NOTICE_REQUIRED)),
            sameday_booking_allowed_before_time    => rand() < SAMEDAY_BOOKING_CHANCE ? sprintf('%02d:00', int(rand(24))) : undef,
            advance_booking_allowed_for_num_months => rand() < ALLOW_INDEFINITE_FUTURE_BOOKING_CHANCE ? undef : int(rand(MAX_ADVANCE_BOOKING)),
            min_stay_length                        => $min_stay_length,
            max_stay_length                        => $max_stay_length,
            base_price                             => $base_price,
            min_price                              => $base_price,
            max_price                              => $base_price,
            currency                               => _random_element(@CURRENCY_TYPES),
            weekly_discount                        => int(rand(MAX_WEEKLY_DISCOUNT)),
            monthly_discount                       => int(rand(MAX_MONTHLY_DISCOUNT)),
            is_deleted                             => rand() < PROPERTY_DELETED_CHANCE ? 1 : 0,
            is_suitable_for_children               => rand() < 0.5 ? (rand() < 0.5 ? 1 : 0) : undef,
            is_suitable_for_infants                => rand() < 0.5 ? (rand() < 0.5 ? 1 : 0) : undef,
            is_suitable_for_pets                   => rand() < 0.5 ? (rand() < 0.5 ? 1 : 0) : undef,
            is_smoking_allowed                     => rand() < 0.5 ? (rand() < 0.5 ? 1 : 0) : undef,
            is_events_or_parties_allowed           => rand() < 0.5 ? (rand() < 0.5 ? 1 : 0) : undef,
            must_climb_stairs                      => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            potential_for_noise                    => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            pets_live_on_property                  => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            no_parking_on_property                 => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            some_spaces_are_shared                 => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            amenity_limitations                    => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            surveillance_on_property               => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            weapons_on_property                    => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
            dangerous_animals_on_property          => rand() < 0.5 ? $lorem->get_paragraph(rand(2) + 1) : undef,
        };
    }
    $db->insert_all($PROPERTY, [ values %$properties ]);
    say " done.";

    return $properties;
}

sub generate_property_available_dates($self) {
    my $db = $self->app->db;
    my $properties = $self->properties;
    print "Generating available dates for blocked properties...";

    if ($db->query("SELECT 1 FROM $PROPERTY_AVAILABLE_DATE LIMIT 1")->rows) {
        say " already populated, skipping.";
        return;
    }

    my @property_availability;
    for my $property (values %$properties) {
        next unless !defined $property->{advance_booking_allowed_for_num_months};

        my $available = 1;
        my $date = DateTime->now();
        for my $i (0 .. BLOCKED_PROPERTIES_GENERATE_DAYS) {
            if (rand() < 0.5) {
                $available = !$available;
            }
            if ($available) {
                push @property_availability, {
                    property_id    => $property->{property_id},
                    available_date => $date->ymd('-'),
                };
            }
            $date = $date->add(days => 1);
        }
    }
    $db->insert_all($PROPERTY_AVAILABLE_DATE, \@property_availability);
    say " done.";
    return \@property_availability;
}

sub generate_property_accessibility($self) {
    return $self->generate_property_enum($PROPERTY_ACCESSIBILITY, 'accessibility', \@PROPERTY_ACCESSIBILITY, PROPERTY_ACCESSIBILITY_CHANCE);
}

sub generate_property_enum($self, $table, $enum_name, $enum_values, $chance) {
    my $db = $self->app->db;
    my $properties = $self->properties;
    print "Generating $enum_name for properties...";

    if ($db->query("SELECT 1 FROM $table LIMIT 1")->rows) {
        say " already populated, skipping.";
        return;
    }

    my @enum;
    for my $property (values %$properties) {
        for my $value (_random_subset($enum_values, $chance)) {
            push @enum, {
                property_id => $property->{property_id},
                $enum_name  => $value,
            }
        }
    }
    $db->insert_all($table, \@enum);
    say " done";
    return \@enum;
}

sub _generate_person {
    my ($self, %defaults) = @_;
    state $password = $self->app->hash_password(HASH_TYPE, 'password');
    return {
        %defaults,
        first_name          => $faker->first_name,
        middle_name         => $faker->first_name,
        last_name           => $faker->last_name,
        street_address      => $faker->street_address,
        city                => $faker->city,
        state               => $faker->us_state,
        country             => _random_country(),
        postal_code         => $faker->us_zip_code,
        password            => $password,
        password_type       => HASH_TYPE,
        is_id_verified      => rand() > 0.5 ? 1 : 0,
        is_address_verified => rand() > 0.5 ? 1 : 0,
        is_deleted          => rand() < USER_DELETED_CHANCE ? 1 : 0,
    }
}

sub _generate_unique_emails {
    my ($self, $count) = @_;
    my %emails;
    while (keys %emails < $count) {
        $emails{$faker->email} = ();
    }
    return keys %emails;
}

sub _random_country {
    _random_element(@COUNTRIES)
}

sub _random_element {
    @_[int(rand(scalar @_))]
}

sub _random_subset($set, $chance) {
    grep { rand() < $chance } @$set
}

sub _random_person {
    my $people = shift;
    my @ids = keys %$people;
    return $people->{@ids[int(rand(scalar @ids))]};
}

1;