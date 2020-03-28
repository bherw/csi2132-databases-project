package Csi2132::Project::Command::migrate_database;
use Mojo::Base 'Mojolicious::Command', -signatures;

sub run($self) {
    $|++;
    print "Connecting...";
    my $pg = $self->app->pg;
    $pg->db;
    print "OK\n";
    print "Migrating...";
    $pg->migrations->migrate;
    print " done.\n";
}

1;
