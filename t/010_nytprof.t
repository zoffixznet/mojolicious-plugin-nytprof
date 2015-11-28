#!perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Mojo;

use File::Spec::Functions 'catfile';
use FindBin '$Bin';
use File::Path qw'rmtree';

use Mojolicious::Plugin::NYTProf;
Mojolicious::Plugin::NYTProf::_find_nytprofhtml()
	|| plan skip_all => "Couldn't find nytprofhtml in PATH or in same location as $^X";

my $prof_dir = catfile($Bin,"nytprof");

my @existing_profs = glob "$prof_dir/profiles/nytprof*";
unlink $_ for @existing_profs;
my @existing_runs = glob "$prof_dir/html/nytprof*";
rmtree($_) for @existing_runs;

{
  use Mojolicious::Lite;

  dies_ok(
    sub {
      plugin NYTProf => {
        nytprof => {
          nytprofhtml_path => '/tmp/bad'
        },
      };
    },
    'none existent nytprofhtml dies',
  );

  like( $@,qr/Could not find nytprofhtml script/i,' ... with sensible error' );

  plugin NYTProf => {
    nytprof => {
      profiles_dir => $prof_dir,
    },
  };

  any 'some_route' => sub {
    my ($self) = @_;
    $self->render(text => "basic stuff\n");
  };
}

my $t = Test::Mojo->new;

$t->get_ok('/nytprof')
  ->status_is(200)
  ->content_like(qr{<p>No profiles found</p>});

ok(
  !-e catfile($prof_dir,'profiles',"nytprof.out.some_route.$$"),
  'nytprof.out file not created'
);

$t->get_ok('/some_route')
  ->status_is(200)
  ->content_is("basic stuff\n") for 1 .. 3;

my @profiles =
  Mojolicious::Plugin::NYTProf::_profiles(catfile($prof_dir,'profiles'));

foreach my $prof (@profiles) {
  ok(-e catfile($prof_dir,'profiles',$prof->{file}), $prof->{file}." created");
}

$t->ua->max_redirects(5);

$t->get_ok('/nytprof')
  ->status_is(200)
  ->content_like(qr{<a href="/nytprof/profiles/nytprof_out_\d+_\d+_some_route_\d+">});

$t->get_ok("/nytprof/profiles/nytprof_out_111_111_some_route_111")
  ->status_is(404);

$t->get_ok($profiles[0]->{url})
  ->status_is(200);

my $content = $t->tx->res->content;
like( $content->asset->slurp,qr/This file was generated by Devel::NYTProf/ );

$t->get_ok("/".$profiles[0]->{file}.'/index.html')
  ->status_is(200);

$content = $t->tx->res->content;
like( $content->asset->slurp,qr/This file was generated by Devel::NYTProf/ );

done_testing();
