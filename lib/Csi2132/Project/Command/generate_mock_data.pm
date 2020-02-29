package Csi2132::Project::Command::generate_mock_data;
use Mojo::Base 'Mojolicious::Command';

use Data::Faker;
use Csi2132::Project::DB;

use constant USER_COUNT => 1000;
use constant USER_DELETED_CHANCE => 0.05;
use constant USER_AVERAGE_PHONE_NUMBERS => 1.5;
use constant HASH_TYPE => 'sha512_base64';

sub run {
    my ($self, @argv) = @_;
    my $db = $self->app->db;
    STDOUT->autoflush(1);

    my $faker = Data::Faker->new;

    # People
    my @user_emails = ('test@user.com', $self->_generate_unique_emails(USER_COUNT - 1));
    my $password = $self->app->hash_password(HASH_TYPE, 'password');
    my $people = {};
    print "Generating " . USER_COUNT . " users...";
    for my $id (1 .. USER_COUNT) {
        $people->{$id} = {
            person_id           => $id,
            first_name          => $faker->first_name,
            middle_name         => $faker->first_name,
            last_name           => $faker->last_name,
            street_address      => $faker->street_address,
            city                => $faker->city,
            state               => $faker->us_state,
            country             => 'USA',
            postal_code         => $faker->us_zip_code,
            email               => shift @user_emails,
            password            => $password,
            password_type       => HASH_TYPE,
            is_id_verified      => rand() > 0.5 ? 1 : 0,
            is_address_verified => rand() > 0.5 ? 1 : 0,
            is_deleted          => rand() < USER_DELETED_CHANCE ? 1 : 0,
        };
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
}

sub _generate_unique_emails {
    my ($self, $count) = @_;
    my $faker = Data::Faker->new;
    my %emails;
    while (keys %emails < $count) {
        $emails{$faker->email} = ();
    }
    return keys %emails;
}

1;