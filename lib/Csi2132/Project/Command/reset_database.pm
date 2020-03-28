package Csi2132::Project::Command::reset_database;
use Mojo::Base 'Mojolicious::Command', -signatures;

sub run($self) {
    $self->app->pg->migrations->migrate(0)->migrate;
}

1;