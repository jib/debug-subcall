package Debug::SubCall;

use strict;
use warnings;

use Hook::LexWrap;
use Object::Accessor;
use Data::Dumper;
use Log::Message::Simple;
use Carp::Trace     qw[trace];
use Params::Check   qw[check];


use vars qw[$VERSION $DEBUG_FH $VERBOSE];

$VERSION = '0.01';
$VERBOSE = 1;

### alias the filehandles, so it's accesible thru our package
*DEBUG_FH = *Log::Message::Simple::DEBUG_FH;

sub as_string { return Log::Message::Simple->stack_as_string };
sub flush     { return Log::Message::Simple->flush }

BEGIN {
    use base 'Exporter';
    use vars qw[@EXPORT_OK];
    
    @EXPORT_OK = qw[report];
}    

sub report {
    my $name    = shift or return;
    my %hash    = @_;
 
    my $tmpl = {
        show_caller =>  { default => 0 },
        show_args   =>  { default => 0 },
        show_rv     =>  { default => 0 },
        show_stack  =>  { default => 0 },
        show_trace  =>  { default => 0 },
        package     =>  { default => '', no_override => 1 },
        sub         =>  { default => '', no_override => 1 },
    };        

    my $args = check( $tmpl, \%hash ) or return;
    
    ### create an object out of it
    my $obj = Object::Accessor->new;
    
    ### make the accessors
    $obj->mk_accessors( keys %$args );
    
    ### and set the values
    $obj->$_( $args->{$_} ) for keys %$args;
    
    my($pkg,$sub) = $name =~ /(?:(\w+)::)?(\w+)$/;
    
    $pkg ||= (caller)[0];
    
    $obj->package( $pkg );
    $obj->sub( $sub );
    
    my $fullname = join '::', $obj->package, $obj->sub;

    my $tmp = wrap $fullname, 
                pre  => sub {  
                            
        my $rv = pop();
        my $msg = "Called '$fullname'";
        
        ### add ' from package::sub [file:line]' if requested
        {   my @call = caller(1) ? caller(1) : caller(0);
        
            $msg .= " from $call[3] [$call[1]:$call[2]]"
                if $obj->show_caller;
        }
        
        ### add carp::trace
        {   $msg .= $/ . trace() if $obj->show_trace }

        ### add stack
        {   $msg .= $/ . 'Carp::longmess() output ' . Carp::longmess() 
                if $obj->show_stack }
        
        ### add args if requested
        {   local $Data::Dumper::Indent = 1;
            $msg .= $/ . Data::Dumper->Dump(\@_, ['ARGS']) if $obj->show_rv;
        }            

        debug( $_ , $VERBOSE ) for split $/, $msg;
    },                
                
                post => sub { 
        local $Data::Dumper::Indent = 1;
        my $msg = Data::Dumper->Dump( [$_[-1]], ['RV'] );
        
        if( $obj->show_rv ) {
            debug( $_ , $VERBOSE ) for split $/, $msg; 
        }
    };        

    return $tmp;
}

1;
