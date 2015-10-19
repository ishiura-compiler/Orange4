package Orange4::Mini::For;

use strict;
use warnings;
use Carp ();

use Orange4::Mini::Backup;
use Orange4::Mini::Util;
use Orange4::Mini::Compute;

sub new {
  my ( $class, $config, $vars, $assigns, %args ) = @_;

  bless {
    config       => $config,
    vars         => $vars,
    assigns      => $assigns,
    run          => $args{run},
    status       => $args{status},
    backup       => Orange4::Mini::Backup->new( $vars, $assigns ),
    minimize_var => undef,
    %args,
  }, $class;
}

sub _generate_and_test {
  my $self = shift;
  
  return Orange4::Mini::Compute->new(
    $self->{config}, $self->{vars}, $self->{assigns},
    run    => $self->{run},
    status => $self->{status},
  )->_generate_and_test;
}

sub _print {
  my ( $self, $body ) = @_;
  Orange4::Mini::Util::print( $self->{status}->{debug}, $body );
}

1;

1;