package Csi2132::Project::Command::generate_mock_data;
use Const::Fast;
use Csi2132::Project::DB;
use Data::Faker;
use Mojo::Base 'Mojolicious::Command';

use constant EMPLOYEE_COUNT => 1000;
use constant USER_COUNT => 1000;
use constant USER_DELETED_CHANCE => 0.05;
use constant USER_AVERAGE_PHONE_NUMBERS => 1.5;
use constant HASH_TYPE => 'sha512_base64';

const my @COUNTRIES => qw(USA Canada Germany UK France Mexico Japan China);

my $faker = Data::Faker->new;

sub run {
    my ($self, @argv) = @_;
    my $db = $self->app->db;
    STDOUT->autoflush(1);

    # People
    my @user_emails = ('test@user.com', $self->_generate_unique_emails(USER_COUNT - 1));

    my $people = {};
    print "Generating " . USER_COUNT . " users...";
    for my $id (1 .. USER_COUNT) {
        $people->{$id} = $self->_generate_person(
            person_id => $id,
            email     => shift @user_emails,
        );
    }
    $db->insert_all($PERSON, [values %$people]);
    print " done.\n";

    # person_phone_number
    print "Generating approximately " . (USER_COUNT * USER_AVERAGE_PHONE_NUMBERS) . " phone numbers...";
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

    # Branches with managers
    print "Generating " . EMPLOYEE_COUNT . " employees for " . scalar(@COUNTRIES) . ' countries...';
    my $person_id = USER_COUNT + 1;
    my $employees_person = {};
    my $employees = {};
    my $branches = {};

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
            person_id  => $manager_id,
            email      => "manager-$country\@nisebnb.com",
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
        $db->insert_all($BRANCH, [values %$branches]);
        $db->insert_all($PERSON, [values %$employees_person]);
        $db->insert_all($EMPLOYEE, [values %$employees]);
        $tx->commit;
    }
    say ' done.';
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
    @COUNTRIES[int(rand(scalar @COUNTRIES))]
}

1;