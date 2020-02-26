package Csi2132::Project;
use Mojo::Base 'Mojolicious';
use Mojo::Pg;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Config
    my $config = $self->plugin('Config');
    $self->secrets($config->{secrets});

    # Model
    $self->helper(pg => sub {state $pg = Mojo::Pg->new(shift->config('pg'))});

    # Migrate to latest version if necessary
    my $path = $self->home->child('migrations', 'project.sql');
    $self->pg->auto_migrate(1)->migrations->name('project')->from_file($path);

    # Router
    my $r = $self->routes;
    $r->namespaces([ 'Csi2132::Project::Controller' ]);

    # Normal route to controller
    $r->get('/')->to('example#welcome');

    # Test Queries
    $r->get('/test')->to('test_queries#index');
    $r->get('/test/one')->to('test_queries#query_one');
    $r->get('/test/two')->to('test_queries#query_two');
    $r->get('/test/three')->to('test_queries#query_three');
    $r->get('/test/four')->to('test_queries#query_four');
    $r->get('/test/five')->to('test_queries#query_five');
    $r->get('/test/six')->to('test_queries#query_six');
    $r->get('/test/seven')->to('test_queries#query_seven');
    $r->get('/test/eight')->to('test_queries#query_eight');
    $r->get('/test/nine')->to('test_queries#query_nine');
    $r->get('/test/ten')->to('test_queries#query_ten');
}

1;
