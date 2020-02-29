package Csi2132::Project::Command::reset_database;
use Mojo::Base 'Mojolicious::Command';

sub run {
    my $self = shift;
    $self->app->pg->migrations->migrate(0)->migrate;
}

1;