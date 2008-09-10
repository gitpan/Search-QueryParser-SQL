package Search::QueryParser::SQL;

use warnings;
use strict;
use Carp;
use base qw( Search::QueryParser );

#use Data::Dump qw( dump );

use Search::QueryParser::SQL::Query;
use Scalar::Util qw( blessed );

our $VERSION = '0.004';

=head1 NAME

Search::QueryParser::SQL - turn free-text queries into SQL WHERE clauses

=head1 SYNOPSIS

 use Search::QueryParser::SQL;
 my $parser = Search::QueryParser::SQL->new(
            columns => [qw( first_name last_name email )]
        );
        
 my $query = $parser->parse('joe smith', 1); # 1 for explicit AND
 print $query;
 # prints:
 # (first_name='joe' OR last_name='joe' OR email='joe') AND \
 # (first_name='smith' OR last_name='smith' OR email='smith')
 
 # for the DBI
 my $query = $parser->parse('foo');
 print $query->dbi->[0];
 # prints
 # (first_name=? OR last_name=? OR email=?)
 
 # wildcard support
 my $query = $parser->parse('foo*');
 print $query;
 # prints
 # (first_name ILIKE 'foo%' OR last_name ILIKE 'foo%' OR email ILIKE 'foo%')


=head1 DESCRIPTION

Search::QueryParser::SQL is a subclass of Search::QueryParser.
Chiefly it extends the unparse() method to stringify free-text
search queries as valid SQL WHERE clauses.

The idea is to allow you to treat your database like a free-text
search index, when it really isn't.
 
=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 new( I<args> )

Returns a new Parser. In addition to the I<args> documented
in Search::QueryParser, this new() method supports additional
I<args>:

=over

=item columns

B<Required>

May be a hash or array ref of column names. If a hash ref,
the keys should be column names and the values the column type
(e.g., int, varchar, etc.).

The values are used for determining correct quoting in strings
and for operator selection with wildcards.
If passed as an array ref, all column arguments will be 
treated like 'char'.

=item default_column

B<Optional>

The column name or names to be used when no explicit column name is
used in a query string. If not present, defaults to I<columns>.


=item quote_columns

B<Optional>

The default behaviour is to not quote column names, but some SQL
dialects expect column names to be quoted (escaped).

Set this arg to a quote value. Example:

 my $parser = Search::QueryParser::SQL->new(
            columns         => [qw( foo bar )],
            quote_columns   => '`'
            );
 # query will look like `foo` and `bar`

=item fuzzify

I<Optional>

Treat all query keywords as if they had wildcards attached to the end.
E.g., C<foo> would be treated like C<foo*>.

=item strict

I<Optional>

Croak if any of the column names in I<string> are not among the supplied
column names in I<columns>.

=item like

I<Optional>

The SQL operator to use for wildcard query strings. The default is
C<ILIKE>.

=back

=cut

sub new {
    my $self = shift->SUPER::new(
        @_,

        # add the dot for table.column
        'rxField' => qr/[\.\w]+/,

        # make and/or/not case insensitive
        'rxAnd' => qr/AND|ET|UND|E/i,
        'rxOr'  => qr/OR|OU|ODER|O/i,
        'rxNot' => qr/NOT|PAS|NICHT|NON/i,
    );
    my $args = ref $_[0] eq 'HASH' ? $_[0] : {@_};
    $self->{columns} = delete $args->{columns} or croak "columns required";
    my $reftype = ref( $self->{columns} );
    if ( !$reftype or ( $reftype ne 'ARRAY' and $reftype ne 'HASH' ) ) {
        croak "columns must be an ARRAY or HASH ref";
    }

    # TODO other sanity checks?

    # store columns as HASH
    if ( $reftype eq 'ARRAY' ) {
        $self->{columns} = { map { $_ => 'char' } @{ $self->{columns} } };
    }

    for my $col ( keys %{ $self->{columns} } ) {
        $self->{_is_int}->{$col} = 1
            if ( $self->{columns}->{$col} =~ m/int|float|bool|time|date/ );
    }

    $self->{default_column} = delete $args->{default_column}
        || [ sort keys %{ $self->{columns} } ];

    if ( !ref( $self->{default_column} ) ) {
        $self->{default_column} = [ $self->{default_column} ];
    }

    $self->{quote_columns} = delete $args->{quote_columns} || '';
    $self->{fuzzify}       = delete $args->{fuzzify}       || 0;
    $self->{strict}        = delete $args->{strict}        || 0;
    $self->{like}          = delete $args->{like}          || 'ILIKE';

    #dump $self;

    return $self;
}

=head2 parse( I<string> )

Acts like parse() method in Search::QueryParser, but
returns a Search::QueryParser::SQL::Query object.

=cut

sub parse {
    my $self  = shift;
    my $query = $self->SUPER::parse(@_)
        or croak "query parse failed: " . $self->err;

    if ( $self->{strict} ) {
        for my $key ( keys %$query ) {
            next unless defined $query->{$key};
            for my $subq ( @{ $query->{$key} } ) {
                next unless $subq->{field};
                unless ( exists $self->{columns}->{ $subq->{field} } ) {
                    croak "invalid column name: $subq->{field}";
                }
            }
        }
    }

    $query->{_parser}       = $self;
    $query->{_string}       = $_[0];
    $query->{_implicit_AND} = $_[1] || 0;

    #dump $query;
    return bless( $query, 'Search::QueryParser::SQL::Query' );
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-search-queryparser-sql@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically be
notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

The Minnesota Supercomputing Institute C<< http://www.msi.umn.edu/ >>
sponsored the development of this software.

=head1 COPYRIGHT & LICENSE

Copyright 2008 by the Regents of the University of Minnesota.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

