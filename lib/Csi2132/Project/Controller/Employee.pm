package Csi2132::Project::Controller::Employee;
use Csi2132::Project::DB;
use Mojo::Base 'Mojolicious::Controller', -signatures;

has property => sub($self) {
    my $property_id = $self->param('property_id');
    my $property = $self->db->query(q{
        SELECT
            property.*,
            person.first_name || ' ' || person.last_name as owner_name
        FROM property
        JOIN person ON host_id=person_id
        WHERE property_id=?}, $property_id)->hash;
    if (!$property) {
        $self->reply->not_found;
        return;
    }
    $self->stash(property => $property);
    return $property;
};

sub index($self) {
    my $city = $self->param('city');
    my $where_city = $city ? ' AND city = $3 ' : '';
    my $country = $self->current_user->country;

    my $listings = $self->db->query(qq{
        SELECT property_id, title, base_price, city
        FROM $PROPERTY P
        WHERE is_published AND P.country = \'$country\'
        $where_city
        }, ($city ? $city : ()))->hashes;

    $self->stash(listings => $listings);
}
#self->current_user->country; get current country from user (person object)
1;
