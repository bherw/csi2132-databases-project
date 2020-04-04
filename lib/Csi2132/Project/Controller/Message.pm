package Csi2132::Project::Controller::Message;
use Csi2132::Project::DB;
use Mojo::Base 'Csi2132::Project::Controller', -signatures;

sub index($self) {
    my $messages = $self->db->query(qq{
        SELECT $MESSAGE.*,
            sender.first_name || ' ' || sender.last_name AS sender_name,
            property.title AS property_title
        FROM $MESSAGE
        JOIN $PERSON sender ON sender_id = person_id
        JOIN $PROPERTY USING ("property_id")
        WHERE receiver_id = ?
        ORDER BY created_at DESC
        }, $self->current_user->person_id)->hashes;
    $self->stash(messages => $messages);
}

1;