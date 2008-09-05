package Search::QueryParser::SQL::Query;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );

use overload '""' => 'stringify';

our $VERSION = '0.001';

=head1 NAME

Search::QueryParser::SQL::Query - query object

=head1 SYNOPSIS

 # see Search::QueryParser::SQL

=head1 DESCRIPTION

This class is primarily for unparsing Search::QueryParser
data structures into valid SQL.
 
=head1 METHODS

Only new or overridden method are documented here.

=cut

=head2 stringify

Returns Query as a string suitable for plugging into a WHERE
clause.

=cut

sub stringify {
    my $self = shift;

    #dump $self;
    return $self->_unwind;
}

my %op_map = (
    '+' => 'AND',
    ''  => 'OR',
    '-' => 'AND',    # operator is munged
);

sub _unwind {
    my $self = shift;
    my $q = shift || $self;
    my @subQ;
    for my $prefix ( '+', '', '-' ) {
        my @clause;
        my $joiner = $op_map{$prefix};
        for my $subq ( @{ $q->{$prefix} } ) {
            push @clause, $self->_unwind_subQ( $subq, $prefix );
        }
        next if !@clause;

        #warn "$joiner clause: " . dump \@clause;

        push( @subQ,
            join( " $joiner ", grep { defined && length } @clause ) );
    }
    return join " AND ", @subQ;
}

sub _unwind_subQ {
    my $self   = shift;
    my $subQ   = shift;
    my $prefix = shift;
    return "(" . $self->_unwind( $subQ->{value} ) . ")"
        if $subQ->{op} eq '()';

    #my $quote = $subQ->{quote} || "";

    # whether we quote depends on the field (column) type
    my $quote = $self->{_parser}->{_is_int}->{ $subQ->{field} } ? "" : "'";

    # normalize operator
    my $op = $subQ->{op};
    if ( $op eq ':' ) {
        $op = '=';
    }
    if ( $prefix eq '-' ) {
        $op = '!' . $op;
    }

    # optional
    my $col_quote = $self->{_parser}->{quote_columns};

    # make sure we have a column
    my @columns
        = $subQ->{field}
        ? ( $subQ->{field} )
        : ( @{ $self->{_parser}->{default_column} } );
    my @buf;
    for my $column (@columns) {
        push(
            @buf,
            join( '',
                $col_quote, $column,        $col_quote, $op,
                $quote,     $subQ->{value}, $quote )
        );

    }
    return '(' . join( ' OR ', @buf ) . ')';
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


