package Module::CoreList::DBSchema;

#ABSTRACT: A database schema for Module::CoreList

use strict;
use warnings;
use Clone qw[clone];
use Module::CoreList;
use SQL::Abstract;

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

my $queries = {
  corelist => [ 'select cl_perls.perl_ver, mod_vers, released, deprecated from cl_versions,cl_perls where cl_perls.perl_ver = cl_versions.perl_ver and mod_name = ? order by cl_versions.perl_ver', 1 ],
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
  my $clone = clone( $tables );
  return %{ $clone } if wantarray;
  return $clone;
}

sub data {
  my $self = shift;
  my %opts = @_;
  $opts{lc $_} = delete $opts{$_} for keys %opts;
  my $prefix = $opts{prefix} || '';
  my $data = [];
  foreach my $perl ( keys %Module::CoreList::version ) {
    push @{ $data }, [ $sql->insert( $prefix . 'cl_perls', [ $perl, $Module::CoreList::released{$perl} ] ) ];
    foreach my $mod ( keys %{ $Module::CoreList::version{ $perl } } ) {
      my $modver = $Module::CoreList::version{ $perl }{ $mod };
      $modver = '' unless $modver;
      my $deprecated = $Module::CoreList::deprecated{ $perl }{ $mod } || 0;
      push @{ $data }, [
        $sql->insert( $prefix . 'cl_versions', [ $perl, $mod, $modver, $deprecated ] )
      ];
    }
  }
  foreach my $family ( keys %Module::CoreList::families ) {
    push @{ $data }, [
      $sql->insert( $prefix . 'cl_families', [ $_, $family ] )
    ] for @{ $Module::CoreList::families{ $family } };
  }
  foreach my $mod ( keys %Module::CoreList::upstream ) {
    push @{ $data }, [
      $sql->insert( $prefix . 'cl_upstream', [ $mod, ( $Module::CoreList::upstream{ $mod } || '' ) ] )
    ];
  }
  foreach my $mod ( keys %Module::CoreList::bug_tracker ) {
    push @{ $data }, [
      $sql->insert( $prefix . 'cl_bugtracker', [ $mod, ( $Module::CoreList::bug_tracker{ $mod } || '' ) ] )
    ];
  }
  return @{ $data } if wantarray;
  return $data;
}

sub queries {
  return keys %{ $queries };
}

sub query {
  my $self = shift;
  my $query = shift || return;
  return unless exists $queries->{ $query };
  my $sql = $queries->{ $query };
  return @{ $sql } if wantarray;
  return $sql;
}

q[Modules are our business];

=pod

=head1 SYNOPSIS

  # this requires DBI and DBD::SQLite which are available from CPAN

  use strict;
  use warnings;
  use DBI;
  use Module::CoreList::DBSchema;

  $|=1;

  my $dbh = DBI->connect('dbi:SQLite:dbname=corelist.db','','') or die $DBI::errstr;
  $dbh->do(qq{PRAGMA synchronous = OFF}) or die $dbh->errstr;

  my $mcdbs = Module::CoreList::DBSchema->new();

  # create tables

  my %tables = $mcdbs->tables();

  print "Creating tables ... ";

  foreach my $table ( keys %tables ) {
    my $sql = 'CREATE TABLE IF NOT EXISTS ' . $table . ' ( ';
    $sql .= join ', ', @{ $tables{$table} };
    $sql .= ' )';
    $dbh->do($sql) or die $dbh->errstr;
    $dbh->do('DELETE FROM ' . $table) or die $dbh->errstr;
  }

  print "DONE\n";

  # populate with data

  my @data = $mcdbs->data();

  print "Populating tables ... ";

  $dbh->begin_work;

  foreach my $row ( @data ) {
    my $sql = shift @{ $row };
    my $sth = $dbh->prepare_cached($sql) or die $dbh->errstr;
    $sth->execute( @{ $row } ) or die $dbh->errstr;
  }

  $dbh->commit;

  print "DONE\n";

  # done

=head1 DESCRIPTION

Module::CoreList::DBSchema provides methods for building a database from the
information that is provided by L<Module::CoreList>.

=head1 CONSTRUCTOR

=over

=item C<new>

Creates a new Module::CoreList::DBSchema object.

  my $mcdbs = Module::CoreList::DBSchema->new();

=back

=head1 METHODS

=over

=item C<tables>

In a scalar context returns a hashref data structure keyed on table name.

In a list context returns a list of the same data structure.

  my %tables = $mcdbs->tables();

  foreach my $table ( keys %tables ) {
    my $sql = 'CREATE TABLE IF NOT EXISTS ' . $table . ' ( ';
    $sql .= join ', ', @{ $tables{$table} };
    $sql .= ' )';
    $dbh->do($sql) or die $dbh->errstr;
    $dbh->do('DELETE FROM ' . $table) or die $dbh->errstr;
  }

=item C<data>

In a list context returns a list of arrayrefs which contain a SQL statement
as the first element and the remaining elements being bind values for the SQL
statement.

In a scalar context returns an arrayref which contains the above arrayrefs.

  my @data = $mcdbs->data();

  foreach my $row ( @data ) {
    my $sql = shift @{ $row };
    my $sth = $dbh->prepare_cached($sql) or die $dbh->errstr;
    $sth->execute( @{ $row } ) or die $dbh->errstr;
  }

You may provide some optional arguments:

  prefix, a string to prefix to the table names in the resultant SQL;

=item C<queries>

Returns a list of the available SQL queries.

  my @queries = $mcdbs->queries();

=item C<query>

Takes one argument, the name of a query to lookup.

Returns in list context a list consisting of a SQL string and a flag indicating whether the
SQL string includes placeholders.

In scalar context returns an array reference containing the same as above.

  my $sql = $mcdbs->query('corelist');

=back

=head1 SEE ALSO

L<Module::CoreList>

L<DBI>

=cut
