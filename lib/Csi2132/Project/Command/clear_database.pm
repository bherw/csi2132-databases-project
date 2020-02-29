package Csi2132::Project::Command::clear_database;
use Mojo::Base 'Mojolicious::Command';

sub run {
    my $self = shift;
    my $db = $self->app->db;
    my $tx = $db->begin;
    $db->query('SET CONSTRAINTS ALL DEFERRED');
    for (qw(employee branch payment rental_agreement message reviews property_available_date property_amenity
        property_accessibility property_bedroom property_host_language property_photo property_custom_house_rule
        property person_phone_number person)) {
        $db->query("DELETE FROM \"$_\"");
    }
    $tx->commit;
}

1;
