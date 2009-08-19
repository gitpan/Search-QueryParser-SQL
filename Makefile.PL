use strict;
use warnings;

use inc::Module::Install;

# Define metadata
name 'Search-QueryParser-SQL';
all_from 'lib/Search/QueryParser/SQL.pm';

requires 'Test::More'          => 0;
requires 'Search::QueryParser' => '0.93';
requires 'Scalar::Util'        => 0;
requires 'Data::Dump'          => 0; # just for devel
requires 'Class::Accessor::Fast' => 0;

WriteAll;
