package Csi2132::Project::Command::generate_mock_data;
use Mojo::Base 'Mojolicious::Command';

use Data::Faker;
use Csi2132::Project::DB;
use Digest::SHA qw(sha512_base64);

use constant USER_COUNT => 1000;
use constant USER_DELETED_CHANCE => 0.05;
use constant USER_AVERAGE_PHONE_NUMBERS => 1.5;

sub run {
    my ($self, @argv) = @_;
    my $db = $self->app->db;

    my $faker = Data::Faker->new;

    # People
    my @user_emails = ('test@user.com', $self->_generate_unique_emails(USER_COUNT - 1));
    my $people = {};
    for my $id (1 .. USER_COUNT) {
        print "\rGenerating user $id / " . USER_COUNT . "... ";
        $people->{$id} = my $user = {
            person_id           => $id,
            first_name          => $faker->first_name,
            middle_name         => $faker->first_name,
            last_name           => $faker->last_name,
            street_address      => $faker->street_address,
            city                => $faker->city,
            state               => $faker->us_state,
            country             => 'USA',
            postal_code         => $faker->us_zip_code,
            password            => "sha512:" . sha512_base64('password'),
            email               => shift @user_emails,
            is_id_verified      => rand() > 0.5 ? 1 : 0,
            is_address_verified => rand() > 0.5 ? 1 : 0,
            is_deleted          => rand() < USER_DELETED_CHANCE ? 1 : 0,
        };

        $db->insert($PERSON, $user);

        # person_phone_number
        my $phone_count = int(rand(USER_AVERAGE_PHONE_NUMBERS)) + 1;
        $user->{phone_numbers} = [];
        for my $i (1 .. $phone_count) {
            my $number = $faker->phone_number;
            push @{$user->{phone_numbers}}, $number;
            $db->insert($PERSON_PHONE_NUMBER, { person_id => $id, phone_number => $number });
        }
    }
    print "done.\n";
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