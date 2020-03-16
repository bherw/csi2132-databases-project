package Csi2132::Project::Command::migrate_database;
use Mojo::Base 'Mojolicious::Command', -signatures;

sub run($self) {
    print "Migrating...";
    $self->app->pg->migrations->migrate;
    print " done.\n";
}

1;
