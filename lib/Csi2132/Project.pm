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
  $self->helper(pg => sub { state $pg = Mojo::Pg->new(shift->config('pg')) });

  # Migrate to latest version if necessary
  my $path = $self->home->child('migrations', 'project.sql');
  $self->pg->auto_migrate(1)->migrations->name('project')->from_file($path);

  # Router
  my $r = $self->routes;
  $r->namespaces(['Csi2132::Project::Controller']);

  # Normal route to controller
  $r->get('/')->to('example#welcome');
}

1;
