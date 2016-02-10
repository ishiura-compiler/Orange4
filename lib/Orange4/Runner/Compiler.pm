package Orange4::Runner::Compiler;

use strict;
use warnings;

sub new {
    my ( $class, %args ) = @_;
    
    bless {
        error_msg => "",
        command   => "",
        %args,
    }, $class;
}

sub run {
    my $self = shift;
    
    system "rm -f $self->{config}->{exec_file} > /dev/null";
    eval {
	local $SIG{ALRM} = sub { die "timeout" };
	alarm 5;   #If you wanna set timeout of compile, change here. (default 5sec)
	( $self->{error_msg}, $self->{command} ) =
	    $self->{compile}->( $self->{config}, $self->{option} );
	alarm 0;
    };
    alarm 0;
    if($@) {
	if($@ =~ /timeout/) {
	    $self->{error_msg} = "Compile-timeout";
	    print "\@NG\@(Compile timeout) \n";
	}
	else {
	}
    }
}

sub error_msg { shift->{error_msg}; }
sub command   { shift->{command}; }

1;
