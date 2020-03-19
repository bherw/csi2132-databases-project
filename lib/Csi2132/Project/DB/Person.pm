package Csi2132::Project::DB::Person;
use Mojo::Base -base, -signatures;
use Csi2132::Project::DB;
use Csi2132::Project::Model::Person;
use Csi2132::Project::Model::Employee;
use Try::Tiny;

has 'pg';
has 'person_class' => 'Csi2132::Project::Model::Person';
has 'employee_class' => 'Csi2132::Project::Model::Employee';

sub load_by_email($self, $email) {
    my $attrs = $self->pg->db->query("SELECT * FROM $PERSON LEFT JOIN $EMPLOYEE USING (person_id) WHERE email=?", $email)->hash;
    return $self->_inflate($attrs);
}

sub load_by_id($self, $id) {
    my $attrs = $self->pg->db->query("SELECT * FROM $PERSON LEFT JOIN $EMPLOYEE USING (person_id) WHERE person_id=?", $id)->hash;
    return $self->_inflate($attrs);
}

sub register($self, $attrs) {
    $self->pg->db->insert($PERSON, $attrs);
    return $self->load_by_email($attrs->{email});
}

sub _inflate($self, $attrs) {
    return unless $attrs;
    my %employee_attrs = delete %$attrs{'position', 'salary'};
    my $user = $self->person_class->new($attrs);
    if (defined $employee_attrs{position}) {
        $user->{roles}{employee} = $self->employee_class->new(person_id => $attrs->{person_id}, %employee_attrs);
    }
    return $user;
}

1;