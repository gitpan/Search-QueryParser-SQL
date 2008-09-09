use Test::More tests => 25;

use_ok('Search::QueryParser::SQL');

ok( my $parser = Search::QueryParser::SQL->new(
        columns        => [qw( foo color name )],
        default_column => 'name'
    ),
    "new parser"
);

ok( my $query1 = $parser->parse('foo=bar'), "query1" );
cmp_ok( $query1->dbi->[0], 'eq', "foo=?", "query1 string" );
is_deeply( $query1->dbi->[1], ['bar'], "query1 values" );

ok( my $query2 = $parser->parse('foo:bar'), "query2" );
cmp_ok( $query2->dbi->[0], 'eq', "foo=?", "query2 string" );
is_deeply( $query2->dbi->[1], ['bar'], "query2 values" );

ok( my $query3 = $parser->parse( 'foo bar', 1 ), "query3" );
cmp_ok( $query3->dbi->[0], 'eq', "name=? AND name=?", "query3 string" );
is_deeply( $query3->dbi->[1], [ 'foo', 'bar' ], "query3 values" );

ok( my $query4 = $parser->parse('-color:red (name:john OR foo:bar)'),
    "query4" );
cmp_ok(
    $query4->dbi->[0], 'eq',
    "(name=? OR foo=?) AND color!=?",
    "query4 string"
);
is_deeply( $query4->dbi->[1], [ 'john', 'bar', 'red' ], "query4 values" );

ok( my $parser2 = Search::QueryParser::SQL->new(
        columns => [qw( first_name last_name email )],
    ),
    "parser2"
);

ok( my $query5 = $parser2->parse("joe smith"), "query5" );
cmp_ok(
    $query5->dbi->[0],
    'eq',
    "(email=? OR first_name=? OR last_name=?) OR (email=? OR first_name=? OR last_name=?)",
    "query5 string"
);
is_deeply(
    $query5->dbi->[1],
    [ 'joe', 'joe', 'joe', 'smith', 'smith', 'smith' ],
    "query5 values"
);

ok( my $query6 = $parser2->parse('"joe smith"'), "query6" );
cmp_ok(
    $query6->dbi->[0], 'eq',
    "(email=? OR first_name=? OR last_name=?)",
    "query6 string"
);
is_deeply(
    $query6->dbi->[1],
    [ 'joe smith', 'joe smith', 'joe smith' ],
    "query6 values"
);

ok( my $parser3 = Search::QueryParser::SQL->new(
        columns       => [qw( foo bar )],
        quote_columns => '`',
    ),
    "parser3"
);

ok( my $query7 = $parser3->parse('green'), "query7" );
cmp_ok( $query7->dbi->[0], 'eq', "(`bar`=? OR `foo`=?)", "query7 string" );
is_deeply( $query7->dbi->[1], [ 'green', 'green' ], "query7 values" );
