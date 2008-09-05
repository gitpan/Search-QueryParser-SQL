package Search::QueryParser::SQL;

use warnings;
use strict;
use Carp;
use base qw( Search::QueryParser );

#use Data::Dump qw( dump );

use Search::QueryParser::SQL::Query;
use Scalar::Util qw( blessed );

our $VERSION = '0.001';

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

The values are used for determining correct quoting in strings.
If passed as an array ref, all column arguments will be quoted
(treated like strings).

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

=back

=cut

sub new {
    my $self = shift->SUPER::new(@_);
    my $args = ref $_[0] eq 'HASH' ? $_[0] : {@_};
    $self->{columns} = delete $args->{columns} or croak "columns required";
    my $reftype = ref( $self->{columns} );
    if ( !$reftype or ( $reftype ne 'ARRAY' and $reftype ne 'HASH' ) ) {
        croak "columns must be an ARRAY or HASH ref";
    }

    # TODO other sanity checks?
    if ( $reftype eq 'ARRAY' ) {
        for my $col ( @{ $self->{columns} } ) {
            $self->{_is_int}->{$col} = 0;
        }
    }
    else {
        for my $col ( keys %{ $self->{columns} } ) {
            $self->{_is_int}->{$col} = 1
                if (
                $self->{columns}->{$col} =~ m/int|float|bool|time|date/ );
        }
    }

    $self->{default_column} = delete $args->{default_column}
        || (
          $reftype eq 'ARRAY'
        ? $self->{columns}
        : [ keys %{ $self->{columns} } ]
        );

    if ( !ref( $self->{default_column} ) ) {
        $self->{default_column} = [ $self->{default_column} ];
    }

    $self->{quote_columns} = delete $args->{quote_columns} || '';

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

    $query->{_parser} = $self;

    #dump $query;
    return bless( $query, 'Search::QueryParser::SQL::Query' );
}

=head2 unparse( I<query> )

Same as calling $query->stringify.

=cut

sub unparse {
    my $self = shift;
    my $query = shift or croak "query required";
    unless ( blessed($query)
        and $query->isa('Search::QueryParser::SQL::Query') )
    {
        croak "query is not a blessed Search::QueryParser::SQL::Query object";
    }

    return $query->stringify;
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

