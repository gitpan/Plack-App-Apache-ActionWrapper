#!/usr/bin/perl

# ABSTRACT: Wrapper for Apache2 Action directive for running PSGI apps on shared hosting with FastCGI

package Plack::App::Apache::ActionWrapper;
our $VERSION = '0.02';
use strict;
use warnings;
use base 'Plack::Component';




sub call {
    my ($self, $env) = @_;
    my $app_filename = $self->_resolve_app_filename($env);
    my $app = $self->_get_app($app_filename);
    $app ||= sub {
        my ( $my_env ) = shift;
        return [
            500,
            [ 'Content-Type' => 'text/plain' ],
            [
              "No .psgi file found in PATH_TRANSLATED.\n",
              "You probably forgot to add the following lines to .htaccess:\n",
              "    Action psgi-handler /path/to/psgi.fcgi\n",
              "    AddHandler psgi-handler .psgi\n",
              $self->_get_debug_info($my_env),
            ],
        ];
    };
    return $app->($env);
}


sub enable_debug {
    my ($self) = @_;
    $self->{'debug'} = 1;
    return $self;
}


sub disable_debug {
    my ($self) = @_;
    delete $self->{'debug'};
    return $self;
}


sub is_debug_enabled {
    my ($self) = @_;
    return $self->{'debug'} ? 1 : 0;
}

sub _resolve_app_filename {
    my ($self, $env) = @_;

    my $path_translated = $env->{'PATH_TRANSLATED'} || "";

    # Figure out which part of the path is actually the psgi file
    my @path_parts = split(m{/}, $path_translated);
    while ( ! -r join("/", @path_parts) ) {
        last if @path_parts == 0; # Break out if we're at the end
        pop @path_parts;
    }

    # Return undef (that is, no app) if no path part was a readable file
    return if @path_parts == 0;

    # Execute the contents of the file and return last variable defined in it
    my $psgi_file = join("/", @path_parts );

    # Cache the app to allow persistent running
    return $psgi_file;
}

sub _get_app {
    my ($self, $app_filename) = @_;
    # No string specified, cannot possibly be any app available
    return unless $app_filename;

    # Initialize code/mtime cache if they are not present
    $self->{'code_cache'} = {} unless exists $self->{'code_cache'};
    $self->{'mtime_cache'} = {} unless exists $self->{'mtime_cache'};

    # Fetch current mtime for $app_filename, for checking if it has been changed
    my $mtime_current = (stat($app_filename))[9];

    # App has never been loaded, do initial loading
    unless ( $self->{'code_cache'}->{$app_filename} ) {
        $self->{'code_cache'}->{$app_filename} = do $app_filename;
        $self->{'mtime_cache'}->{$app_filename} = $mtime_current;
    }

    # App on disk is newer than cached version, reload
    if ( $mtime_current > $self->{'mtime_cache'}->{$app_filename} ) {
        $self->{'code_cache'}->{$app_filename} = do $app_filename;
        $self->{'mtime_cache'}->{$app_filename} = $mtime_current;
    }

    # Return cached app
    return $self->{'code_cache'}->{$app_filename};        
}

sub _get_debug_info {
    my ($self, $env) = @_;

    # Don't return debug info unless it has been enabled
    return unless $self->is_debug_enabled();

    my @body = ( "\n", "Debug:\n" );

    # Real and effective UID
    push @body, "UID: " . $< . "\n"; # $UID
    push @body, "EUID: " . $> . "\n"; # $EUID

    # Environment variables
    foreach my $key ( sort keys %{ $env } ) {
        push @body, $key . ' = ' . $env->{$key} . "\n";
    }

    # Returned collected data
    return @body;
}

1;

__END__
=pod

=head1 NAME

Plack::App::Apache::ActionWrapper - Wrapper for Apache2 Action directive for running PSGI apps on shared hosting with FastCGI

=head1 VERSION

version 0.02

=head1 SYNOPSIS

    ------------- .htaccess -----------------
    AddHandler fcgi-script .fcgi
    Action psgi-script /cgi-bin/psgi.fcgi
    AddHandler psgi-script .psgi

    DirectoryIndex index.psgi

    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.psgi/$1 [QSA,L]

    ------------- psgi.fcgi -----------------
    #!/usr/bin/env perl

    use strict;
    use warnings;

    # Change this line if you use local::lib or need
    # specific libraries loaded for your application
    use lib '/home/robin/perl5/lib/perl5';

    use Plack::App::Apache::ActionWrapper;
    my $app = Plack::App::Apache::ActionWrapper->new->enable_debug->to_app;

    # Run the actual app
    use Plack::Server::FCGI;
    Plack::Server::FCGI->new->run($app);

    1;

    ------------- index.psgi -----------------
    #!/usr/bin/env plackup

    use strict;
    use warnings;

    my $app = sub {
        my $env = shift;
        return [
            200,
            [ 'Content-Type' => 'text/plain' ],
            [
                "This is the index.\n",
                'PATH_INFO=' . $env->{'PATH_INFO'} . "\n",
                'PATH_TRANSLATED=' . $env->{'PATH_TRANSLATED'} . "\n",
            ],
        ];
    };

=head1 DESCRIPTION

The PSGI web application specification is awesome. Plack is awesome aswell.
Running PSGI apps using plackup in development is super easy.

But what do you do when you want to deploy your PSGI app on shared hosting?
You can deploy it using traditional CGI, but if you're dealing with
something like Moose or Catalyst-based apps it's bound to be slow.

So your shared hosting provider has provided you with FastCGI support to
mitigate that problem. But because FastCGIExternalServer cannot be defined
in .htaccess you can only run dynamic FastCGI applications.

Your immediate reaction is to define C<AddHandler fcgi-script .psgi> in your
.htaccess and use plackup on the shebang line to run your PSGI app. But that
doesn't work if you use local::lib, because @INC is not setup properly.

By using a wrapper as specified in the synopsis you can avoid having to type
in C<use lib 'XXX'> in every one of your .psgi files. Another benefit is
that you can preload modules to benefit from copy-on-write on operating
systems that provide it to diminish the memory usage.

=head1 METHODS

=head2 call

The main handler that will be returned by the C<to_app> method inherited from L<Plack::Component>.

=head2 enable_debug

Mutator to enable debug output if no path was found in PATH_TRANSLATED. Allows chaining.

=head2 disable_debug

Mutator to disable debug output if no path was found in PATH_TRANSLATED. Allows chaining.

=head2 is_debug_enabled

Accessor to determine if debug is enabled or not. Debug is disabled by default.

=encoding utf8

=head1 AUTHOR

  Robin Smidsrød <robin@smidsrod.no>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Robin Smidsrød.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
