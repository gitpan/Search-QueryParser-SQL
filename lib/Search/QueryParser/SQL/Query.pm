package Search::QueryParser::SQL::Query;
use strict;
use warnings;
use Carp;
use Data::Dump qw( dump );

use overload '""' => 'stringify';

our $VERSION = '0.004';

my $debug = $ENV{PERL_DEBUG} || 0;

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
    return $self->_unwind;
}

my %op_map = (
    '+' => 'AND',
    ''  => 'OR',
    '-' => 'AND',    # operator is munged
);

=head2 dbi

Like stringify(), but returns array ref of two items:
the SQL string and an array ref of values. The SQL string
uses the C<?> placeholder as expected by the DBI API.

=cut

sub dbi {
    my $self = shift;

    # set flag temporarily
    $self->{opts}->{delims} = 1;

    my $sql = $self->_unwind;
    my @values;
    my $start   = chr(2);
    my $end     = chr(3);
    my $opstart = chr(5);
    my $opend   = chr(6);

    # do not need op delims at all
    $sql =~ s/($opstart|$opend)//go;

    while ( $sql =~ s/$start(.+?)$end/\?/o ) {
        push( @values, $1 );
    }

    delete $self->{opts}->{delims};

    return [ $sql, \@values ];
}

=head2 pairs

Returns array ref of array refs of column/op/value pairs.
Note that the logical AND/OR connectors will not be present.

=cut

sub pairs {
    my $self = shift;

    my @pairs;
    my $vstart  = chr(2);
    my $vend    = chr(3);
    my $opstart = chr(5);
    my $opend   = chr(6);
    my $like    = $self->{_parser}->{like};

    # set flag temporarily
    $self->{opts}->{delims} = 1;
    my $sql = $self->_unwind;

    while ( $sql =~ m/([\.\w]+)\ ?$opstart(.+?)$opend\ ?$vstart(.+?)$vend/go )
    {
        push( @pairs, [ $1, $2, $3 ] );
    }

    delete $self->{opts}->{delims};

    return \@pairs;
}

=head2 rdbo

Returns array ref ready for passing to Rose::DB::Object::Querybuilder
build_select() method as the C<query> argument.

=cut

sub rdbo {
    my $self = shift;

    $debug and warn '=' x 80 . "\n";
    $debug and warn "STRING: $self->{_string}\n";
    $debug and warn "PARSER: " . dump( $self->{_parser} ) . "\n";

    my $q = $self->_orm;

    $debug and warn "q: " . dump $q;

    if ( scalar @$q > 2 ) {
        return [ ( $self->{_implicit_AND} ? 'AND' : 'OR' ) => $q ];
    }
    else {
        return $q;
    }
}

=head2 parser

Returns the original parser object that generated the query.

=cut

sub parser {
    shift->{_parser};
}

sub _orm {
    my $self = shift;
    my $q = shift || $self;
    my $query;
    for my $prefix ( '+', '', '-' ) {
        next unless ( defined $q->{$prefix} and @{ $q->{$prefix} } );

        my $joiner = $op_map{$prefix};

        $debug and warn "prefix '$prefix' ($joiner): " . dump $q->{$prefix};

        my @op_subq;

        for my $subq ( @{ $q->{$prefix} } ) {
            my $q = $self->_orm_subq( $subq, $prefix );
            my $items = scalar(@$q);

            $debug and warn "items $items $joiner : " . dump $q;

            push( @op_subq, ( $items > 2 ) ? ( 'OR' => $q ) : @$q );
        }

        push( @$query,
            ( scalar(@op_subq) > 2 ) ? ( $joiner => \@op_subq ) : @op_subq );

    }
    return $query;
}

sub _orm_subq {
    my $self   = shift;
    my $subQ   = shift;
    my $prefix = shift;
    my $opts   = $self->{opts} || {};
    my $is_int = $self->{_parser}->{_is_int};
    my $like   = $self->{_parser}->{like};

    return $self->_orm( $subQ->{value} )
        if $subQ->{op} eq '()';

    # make sure we have a column
    my @columns
        = $subQ->{field}
        ? ( $subQ->{field} )
        : ( @{ $self->{_parser}->{default_column} } );

    # what value
    my $value = $subQ->{value};
    if ( $self->{_parser}->{fuzzify} ) {
        $value .= '*' unless $value =~ m/[\*\%]/;
    }

    # normalize wildcard to sql variety
    $value =~ s/\*/\%/g;

    # normalize operator
    my $op = $subQ->{op};
    if ( $op eq ':' ) {
        $op = '=';
    }
    if ( $prefix eq '-' ) {
        $op = '!' . $op;
    }
    if ( $value =~ m/\%/ )
    {    # TODO is this correct for all dbs? or $op =~ m/\~/) {
        $op = $like;
    }

    # TODO better operator selection

    my @buf;
    for my $column (@columns) {
        if ( $op eq '=' ) {
            push( @buf, $column => $value );
        }
        elsif ( $is_int->{$column} and $op eq $like ) {
            
            # if the value doesn't look like an int...??
            if ( $value =~ m/\D/ ) {
                next;
            }
            
            push( @buf, $column => { 'ge' => $value } );
        }
        else {
            push( @buf, $column => { $op => $value } );
        }
    }

    #warn "buf: " . dump \@buf;

    return \@buf;

}

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
    return join( " AND ", @subQ );
}

sub _unwind_subQ {
    my $self   = shift;
    my $subQ   = shift;
    my $prefix = shift;
    my $opts   = $self->{opts} || {};

    return "(" . $self->_unwind( $subQ->{value} ) . ")"
        if $subQ->{op} eq '()';

    #my $quote = $subQ->{quote} || "";

    # whether we quote depends on the field (column) type
    my $quote = $self->{_parser}->{_is_int}->{ $subQ->{field} } ? "" : "'";

    # optional
    my $col_quote = $self->{_parser}->{quote_columns};

    # make sure we have a column
    my @columns
        = $subQ->{field}
        ? ( $subQ->{field} )
        : ( @{ $self->{_parser}->{default_column} } );

    # what value
    my $value = $subQ->{value};
    if ( $self->{_parser}->{fuzzify} ) {
        $value .= '*' unless $value =~ m/[\*\%]/;
    }

    # normalize wildcard to sql variety
    $value =~ s/\*/\%/g;

    # normalize operator
    my $op = $subQ->{op};
    if ( $op eq ':' ) {
        $op = '=';
    }
    if ( $prefix eq '-' ) {
        $op = '!' . $op;
    }
    if ( $value =~ m/\%/ ) {
        $op = ' ' . $self->{_parser}->{like} . ' ';
    }

    # TODO better operator selection

    my @buf;
    for my $column (@columns) {
        if ( $opts->{delims} ) {
            push(
                @buf,
                join( '',
                    $col_quote, $column, $col_quote, chr(5), $op,
                    chr(6),     chr(2),  $value,     chr(3) )
            );
        }
        else {
            push(
                @buf,
                join( '',
                    $col_quote, $column, $col_quote, $op,
                    $quote,     $value,  $quote )
            );
        }
    }

    return
          ( scalar(@buf) > 1 ? '(' : '' )
        . join( ' OR ', @buf )
        . ( scalar(@buf) > 1 ? ')' : '' );

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


