package Csi2132::Project::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub params_hash($self, @names) {
    my %params;
    for my $name (@names) {
        $params{$name} = $self->param($name)
    }
    return \%params;
}

1;
