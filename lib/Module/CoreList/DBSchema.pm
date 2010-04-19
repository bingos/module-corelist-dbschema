package Module::CoreList::DBSchema;

use strict;
use warnings;
use Module::CoreList;
use SQL::Abstract;
use vars qw[$VERSION];

$VERSION = '0.02';

my $tables = {
   cl_perls => [
      'perl_ver VARCHAR(20) NOT NULL',
      'released VARCHAR(10)',
    ],
    cl_versions => [
      'perl_ver VARCHAR(20) NOT NULL',
      'mod_name VARCHAR(300) NOT NULL',
      'mod_vers VARCHAR(30)',
      'deprecated BOOL',
    ],
    cl_families => [
      'perl_ver VARCHAR(20) NOT NULL',
      'family VARCHAR(20) NOT NULL',
    ],
    cl_upstream => [
      'mod_name VARCHAR(300) NOT NULL',
      'upstream VARCHAR(20)',
    ],
    cl_bugtracker => [
      'mod_name VARCHAR(300) NOT NULL',
      'url TEXT',
    ],
};

my $sql = SQL::Abstract->new();

sub new {
  my $package = shift;
  my %opts = @_;
  $opts{lc $_} = delete $opts{$_} for keys %opts;
  my $self = bless \%opts, $package;
  return $self;
}

sub tables {
  return %{ $tables };
}

sub data {
  my $self = shift;
  my $data = [];
  foreach my $perl ( keys %Module::CoreList::version ) {
    push @{ $data }, [ $sql->insert( 'cl_perls', [ $perl, $Module::CoreList::released{$perl} ] ) ];
    foreach my $mod ( keys %{ $Module::CoreList::version{ $perl } } ) {
      my $modver = $Module::CoreList::version{ $perl }{ $mod };
      $modver = '' unless $modver;
      my $deprecated = $Module::CoreList::deprecated{ $perl }{ $mod } || 0;
      push @{ $data }, [
        $sql->insert( 'cl_versions', [ $perl, $mod, $modver, $deprecated ] )
      ];
    }
  }
  foreach my $family ( keys %Module::CoreList::families ) {
    push @{ $data }, [
      $sql->insert( 'cl_families', [ $_, $family ] )
    ] for @{ $Module::CoreList::families{ $family } };
  }
  foreach my $mod ( keys %Module::CoreList::upstream ) {
    push @{ $data }, [
      $sql->insert( 'cl_upstream', [ $mod, ( $Module::CoreList::upstream{ $mod } || '' ) ] )
    ];
  }
  foreach my $mod ( keys %Module::CoreList::bug_tracker ) {
    push @{ $data }, [
      $sql->insert( 'cl_bugtracker', [ $mod, ( $Module::CoreList::bug_tracker{ $mod } || '' ) ] )
    ];
  }
  return $data;
}

q[Modules are our business];

__END__
