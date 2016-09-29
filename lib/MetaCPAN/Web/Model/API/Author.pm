package MetaCPAN::Web::Model::API::Author;

use Moose;
use namespace::autoclean;

extends 'MetaCPAN::Web::Model::API';

=head1 NAME

MetaCPAN::Web::Model::Author - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Matthew Phillips

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub get {
    my ( $self, @author ) = @_;

    return $self->request( '/author/' . uc( $author[0] ) )
        if ( @author == 1 );

    return $self->request(
        '/author/_search',
        {
            query => {
                constant_score => {
                    filter => { ids => { values => [ map {uc} @author ] } }
                }
            },
            size => scalar @author,
        }
    );

}

sub search {
    my ( $self, $query, $from ) = @_;

    my $cv     = $self->cv;
    my $search = {
        query => {
            bool => {
                should => [
                    {
                        match => {
                            'name.analyzed' =>
                                { query => $query, operator => 'and' }
                        }
                    },
                    {
                        match => {
                            'asciiname.analyzed' =>
                                { query => $query, operator => 'and' }
                        }
                    },
                    { match => { 'pauseid'    => uc($query) } },
                    { match => { 'profile.id' => lc($query) } },
                ]
            }
        },
        size => 10,
        from => $from || 0,
    };

    $self->request( '/author/_search', $search )->cb(
        sub {
            my $results = shift->recv
                || { hits => { total => 0, hits => [] } };
            $cv->send(
                {
                    results => [
                        map { +{ %{ $_->{_source} }, id => $_->{_id} } }
                            @{ $results->{hits}{hits} }
                    ],
                    total => $results->{hits}{total} || 0,
                    took => $results->{took}
                }
            );
        }
    );
    return $cv;
}

sub by_user {
    my ( $self, $users ) = @_;
    return $self->request(
        '/author/by_user?fields=user,pauseid&users=' . join ',',
        @{$users} );
}

__PACKAGE__->meta->make_immutable;

1;
