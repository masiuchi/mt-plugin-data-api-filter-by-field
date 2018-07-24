package MT::Plugin::DataAPIFilterByField::Callback;
use strict;
use warnings;

use MT;
use MT::Meta;

sub list_permission_filter {
    my ( $cb, $app, $terms, $args, $opt ) = @_;

    my $search = $app->param('search');
    return 1 unless defined $search && $search ne '';

    my @search_fields = split ',', $app->param('searchFields');
    my @search_custom_fields = grep {/^field\./} @search_fields;
    return 1 unless @search_custom_fields;

    my $new_search_fields = join ',',
        grep { $_ !~ /^field\./ } @search_fields;
    $app->param( 'searchFields', $new_search_fields );
    $app->param( 'search',       '' )
        unless defined $new_search_fields && $new_search_fields ne '';

    my $request = {
        search               => $search,
        search_custom_fields => \@search_custom_fields,
    };
    $app->request( 'data_api_filter_by_field', $request );

    1;
}

sub pre_load_filtered_list {
    my ( $cb, $app, $filter, $opt, $cols ) = @_;

    my $request = $app->request('data_api_filter_by_field');
    return unless $request;
    my $search               = $request->{search};
    my $search_custom_fields = $request->{search_custom_fields};

    my $ds    = $filter->object_ds;
    my $class = MT->model($ds);

    my @join_terms;
    for my $field (@$search_custom_fields) {
        my $meta_type = MT::Meta->metadata_by_name( $class, $field );
        push @join_terms,
            {
            type               => $field,
            $meta_type->{type} => $search,
            };
        push @join_terms, '-or';
    }
    pop @join_terms;

    push @{ $opt->{args}{joins} ||= [] },
        [
        $class->meta_pkg, undef,
        [ { "${ds}_id" => \"= ${ds}_id" }, \@join_terms ],
        ];

    $opt->{args}{unique} = 1;
}

1;

