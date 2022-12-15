    #!/usr/bin/perl
    use FCGI;

    my $count2++;
    my $request = FCGI::Request();
    while ($request->Accept() >= 0 && $count < 10)
    {
      print "Content-type: text/html\r\n\r\n";
      $count++;
      print "$$ / $count / $count2";
      print "Dies ist ein Test fuer FastCGI\n";

      $request->Finish();
      exit if -M $ENV{SCRIPT_FILENAME} < 0;
    }
    #$request->Finish();
    print "Content-type: text/html\r\nStatus: 200 OK\r\n\r\n";
    $request->Finish();
