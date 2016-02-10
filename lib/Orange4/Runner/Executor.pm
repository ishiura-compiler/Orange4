package Orange4::Runner::Executor;

use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;
    
    bless {
        error     => [],
        error_msg => "",
        command   => "",
        %args,
    }, $class;
}

sub run {
    my $self = shift;
    eval {
	local $SIG{ALRM} = sub { die "timeout" };
	alarm 2;   #If you wanna set timeout, change here. (default 2sec)
	( $self->{error_msg}, $self->{error}, $self->{command} ) =
	    $self->{execute}->( $self->{config} );
	alarm 0;
    };
    alarm 0;
    if($@) {
	if($@ =~ /timeout/) {
	    push @{$self->{error}}, "timeout";
	    $self->{error_msg} = "timeout";
	    print "\@NG\@(timeout)\n";
	}
	else {
	}
    }
}

sub error     { @{ shift->{error} }; }
sub error_msg { shift->{error_msg}; }
sub command   { shift->{command}; }

1;
