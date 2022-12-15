package Apiis::Form::WWWUtilities;
use strict;
use warnings;
use Apiis;

##############################################################################
#DEBUG
##############################################################################
sub SetDebug {
    my $debug = 7;    #debug information will be printed into debug file

=cut



 For debug messages special DBG_FILE is open. In web environmet sending of 
 debug messages to STDOUT is not very useful. Most of error/warning/info 
 messages are sent into APIIS log file in case when APIIS object is not 
 available (i.e.: in case of error during APIIS object creation) messages 
 are written to STDERR or DBG_FILE. 

=cut

    #mue add errorhandling
    if ($debug) { 
        open (DBG_FILE, ">>", "$ENV{'APIIS_HOME'}/tmp/www_debug" ); 
        
        print DBG_FILE "\n------------------------ start of request ------------------------";
        
        use POSIX qw(strftime);
        
        print DBG_FILE "\n" . strftime "%a %b %e %H:%M:%S %Y", localtime;

        close(DBG_FILE);
    }

    # default temp directory
    my $tmpdir = "$ENV{'APIIS_HOME'}/tmp/";

    return 0;
}
### DEBUG END

sub TestSystemForWWWAccess {

    #--- Test ob es Files gibt
    my $vapiis = $apiis->APIIS_HOME;
    if ( !-e $apiis->APIIS_HOME . "/tmp/sessiondata" ) {
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'OS',
                severity  => 'ERR',
                from      => 'GUI',
                msg_short => __( "Can't open [_1]/tmp/sessiondata", $vapiis ),
            )
        );
	goto ERR;
    }
    if ( ( -e $apiis->APIIS_HOME . "/tmp/sessiondata" ) and ( !-w $apiis->APIIS_HOME . "/tmp/sessiondata" ) ) {
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'OS',
                severity  => 'ERR',
                from      => 'GUI',
                msg_short => __( "Can't write [_1]/tmp/sessiondata", $vapiis ),
            )
        );
	goto ERR;
    }
    if ( !-e $apiis->APIIS_HOME . "/etc/apiis.css" ) {
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'OS',
                severity  => 'ERR',
                from      => 'GUI',
                msg_short => __( "Can't open [_1]/etc/apiis.css", $vapiis ),
            )
        );
	goto ERR;
    }
    if ( -e $apiis->sql_logfile and !-w $apiis->sql_logfile ) {
        my $a = $apiis->sql_logfile;
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'OS',
                severity  => 'ERR',
                from      => 'GUI',
                msg_short => __( "[_1] Can't write $a", $ENV{'REMOTE_IDENT'} ),
            )
        );
	goto ERR;
    }
    if ( !-w $apiis->filelog_filename ) {
        my $a = $apiis->filelog_filename;
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'OS',
                severity  => 'ERR',
                from      => 'GUI',
                msg_short => __( "[_1] Can't write $a", $ENV{'REMOTE_IDENT'} ),
            )
        );
	goto ERR;
    }
    if ( !-r "$ENV{'APIIS_HOME'}/etc/apiisrc" ) {
        $apiis->errors(
            Apiis::Errors->new(
                type      => 'OS',
                severity  => 'ERR',
                from      => 'GUI',
                msg_short => __( "[_1] Can't read $ENV{'APIIS_HOME'}/etc/apiisrc", $ENV{'REMOTE_IDENT'} ),
            )
        );
	goto ERR;
    }
    return 0;
ERR:
    return 1;
}

sub EvalCGIParameter {
    my $query=shift;
    my $cgi;

    map {$cgi->{$_}=$query->param($_)} keys %{$query->Vars};
    
    if ((! ($cgi->{'g'} )) and (! ($cgi->{'json'} )))  {
        $apiis->errors(Apiis::Errors->new(
            type      => 'PARAM',severity  => 'ERR',from      => 'GUI',
            msg_short => __("-o or -g or -m option wasn't set"),
        ));
        goto ERR; 
    }

#    my $json;
#    if ($query->charset!~/utf.*?8/i) {
#        use Encode;
#        $json= Encode::encode('utf8',$cgi->{json});
#
#        $cgi->{json}=$json;
#    }

    return $cgi;

    ERR:
    return 1;
}

1;
