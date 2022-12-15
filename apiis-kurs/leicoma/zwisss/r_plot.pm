############################################################
# r_plot.pm
############################################################
# sub r_plot
# example parameterhash (more see pod)
#       my %parameter_hash = (
# 			    filename => $breeder,
# 			    sql      => '',
#                           odbc_line => [ 'testherden', 'b08ralf', 'b08ralf' ],
#                           microsoft_sql_server => 'no',
# 			    no_sql_elements => '',
# 			    data => [ \@dat_y, \@dat_e, \@dat_f_y, \@dat_f_e],
# 			    export_format => 'pdf',
# 			    chart_type => 'barplot_lines',
# 			    chart_type2 => 'b',
#                           range       => [ 0, max ],
#                           range2      => [ min, 100 ],
# 			    legend      => ['whole population', "breeder: $out_breeder"],
#                           legendpos   => [ 'left', 'top' ],
# 			    second_y_axis => 'no',
# 			    titel      => '"BLUE values of effect ' . $effect_class . ' for trait ' . $out_trait . '"',
# 			    subtitel   => '"' . $out_breeder . '"',
# 			    xlabel     => '"Timeaxis"',
# 			    ylabel     => '"BLUE"',
# 			    mtext_l    => '', # additional text
# 			    mtext_r    => '',
# 			    color      => 'yes',
# 			    x_dates    => 'no'
# 			   );
#
#       $status = r_plot( \%parameter_hash );
#
# usage $outfile = r_plot(\%hashref)
############################################################
sub r_plot {
  my $args = shift;
  %args = %$args;

  my $filename = 'r_in';
  use Env qw( APIIS_HOME );
  if ( $APIIS_HOME ) {
      push @INC, "$APIIS_HOME/lib";
      chdir($APIIS_HOME."/tmp");
      $filename = rand();
  }
  open( RIN, ">$filename");

  my $alpha = ();		# check if names are alphanumeric
  if ( $args{ data } ) {
	print RIN '
    postscript("' . $args{ filename } . '.ps", paper = "a4")
      ';
	@lines_dat = ();
	my @data = @{$args{ data }};
	# next if ( $#data == -1 );
	$min = 1000;
	$max = 0;
	$xmin = 999000000;
	$xmax = 0;
	for ( my $nn = 0; $nn <= $#data; $nn=$nn+2 ) {
	  my $dat1 = (); my $dat2 = ();
	  map { $xmin = $_ if ( $_ < $xmin ) } @{$data[$nn]};
	  map { $xmax = $_ if ( $_ > $xmax ) } @{$data[$nn]};
	  if ( $args{ 'chart_type' } ne 'after_pest_barchart' or $nn == 0 ) {
	      map { $min = $_ if ( $_ < $min ) } @{$data[$nn+1]};
	      map { $max = $_ if ( $_ > $max ) } @{$data[$nn+1]};
	  }

	  map { s/(.*)/'$1'/ if $_ =~ /[a-zA-Z_]/ } @{$data[$nn]};
	  map { s/(.*)/'$1'/ if $_ =~ /[a-zA-Z_]/ } @{$data[$nn+1]};
	  $alpha = 1 if ( grep { /[a-zA-Z_]/ }  @{$data[$nn]} );

	  $dat1 = join(',',@{$data[$nn]}) if ( @{$data[$nn]} );
	  $dat2 = join(',',@{$data[$nn+1]}) if ( @{$data[$nn+1]} );

	  if ( $nn == 0 ) {
	    my $len_data = scalar ( @{$data[$nn]} );
	    if ( $len_data > 20 ) {
	      my @dat_1 = (); my @dat_2 = ();
	      my $dat1 = (); my $dat2 = ();
	      for ( my $l = 0; $l < $len_data; $l = $l + 20 ) {
		@dat_1 = splice ( @{$data[$nn]}, 0 , 20 ) if ( @{$data[$nn]} );
		$dat1 = join(',',@dat_1) if ( @dat_1 );
		@dat_2 = splice ( @{$data[$nn+1]}, 0 , 20 ) if ( @{$data[$nn+1]} );
		$dat2 = join(',',@dat_2) if ( @dat_2 );
		if ( $l == 0 ) {
		  print RIN "m<-c($dat1)\n y<-data.frame(m,m)\n" if ( ! $dat2 );
		  print RIN "m<-c($dat1)\n n<-c($dat2)\n y<-data.frame(m,n)\n" if ( $dat2 );
		} else {
		  print RIN "m<-c(m, $dat1)\n \n\n" if ( ! $dat2 );
		  print RIN "m<-c(m, $dat1)\n n<-c(n, $dat2)\n" if ( $dat2 );
		}
	      }
	      print RIN " y<-data.frame(m,m)\n" if ( ! $dat2 );
	      print RIN " y<-data.frame(m,n)\n" if ( $dat2 );
	    } else {
	      print RIN "m<-c($dat1)\n y<-data.frame(m,m)\n" if ( ! $dat2 );
	      print RIN "m<-c($dat1)\n n<-c($dat2)\n y<-data.frame(m,n)\n" if ( $dat2 );
	    }
	  } else {
	    next if ( ! @{$data[$nn]} );
	    my $chr = chr($nn %(26) + ord('a'));
	    if ( $args{ chart_type } eq 'barplot_lines' ) {
	      @a = @{$args{ data }[0]};
	      @b = @{$args{ data }[$nn]};
	      # 	  print "A=@a\nB=@b\n";
	      ($xr,$yr)=get_pos_val(\@a,\@b);
	      $yr = $yr;	# prevent error
	      # 	  print "==>\nX=@{$xr}\nY=@{$yr}\n";
	      my @dat_out_f_e = ();
	      map { $_ = $_ + 1 } @{ $xr };
	      map { $_ = 'bp[[' . $_ . ']]' } @{ $xr };
	      $dat_barlines = join( ',', @{ $xr } );
	      for ( my $pos = 0 ; $pos <= $#{$xr}; $pos++ ) {
		push @dat_out_f_e, ${$args{ data }[$nn+1]}[$pos]; # $dat_f_e[ ${$xr}[$pos] ];
	      }
	      $dat2 = join(',', @dat_out_f_e );
	      print RIN "m<-c($dat1)\n n<-c($dat2)\n \n";
	      push @lines_dat, $chr;
	    } else {
	      print RIN "m<-c($dat1)\n n<-c($dat2)\n $chr<-data.frame(m,n)\n";
	      push @lines_dat, $chr;
	    }
	  }
	}
  } else {
    my $db_name = ${$args{ odbc_line }}[0];
    my $db_user = ${$args{ odbc_line }}[1];
    my $db_pwd = ${$args{ odbc_line }}[2] if ( ${$args{ odbc_line }}[2] );
    print RIN '
     library(gplots)
     library(RODBC)
     ';
    if ( $args{ microsoft_sql_server } eq 'no' ) {
      if ( ${$args{ odbc_line }}[2] ) {
	print RIN '
     channel <- odbcConnect("' . $db_name . '", uid="' . $db_user . '", pwd="' . $db_pwd . '", case="tolower" )
     ';
      } else {
	print RIN '
     channel <- odbcConnect("' . $db_name . '", uid="' . $db_user . '", case="tolower")
    '
   }
    } else {
      if ( ${$args{ odbc_line }}[2] ) {
	print RIN '
     channel <- odbcConnect("' . $db_name . '", uid="' . $db_user . '", pwd="' . $db_pwd . '", case="nochange", believeNRows=FALSE)
     ';
      } else {
	print RIN '
     channel <- odbcConnect("' . $db_name . '", uid="' . $db_user . '", case="nochange", believeNRows=FALSE)
    '
   }
    }
    print RIN '
     postscript("' . $args{ filename } . '.ps", paper = "a4")
     y <- sqlQuery(channel, "' . $args{ sql } . '")
     close(channel)
     ';
  }
  
    if ( $args{ x_dates } eq 'yes' ) {
      print RIN '
     a <- strptime(as.character(y[[1]]), "%Y-%m-%d")
     b <- y[[2]]
    ';
    } else {
      print RIN '
     a <- y[[1]]
    ';
      if ( $args{ chart_type } ne 'histogramm' and $args{ chart_type } ne 'barcount' ) {
	print RIN '
        b <- y[[2]]
        ';
      }
    }

    my $legend_out = ();
    if ( $args{ legend } ) {
      # legende formatieren
      @legend = @{$args{ legend }};
      foreach $sel ( @legend ) {
	$legend_out .= ',"' . $sel . '"';
      }
      $legend_out =~ s/^,//g if ( $legend_out );
    }

  if ( $args{ chart_type } ne 'piechart'and $args{ chart_type } ne 'piechart_num' and $args{ chart_type } ne 'barplot' and $args{ chart_type } ne 'barplot_lines' and $args{ chart_type } ne 'histogramm' and $args{ chart_type } ne 'barcount' and $args{ chart_type } ne 'boxplot' and $args{ chart_type } ne 'scatterplot' and $args{ chart_type } ne 'piechart_num'and $args{ chart_type } ne 'barlines_time' and $args{ chart_type } ne 'barlines25' and $args{ chart_type } ne 'barlines25_cat' and $args{ chart_type } ne 'regression'  and $args{ chart_type } ne 'after_pest_barchart') {
    if ( $args{ data } ) {
      $count_elements = $#{$args{ data }} + 1;
    } else {
      $count_elements = $args{ no_sql_elements };
    }

    for ( $n = 2; $n <= $count_elements; $n ++ ) {
      if ($n == 2 ) {
	print RIN '
          plot(a,b';

	if ( $args{ chart_type } ne 'scatterplot' ) {
	  print RIN ', type = "' . $args{ chart_type } . '"' if ( $args{ chart_type });
	}
	print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
	print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
	print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
	print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
	print RIN ', col = \'' . $n . '\'' if ( $args{ color } );
	if ( $args{ range } ) {
	    if ( $args{ range }[0] eq 'min' ) {
		print RIN ', ylim = c(' . $min . ', ' . $args{ range }[1] . ')' if ( $min );
	    } elsif ( $args{ range }[1] eq 'max' ) {
		print RIN ', ylim = c(' . $args{ range }[0] . ', ' . $max . ')' if ( $max );
	    } else {
		print RIN ', ylim = c(' . $args{ range }[0] . ', ' . $args{ range }[1] . ')';
	    }
	} else {
	    print RIN ', ylim = c(' . $min . ', ' . $max . ')' if ( $min );
	}
	print RIN ', xlim = c(' . $xmin . ', ' . $xmax . ')' if ( $xmin );
	print RIN ')' if ( $args{ chart_type } ne 'histogramm' );
      } else {

	print RIN "\n" . chr($m) . '<- ' . "y[[$n]]\n print(" . chr($m) . ")\n" if ( ! $args{ data } );
	my $m = $n + 71;
	$pch = $n + 14;		# other symbols + 12;
	@pch_out = ();
	if ( ! $args{ data } ) {
	  if ( $args{ second_y_axis } eq 'yes' and $args{ no_sql_elements } and $args{ no_sql_elements } eq '3' ) {
	    print RIN "
         par(new=TRUE,yaxs='r')
         plot(a," . chr($m) . ", axes=FALSE, xlab = \"\", ylab = \"\", pch=$pch";
	    print RIN ', type = "' . $args{ chart_type2 } . '"'
	      if ( $args{ chart_type2 });
	    print RIN ', col = \'' . $pch . '\'' if ( $args{ color } );
	    print RIN ')';
	    print RIN "
         points(a," . chr($m) . ", axis(4), pch=$pch";
	    push @pch_out, $pch;
	    if ( $args{ range2 } ) {
		if ( $args{ range2 }[0] eq 'min' ) {
		    print RIN ', ylim = c(' . $min . ', ' . $args{ range2 }[1] . ')' if ( $min );
		} elsif ( $args{ range2 }[1] eq 'max' ) {
		    print RIN ', ylim = c(' . $args{ range2 }[0] . ', ' . $max . ')' if ( $max );
		} else {
		    print RIN ', ylim = c(' . $args{ range2 }[0] . ', ' . $args{ range2 }[1] . ')';
		}
	    } else {
		print RIN ', ylim = c(' . $min . ', ' . $max . ')' if ( $min );
	    }
	    print RIN ', xlim = c(' . $xmin . ', ' . $xmax . ')' if ( $xmin );
	    print RIN ')';
	  } else {
	    print RIN "
        points(a," . chr($m) . ", pch=$pch";
	    print RIN ', col = \'' . $pch . '\'' if ( $args{ color } );
	    push @pch_out, $pch;
	    print RIN ')';
	  }
	  print RIN "
#          ypos <- mean(" . chr($m) . ",na.rm=TRUE)
#          xpos <- min(a,na.rm=TRUE)";
	} else {
	  if ( @lines_dat ) {
	    my $cou = 1;
	    foreach my $v ( @lines_dat ) {
	      $cou++;
	      $pch = $cou + 14; # other symbols + 12;
	      push @pch_out, $pch;
	      print RIN "
	                 points($v, pch=$pch";
	      print RIN ', type = "' . $args{ chart_type2 } . '"'
		if ( $args{ chart_type2 });
	      print RIN ', col = \'' . $pch . '\'' if ( $args{ color } );
	      print RIN ')';
	      print RIN "
# 		  ypos <- mean(" . $v . "[[2]],na.rm=TRUE)
# 		  xpos <- min(a,na.rm=TRUE)" if ( $cou == 2 );
	    }
	    last;
	  }
	}
      }
    }
     $pch_out = join( ',', @pch_out);
#     print RIN ", col = c(2, $pch_out)" if ( $args{ color } );
#     print RIN ")";
    print RIN "\nmtext(\'$args{ mtext_l }\', side = 3, adj =0)\n" if ( $args{ mtext_l } );
    print RIN "\nmtext(\'$args{ mtext_r }\', side = 3, adj =1)\n" if ( $args{ mtext_r } );
    print RIN "\nlibrary(gplots)\n";
    if ( $args{ legendpos } ) {
	print RIN "smartlegend(x='" . $args{ legendpos }[0] . "', y='". $args{ legendpos }[1] ."' , " if ( $legend_out );
    } else {
	print RIN "smartlegend(x='left', y='bottom', " if ( $legend_out );
    }
    print RIN " pch=c(1, $pch_out), legend = c(" . $legend_out . "))\n" if ( $legend_out );
} elsif ( $args{ chart_type } eq 'piechart_num' ) { # pie chart + numbers
  print RIN "y<-unique(y)\n";
  print RIN "pie.counts <-y[[2]]\nnames(pie.counts) <- y[[1]]\n";
  print RIN "mya<-sum( y[[2]] )
             mylab<-paste(y[[1]], '(', y[[2]], '/',  sprintf(\"%2.1f\",y[[2]] * 100 / mya), '%)')\n";
  umlaute( 'mylab' ); # german funnys
  print RIN "print(y)\npie(pie.counts, labels = mylab, col = rainbow(length(names(pie.counts))) ";
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ')';
  print RIN "\n mtext(paste('gesamt n:', mya), side = 1)";
  } elsif ( $args{ chart_type } eq 'piechart' ) { # pie chart
  # pie.sales <- c(0.12, 0.3, 0.26, 0.16, 0.04, 0.12)
  # names(pie.sales) <- c("Blueberry", "Cherry",
  #   "Apple", "Boston Cream", "Other", "Vanilla Cream")
  print RIN "pie.counts <-y[[2]]\nnames(pie.counts) <- y[[1]]\n
             print(y)\npie(pie.counts, col = rainbow(length(names(pie.counts))) ";
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ')';
} elsif ( $args{ chart_type } eq 'piechart_num' ) { # pie chart + numbers
  print RIN "y<-unique(y)\n";
  print RIN "pie.counts <-y[[2]]\nnames(pie.counts) <- y[[1]]\n";
  print RIN "mya<-sum( y[[2]] )
             mylab<-paste(y[[1]], '(', y[[2]], '/',  sprintf(\"%2.1f\",y[[2]] * 100 / mya), '%)')\n";
  umlaute( 'mylab' ); # german funnys
  print RIN "print(y)\npie(pie.counts, labels = mylab, col = rainbow(length(names(pie.counts))) ";
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ')';
  print RIN "\n mtext(paste('gesamt n:', mya), side = 1)";
} elsif ( $args{ chart_type } eq 'barplot' ) { # bar chart
  print RIN "means<-by(a, b, mean, na.rm=T)
             S<-barplot(means, xpd=FALSE, ylim = c(0, max(means) + 2*( max(means)/100 ))";
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ')';
  print RIN "\n";
  print RIN 'box(bty="o")';
  print RIN "\n";
  print RIN 'x<-tapply(a, b, length)';
  print RIN "\n";
  print RIN 'at<-S';
  print RIN "\n";
  print RIN 'mtext(x, side=3, line=0, at=at)';
  print RIN "\n";
  print RIN 'mtext("n =", side=3, line=0, adj=0)';
} elsif ( $args{ chart_type } eq 'barplot_lines' ) { # bar chart plus lines
  if ( ! $alpha ) {
    print RIN "bp<-barplot(y[[2]], xpd=FALSE, col = 'red', names.arg=c(y[[1]])";
  } else {
    print RIN "bp<-barplot(y[[2]], xpd=FALSE, col = 'red', names.arg=c(m)";
  }
  print RIN ', yaxs=\'r\', ylim = c(' . $min . ', ' . $max . ')' if ( $min );
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ')';
  my $out = $anz_bars;
  print RIN "\n bout<-c(" . $dat_barlines . "\n";
  print RIN ')';
  print RIN "\n lines(bout, n "; # rffr
  print RIN ', type = "' . $args{ chart_type2 } . '"'
    if ( $args{ chart_type2 });
  print RIN ')';
  print RIN "\n box()\n";
#  print RIN "\n xpos<-" . ${$xr}[ 0 ] ."\n";
#  print RIN "\n ypos<-$max\n";
  print RIN "\nrequire(gplots, quietly=TRUE)\n";
  if ( $legend[0] ) {
      if ( $args{ legendpos } ) {
	  print RIN "smartlegend(x='" . $args{ legendpos }[0] . "', y='". $args{ legendpos }[1] . "' , ";
      } else {
	  print RIN "smartlegend(x='left', y='bottom', ";
      }
      print RIN "fill=2, legend = c('" . $legend[0] . "'))";
      #  print RIN "\n xmax<-" . ${$xr}[ $#{$xr} - 2 ] ."\n";
      print RIN "\nsmartlegend(x='right', y='bottom', ";
      print RIN ", pch=c(1), legend = c('" . $legend[1] . "'))\n";
  }
#  print RIN ", col = c(2, $pch_out)" if ( $args{ color } );
}   elsif ( $args{ chart_type } eq 'barlines_time' ) { # barplot and lines for
                                                  # three elements sql
  print RIN 'library("chron")'."\n";
  print RIN 'compdate<-as.POSIXct(Sys.Date()-730)'."\n";
  print RIN 'x<-subset(y, y[[2]] > compdate)'."\n";
  #  print RIN 'x<-subset(y, as.Date(y[[2]]) > compdate)'."\n";
  # taifun notwendig...?
  print RIN 'levb <- levels(factor(x[[3]]))'."\n";
  print RIN 'for ( i in levb ) {'."\n";
  print RIN 'g<-subset(x, x[[3]]== i)'."\n";
  print RIN 'name<-paste("'. $args{ filename } . '_",' . 'i, sep = \'\')'."\n";
  print RIN 'postscript(name, paper = "a4")'."\n";

  print RIN 'datesyq<-paste(format(x[[2]], "%Y"), quarters(x[[2]]))';
  print RIN ''."\n";
  print RIN 'cc<-tapply(x[[1]], datesyq, mean, na.rm=TRUE)'."\n";
  print RIN 'yl1<-min(x[[1]], na.rm=TRUE)'."\n";
  print RIN 'yl2<-max(x[[1]], na.rm=TRUE) + 2*( max(x[[1]], na.rm=TRUE)/100 )'."\n";
  print RIN 'ylim<-c(yl1, yl2)'."\n";
  print RIN 'S<-barplot(cc, ylim=ylim, xpd=FALSE';
  print RIN ', main = paste(' . $args{ titel }  . ', i)' if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
  print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
  print RIN ')'; print RIN "\n";
  print RIN 'box(bty="o")';
  print RIN "\n";
  print RIN 'ccmax<-tapply(x[[1]], datesyq, max, na.rm=TRUE)'."\n";
  print RIN 'segments(S, cc, S, ccmax)'."\n";
  print RIN 'points(S, ccmax, pch = 24, col = "black")'."\n";
  # einzelbetriebe
  print RIN 'datesyqg<-paste(format(g[[2]], "%Y"), quarters(g[[2]]))'."\n";
  print RIN 'gg<-tapply(g[[1]], datesyqg, mean, na.rm=TRUE)'."\n";
  print RIN 'ggmax<-tapply(g[[1]], datesyqg, max, na.rm=TRUE)'."\n";
  print RIN 'str(gg)'."\n";
  print RIN '
   mya<-NaN
   l<-0
   for ( ii in names(cc) ) {
    l<-l+1
    for ( iii in names(gg) ) {
     if ( ii == iii ) {
      mya<-c(mya, l)
     }
    }
   }
   myo<-mya[2:length(mya)]
   ';
  print RIN 'lines(S[myo], gg, pch=19, type="b", col = "blue")'."\n";
  print RIN 'lines(S[myo], ggmax, type="b", pch=19, col = "red")'."\n";
  # legende
  print RIN "\n xpos<-max(S) - 20*(max(S)/100)\n";
  print RIN "\n ypos<-min(x[[1]]) + 20*(min(x[[1]])/100)\n";
  print RIN 'text(xpos+4*(xpos/100),ypos,label=("Betrieb"), pos=3)'."\n";
  print RIN 'legend(xpos, ypos, bg="grey", lty=c(1,1), col=c("red","blue"), pch=c(19,19), legend = c("maximum","durchschnitt"))'."\n";
  print RIN "\n xpos2<-min(S) + 20*(min(S)/100)\n";
  print RIN 'text(xpos2+4*(xpos/100),ypos,label=("alle Betriebe"), pos=3)'."\n";
  print RIN 'legend(xpos2, ypos, bg="grey", col=c("black","black"), pch=c(24,22), legend = c("maximum","durchschnitt"))'."\n";

  print RIN "}\n";
  print RIN 'dev.off()'."\n";
  print RIN '
     levb <- levels(factor(x[[3]]))
     capture.output(levb, file = "R_temp_out_b")
     ';
}   elsif ( $args{ chart_type } eq 'barlines25' ) { # barplot and lines for
                                                    # three elements sql

  print RIN 'levb <- levels(factor(x[[3]]))'."\n";
  print RIN 'for ( i in levb ) {'."\n";
  print RIN 'g<-subset(x, x[[3]]== i)'."\n";
  print RIN 'name<-paste("'. $args{ filename } . '_",' . 'i, sep = \'\')'."\n";
  print RIN 'postscript(name, paper = "a4")'."\n";

  print RIN 'cc<-tapply(x[[1]], x[[2]], '. $args{ function } .', na.rm=TRUE)'."\n";
  # einzelbetriebe
  #  print RIN 'datesyqg<-paste(format(g[[2]], "%Y"), quarters(g[[2]]))'."\n";
  print RIN 'gg<-tapply(g[[1]], g[[2]], '. $args{ function } .', na.rm=TRUE)'."\n";
  print RIN 'yl1<-min(x[[1]], na.rm=TRUE)'."\n";
  # print RIN 'yl2<-max(cc, na.rm=TRUE) + 2*( max(cc, na.rm=TRUE)/100 )'."\n";
  # print RIN 'yl2<-18'."\n";
  print RIN 'ylim<-c(yl1, yl2)'."\n";
  print RIN 'S<-barplot(cc, ylim=ylim, xpd=FALSE';
  print RIN ', main = paste(' . $args{ titel }  . ', i)' if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
  print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
  print RIN ')'; print RIN "\n";
  print RIN 'box(bty="o")';
  print RIN "\n";
  print RIN 's<-0'."\n";

  print RIN 'for ( j in levels(factor(datesyq)) ) {'."\n";
  print RIN 's<-s+1'."\n";
  print RIN 'limit<-subset(x, paste(format(x[[2]], "%Y"), quarters(x[[2]])) == j )'."\n";
#  print RIN 'str(limit)'."\n";
  print RIN 'ccc<-tapply(limit[[1]], limit[[3]], mean, na.rm=TRUE)'."\n";
  print RIN 'f<-order(ccc)'."\n";
  print RIN 'ff<-order(ccc, decreasing = TRUE)'."\n";
  print RIN 'fi<-f[1:3]'."\n";
  print RIN 'ffi<-ff[1:3]'."\n";
  print RIN 'ul<-subset(limit[[1]], limit[[3]] == c(names(ccc)[fi[[1]]], names(ccc)[fi[[2]]], names(ccc)[fi[[3]]] ) )'."\n";
  print RIN 'ol<-subset(limit[[1]], limit[[3]] == c(names(ccc)[ffi[[1]]], names(ccc)[ffi[[2]]], names(ccc)[ffi[[3]]] ) )'."\n";
#   print RIN 'if ( ! is.infinite(min(ol, na.rm=T))) { ol<-0 }'."\n";
#   print RIN 'if ( ! is.infinite(min(ul, na.rm=T))) { ul<-0 }'."\n";
  print RIN 'points(S[[s]],mean(ul),pch=24)'."\n";
  print RIN 'points(S[[s]],mean(ol),pch=25)'."\n";
  print RIN '}'."\n";
#  print RIN 'd<-mean(ol)'."\n"; print RIN 'oo<-tapply(o[[1]],
#   datesyq, '. $args{ function } .', na.rm=TRUE)'."\n"; 

  print RIN '
   mya<-NaN
   l<-0
   for ( ii in names(cc) ) {
    l<-l+1
    for ( iii in names(gg) ) {
     if ( ii == iii ) {
      mya<-c(mya, l)
     }
    }
   }
   myo<-mya[2:length(mya)]
   ';
  print RIN 'lines(S[myo], gg, pch=19, type="b", col = "blue")'."\n";
  print RIN "}\n";
  print RIN 'dev.off()'."\n";
  print RIN '
     levb <- levels(factor(x[[3]]))
     capture.output(levb, file = "R_temp_out_b")
     ';
}  elsif ( $args{ chart_type } eq 'barlines25_cat' ) { # barplot and lines for
                                                       # three elements sql
  print RIN 'x<-y'."\n";

  print RIN 'levb <- levels(factor(c))'."\n";
  print RIN 'for ( i in levb ) {'."\n";
  print RIN 'print(i)'."\n";
  print RIN 'g<-subset(x, x[[3]] == i)'."\n";
  print RIN 'name<-paste("'. $args{ filename } . '_",' . 'i, sep = \'\')'."\n";
  print RIN 'postscript(name, paper = "a4")'."\n";

  print RIN 'cc<-tapply(x[[1]], x[[2]], length)'."\n";
  print RIN 'tr<-subset(x, x[[1]] > 0)'."\n";
  print RIN 'ccc<-tapply(tr[[1]], tr[[2]], length)'."\n";
  # einzelbetriebe
  print RIN 'gg<-tapply(g[[1]], g[[2]], length)'."\n";
  print RIN 'tr2<-subset(g, g[[1]] > 0)'."\n";
  print RIN 'ggg<-tapply(tr2[[1]], tr2[[2]], length)'."\n";

  print RIN '
   myca<-NaN
   mycvals<-NaN
   l<-0
   for ( ii in names(cc) ) {
    l<-l+1
    test<-0
    for ( iii in names(ccc) ) {
     if ( ii == iii ) {
      test<-1
      myca<-c(myca, l)
      mycvals<-c(mycvals, ccc[[ii]]*100/cc[[ii]])
     }
    }
    if ( test == 0 ) {
      myca<-c(myca, l)
      mycvals<-c(mycvals, 0)
    }
   }
   myco<-myca[2:length(myca)]
   mycovals<-mycvals[2:length(mycvals)]
   ';
  print RIN '
   mya<-NaN
   myvals<-NaN
   l<-0
   for ( ii in names(gg) ) {
    l<-l+1
    test2<-0
    for ( iii in names(ggg) ) {
     if ( ii == iii ) {
      test2<-1
      mya<-c(mya, l)
      myvals<-c(myvals, ggg[[ii]]*100/gg[[ii]])
     }
    }
    if ( test2 == 0 ) {
      mya<-c(mya, l)
      myvals<-c(myvals, 0)
    }
   }
   myo<-mya[2:length(mya)]
   myovals<-myvals[2:length(myvals)]
   ';

  print RIN 'yl1<-min(mycovals, na.rm=TRUE)'."\n";
  print RIN 'yl2<-max(mycovals, na.rm=TRUE)'."\n";

  print RIN 'if ( yl1 > min(myovals, na.rm=TRUE) ) yl1<-min(myovals, na.rm=TRUE)'."\n";
  print RIN 'if ( yl2 < max(myovals, na.rm=TRUE) ) yl2<-max(myovals, na.rm=TRUE)'."\n";

  # min - max alles x-mal machen nur um die werte zu bekommen
  #  print RIN 's<-0'."\n";
  print RIN 'for ( j in levels(factor(x[[2]])) ) {'."\n";
  #  print RIN 's<-s+1'."\n";
  print RIN 'limit<-subset(x, x[[2]] == j )'."\n";
  # print RIN 'str(limit)'."\n";
  print RIN 'ccc1<-tapply(limit[[1]], limit[[3]], length)'."\n";
  print RIN 'tr1<-subset(limit, limit[[1]] > 0)'."\n";
  print RIN 'ccc2<-tapply(tr1[[1]], tr1[[3]], length)'."\n";
  print RIN '
   cmya<-NaN
   cmyvals<-NaN
   l<-0
   for ( ii in names(ccc1) ) {
    l<-l+1
    tests<-0
    for ( iii in names(ccc2) ) {
     if ( ii == iii ) {
      tests<-1
      cmya<-c(cmya, l)
      cmyvals<-c(cmyvals, ccc2[[ii]]*100/ccc1[[ii]])
     }
    }
    if ( tests == 0 ) {
      cmya<-c(cmya, l)
      cmyvals<-c(cmyvals, 0)
     }
   }
   cmyo<-mya[2:length(cmya)]
   cmyovals<-cmyvals[2:length(cmyvals)]
   ';

  print RIN 'if ( length(cmyovals) > 3 ) {'."\n";

  print RIN 'f<-order(cmyovals)'."\n";
  print RIN 'ff<-order(cmyovals, decreasing = TRUE)'."\n";

  print RIN 'my25<-round(length(cmyovals)/4)'."\n"; # 25% der werte

  print RIN 'fi<-f[1:my25]'."\n";
  print RIN 'ffi<-ff[1:my25]'."\n";

  print RIN 'cmypovals<-(sum(cmyovals[fi]*ccc1[fi])/sum(ccc1[fi]))'."\n";
  print RIN 'cmyppovals<-(sum(cmyovals[ffi]*ccc1[ffi])/sum(ccc1[ffi]))'."\n";

  # #   print RIN 'cmypovals<-mean(cmyovals[fi])'."\n";
  # #   print RIN 'cmyppovals<-mean(cmyovals[ffi])'."\n";

  print RIN 'if ( is.na(cmypovals) ) cmypovals<-0'."\n";
  print RIN 'if ( is.na(cmyppovals) ) cmyppovals<-0'."\n";

  print RIN 'if ( yl1 > min(cmypovals, na.rm=TRUE) ) yl1<-min(cmypovals, na.rm=TRUE)'."\n";
  print RIN 'if ( yl2 < max(cmyppovals, na.rm=TRUE) ) yl2<-max(cmyppovals, na.rm=TRUE)'."\n";

  print RIN '}'."\n";
  print RIN '}'."\n";
  ## min - max

  print RIN 'yl1<-yl1 - 2*( yl1/100 )'."\n"; # +2 %
  print RIN 'yl2<-yl2 + 2*( yl2/100 )'."\n"; # +2 %

  print RIN 'ylim<-c(yl1, yl2)'."\n";
  print RIN 'S<-barplot(mycovals, ylim=ylim, xpd=FALSE, names = names(cc)'. "\n";
  print RIN ', main = paste(' . $args{ titel }  . ', i)' if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
  print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
  print RIN ', col=0, border=0)'; print RIN "\n";
  print RIN 'box(bty="o")';
  print RIN "\n";
  print RIN ''."\n";
  # print RIN 'points(S[myo],myovals,pch=5)'."\n";
  print RIN 'barplot(myovals, add=TRUE, xpd=FALSE)'."\n";
  print RIN 'points(S[myco],mycovals,pch=8)'."\n";

  print RIN 's<-0'."\n";
  print RIN 'for ( j in levels(factor(x[[2]])) ) {'."\n";

  print RIN 's<-s+1'."\n";
  print RIN 'limit<-subset(x, x[[2]] == j )'."\n";
  # print RIN 'str(limit)'."\n";
  print RIN 'ccc1<-tapply(limit[[1]], limit[[3]], length)'."\n";
  print RIN 'tr1<-subset(limit, limit[[1]] > 0)'."\n";
  print RIN 'ccc2<-tapply(tr1[[1]], tr1[[3]], length)'."\n";
  print RIN '
   mya<-NaN
   myvals<-NaN
   l<-0
   for ( ii in names(ccc1) ) {
    l<-l+1
    tests<-0
    for ( iii in names(ccc2) ) {
     if ( ii == iii ) {
      tests<-1
      mya<-c(mya, l)
      myvals<-c(myvals, ccc2[[ii]]*100/ccc1[[ii]])
     }
    }
    if ( tests == 0 ) {
      mya<-c(mya, l)
      myvals<-c(myvals, 0)
    }
   }
   myo<-mya[2:length(mya)]
   myovals<-myvals[2:length(myvals)]
   ';

  print RIN 'if ( length(myovals) > 3 ) {'."\n";

  print RIN 'f<-order(myovals)'."\n";
  print RIN 'ff<-order(myovals, decreasing = TRUE)'."\n";
  print RIN 'my25<-round(length(myovals)/4)'."\n"; # 25% der werte
  print RIN 'fi<-f[1:my25]'."\n";
  print RIN 'ffi<-ff[1:my25]'."\n";

  print RIN 'mypovals<-(sum(myovals[fi]*ccc1[fi])/sum(ccc1[fi]))'."\n";
  print RIN 'myppovals<-(sum(myovals[ffi]*ccc1[ffi])/sum(ccc1[ffi]))'."\n";


  print RIN 'if ( is.na(mypovals) ) mypovals<-0'."\n";
  print RIN 'if ( is.na(myppovals) ) myppovals<-0'."\n";

  print RIN 'points(S[[s]],myppovals,pch=25)'."\n";
  print RIN 'points(S[[s]],mypovals,pch=24)'."\n";

  print RIN '}'."\n";

  print RIN '}'."\n";
  print RIN 'dev.off()'."\n";
  print RIN "}\n";
  print RIN '
     levb <- levels(factor(x[[3]]))
     capture.output(levb, file = "R_temp_out_b")
     ';
} elsif ( $args{ chart_type } eq 'regression' ) { # calc regression rffr
  print RIN 'name<-paste("'. $args{ filename } . '.ps", sep=\'\')'."\n";
  print RIN 'postscript(name, paper = "a4")'."\n";

  print RIN "a<-cars[[1]]\nb<-cars[[2]]\n";
  print RIN "plot(b,a)\n";
  print RIN "t<-min(b):max(b)\n";

  # seperate functions...
  # linear
  print RIN "cc1<-lm(a ~ b)\n";
  print RIN 'rs1<-summary(cc1)$r.squared'."\n";
  print RIN "func1<-function(a,b){ l1[[1]] + l1[[2]]*t }\n";
  print RIN "l1<-coef(cc1)\n";
  print RIN "lines(t,func1(l1[[1]],l1[[2]]), col=\"black\") \n";
  # quadratic
  print RIN 'c<-b^2'."\n";
  print RIN "cc2<-lm(a ~ b + c)\n";
  print RIN 'rs2<-summary(cc2)$r.squared'."\n";
  print RIN "func2<-function(a,b,c){ l2[[1]] + l2[[2]]*t + l2[[3]]*t*t }\n";
  print RIN "l2<-coef(cc2)\n";
  print RIN "lines(t,func2(l2[[1]],l2[[2]],l2[[3]]), col=\"blue\") \n";
  # kubic
  print RIN 'd<-b^3'."\n";
  print RIN "cc3a<-lm(a ~ b + d)\n";
  print RIN 'rs3a<-summary(cc3a)$r.squared'."\n";
  print RIN "func3a<-function(a,b,c){ l3a[[1]] + l3a[[2]]*t + l3a[[3]]*t*t*t }\n";
  print RIN "l3a<-coef(cc3a)\n";
  print RIN "lines(t,func3a(l3a[[1]],l3a[[2]],l3a[[3]]), col=\"yellow3\") \n";
  # quadratic + kubic
  print RIN "cc3<-lm(a ~ b + c + d)\n";
  print RIN 'rs3<-summary(cc3)$r.squared'."\n";
  print RIN "func3<-function(a,b,c,d){ l3[[1]] + l3[[2]]*t + l3[[3]]*t*t + l3[[4]]*t*t*t }\n";
  print RIN "l3<-coef(cc3)\n";
  print RIN "lines(t,func3(l3[[1]],l3[[2]],l3[[3]],l3[[4]]), col=\"yellow\") \n";
  # sqrt
  print RIN 'd<-b^3'."\n";
  print RIN "cc4<-lm(a ~ sqrt(b))\n";
  print RIN 'rs4<-summary(cc4)$r.squared'."\n";
  print RIN "func4<-function(a,b){ l4[[1]] + l4[[2]]*sqrt(t) }\n";
  print RIN "l4<-coef(cc4)\n";
  print RIN "lines(t,func4(l4[[1]],l4[[2]]), col=\"green\") \n";

  print RIN '
  cc5<-lm(a~1+b+exp(-0.05*b))
  l5 <- coef(cc5)
  rs5<-summary(cc5)$r.squared
  wilmink <- function(mm,alpha,beta) { l5[[1]] + l5[[2]]*t + l5[[3]] * exp(-0.05*t)}
  lines(wilmink(l5), col = "red")
#  alischaeffer <- function(mm, alpha, beta, gamma, delta ) { l[[1]] + l[[2]]*(t/dd) + l[[3]] * (t/dd)^2 + l[[4]] * (log(dd/t)) + l[[5]] * ((log(dd/t))^2)}
#  dd<-380
#  first <- b/dd
#  first2 <- (b/dd)^2
#  sec <- log(dd/b) 
#  sec2 <- (log(dd/b))^2 
#  h<-lm(a~1+first+first2+sec+sec2)
#  l <- coef(h)
#  print(l)
#  lines(alischaeffer(l), col = "blue")
  text(mean(t),9, paste("var(e):",  sprintf("%3.3f",var(residuals(cc5))), "R^2: ", sprintf("%3.3f",rs5)), col = "black")
  text(mean(t),8, paste("var(e):",  sprintf("%3.3f",var(residuals(cc4))), "R^2: ", sprintf("%3.3f",rs4)), col = "blue")
  text(mean(t),7, paste("var(e):",  sprintf("%3.3f",var(residuals(cc3))), "R^2: ", sprintf("%3.3f",rs3)), col = "yellow")
  text(mean(t),6, paste("var(e):",  sprintf("%3.3f",var(residuals(cc3a))), "R^2: ", sprintf("%3.3f",rs3a)), col = "yellow3")
  text(mean(t),5, paste("var(e):",  sprintf("%3.3f",var(residuals(cc2))), "R^2: ", sprintf("%3.3f",rs2)), col = "green")
  text(mean(t),4, paste("var(e):",  sprintf("%3.3f",var(residuals(cc1))), "R^2: ", sprintf("%3.3f",rs1)), col = "red")
';

#   print RIN "mytxt1<-paste('R^2:',  sprintf(\"%2.3f\",rs1), ' linear:', sprintf(\"%2.2f\",l1[[1]], '+', sprintf(\"%2.2f\",l1[[2]], ))\n\n";
#   print RIN "mtext(mytxt1), side=1)\n";
#   print RIN "
#   aa <- sprintf("%3.3f",l1[[1]])
#   bb <- sprintf("%3.3f",l1[[2]])
#   cc <- sprintf("%3.3f",l[[3]])
#   dd <- sprintf("%3.3f",l[[4]])

#   text(100,4,paste(aa, " ", bb, " ", cc, " ", dd), col= "red")
#   text(300,4, paste("var(e):",  sprintf("%3.3f",var(residuals(h)))), col = "red")

# \n";
  print RIN "\n";

} elsif ( $args{ chart_type } eq 'after_pest_barchart' ) { # after pest bar
  if ( ! $alpha ) {
    print RIN "bp<-barplot(y[[2]], xpd=FALSE, col = 'red', names.arg=c(y[[1]])";
  } else {
    print RIN "bp<-barplot(y[[2]], xpd=FALSE, col = 'red', names.arg=c(m)";
  }
  print RIN ', yaxs=\'r\', ylim = c(' . $min . ', ' . $max . ')' if ( $min );
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ')';
  print RIN "\nmtext(n, at=bp) \n";
  print RIN "\nmtext('n =', adj = 0) \n";
  print RIN "\n box()\n";
  print RIN "\nrequire(gplots, quietly=TRUE)\n";
  if ( $legend[0] ) {
      if ( $args{ legendpos } ) {
	  print RIN "smartlegend(x='" . $args{ legendpos }[0] . "', y='". $args{ legendpos }[1] . "' , ";
      } else {
	  print RIN "smartlegend(x='left', y='bottom', ";
      }
      print RIN "fill=2, legend = c('" . $legend[0] . "'))";
      #  print RIN "\n xmax<-" . ${$xr}[ $#{$xr} - 2 ] ."\n";
      print RIN "\nsmartlegend(x='right', y='bottom', ";
      print RIN ", pch=c(1), legend = c('" . $legend[1] . "'))\n";
  }
} elsif ( $args{ chart_type } eq 'histogramm' ) { # special histogramm
  print RIN '
rffr1 <- function( variable, name ) {

inf<-variable
def.par <- par(no.readonly = TRUE)# save default, for resetting...
nf <- layout(matrix(c(1,2)),c(1,1),c(1,2.7))
mfg=c(1,1,1,1)
par(mar=c(0,4,1,2))
#axis(1, xaxs="i")
xlim=c( min(inf, na.rm=T), max(inf, na.rm=T))
S<-boxplot(inf, horizontal=T, ylab=name, axes=F)#, xlim=xlim)
mtext(S$n, side=2, line=0)
means<-mean(inf, na.rm=T)
points(means, 1, pch = 23, cex=0.50, bg="red")
box(bty="o")
#rug(inf, side=1)
#par(mar=c(2,2))

mfg=c(2,1,1,1)
dens<-density(inf, na.rm=T)
ylim<-range(dens$y)
par(bty="o")
par(mar=c(4,4,0,2))
hist(inf, probability = T, xlim=xlim, ylim=ylim, main = \'\', xlab=\'\')
box(bty="o")
lines(dens)
par(new=F)
#plot(density(inf, na.rm=T), main=\'\', xlim=xlim)
rug(inf, side=1)

par(mar=c(5,4,4,2)) # default
par(def.par)# - reset to default
}
';
  print RIN 'rffr1(a, \'' . $args{ titel } . '\')';

}  elsif ( $args{ chart_type } eq 'boxplot' ) { # boxplot

  print RIN 'S<-boxplot(y[[1]]~ y[[2]]';
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
  print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
  print RIN ')';

  print RIN '
   at<-(1:length(S$names))
   mtext(S$n, side=3, line=0, at=at)
   mtext("n =", side=3, line=0, adj=0)
   means<-by(y[[1]], y[[2]], mean, na.rm=T)
   points(at, means, pch = 23, cex=0.50, bg="black")
';
}  elsif ( $args{ chart_type } eq 'barcount' ) { # barplot as count for
						 # levels
  print RIN 'x<-tapply(a, factor(a), length)';
  print RIN "\n";
  print RIN 'S<-barplot(x, xpd=FALSE, ylim = c(0, max(x) + 6*( max(x)/100 ))'; # +6% ylim
  print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
  print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
  print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
  print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
  print RIN ')'; print RIN "\n";
  print RIN 'box(bty="o")';
  print RIN "\n";
  print RIN 'at<-S';
  print RIN "\n";
  print RIN "text(S,x, labels=x, pos=3)\n";
  print RIN "\nl<-x/length(a)*100\n"; # %
  print RIN "\n";
  print RIN 'mtext(sapply(l, function(n) sprintf("%2.2f", n)), side=3, line=0, at=at)';
  print RIN "\n";
  print RIN 'mtext("% =", side=3, line=0, adj=0)';
  print RIN "\n";
  print RIN 'mtext(paste("total =", length(a)), side=3, line=1, adj=0)';
  print RIN "\n";
  print RIN 'mtext(paste("valid =", sum(x), "(", sprintf("%2.2f", sum(x)/length(a)*100), "%)"), side=3, line=1, adj=1)';
  print RIN "\n";
  print RIN '
     levb <- levels(factor(a))
     capture.output(levb, file = "R_temp_out_b")
     ';
}  elsif ( $args{ chart_type } eq 'scatterplot' ) {
  if ( $args{ data } ) {
    $count_elements = $#{$args{ data }} + 1;
  } else {
    $count_elements = $args{ no_sql_elements };
  }

  for ( $n = 2; $n <= $count_elements; $n ++ ) {
    if ($n == 2 ) {
      print RIN '
          plot(b,a';

      print RIN ', main = ' . $args{ titel }  if ( $args{ titel } );
      print RIN ', sub  = ' . $args{ subtitel }  if ( $args{ subtitel } );
      print RIN ', xlab = ' . $args{ xlabel } if ( $args{ xlabel } );
      print RIN ', ylab = ' . $args{ ylabel } if ( $args{ ylabel } );
      print RIN ', col = \'' . $n . '\'' if ( $args{ color } );
	if ( $args{ range } ) {
	    if ( $args{ range }[0] eq 'min' ) {
		print RIN ', ylim = c(' . $xmin . ', ' . $args{ range }[1] . ')' if ( $xmin );
	    } elsif ( $args{ range }[1] eq 'max' ) {
		print RIN ', ylim = c(' . $args{ range }[0] . ', ' . $xmax . ')' if ( $xmax );
	    } else {
		print RIN ', ylim = c(' . $args{ range }[0] . ', ' . $args{ range }[1] . ')';
	    }
	} else {
	    print RIN ', ylim = c(' . $xmin . ', ' . $xmax . ')' if ( $xmin );
	}
      # print RIN ', ylim = c(' . $xmin . ', ' . $xmax . ')' if ( $xmin );
      print RIN ', xlim = c(' . $min . ', ' . $max . ')' if ( $min );
    }
  }
  print RIN ")";
  print RIN "\nmtext(\'$args{ mtext_l }\', side = 3, adj =0)\n" if ( $args{ mtext_l } );
  print RIN "\nmtext(\'$args{ mtext_r }\', side = 3, adj =1)\n" if ( $args{ mtext_r } );
  print RIN "\nrequire(gplots, quietly=TRUE)\n";
  if ( $args{ legendpos } ) {
      print RIN "smartlegend(x='" . $args{ legendpos }[0] . "', y='". $args{ legendpos }[1] . "' , " if ( $legend_out );
  } else {
      print RIN "smartlegend(x='left', y='bottom', " if ( $legend_out );
  }
  print RIN " pch=c(1, $pch_out), legend = c(" . $legend_out . ")" if ( $legend_out );


  print RIN "\nz<-lm(a~b)
             abline(z, col=1, lty=1)\n
             n<-length(a)\n
             mtext(paste(\"n =\", n), side=3, line=0, adj=0)\n
             mtext(paste(\"y = a + b*\", $args{ xlabel } ), side=3, line=0, adj=1)\n
            ";
  if ( $args{ pestreg } ) {

#     print RIN "zz<-c(sum(a)/length(a), $args{ pestreg } )
#              abline(zz, col=2, lty=2)\n";
#     das stimmt so sicher nicht! rffr
    print RIN "xo<-mean(b)
               yo<-mean(a)
               mc<-yo-(  $args{ pestreg } * xo )
               abline(mc, $args{ pestreg }, col=2, lty=2)\n";
    print RIN "\nrequire(gplots, quietly=TRUE)\n";
    if ( $args{ legendpos } ) {
	print RIN "smartlegend(x='" . $args{ legendpos }[0] . "', y='". $args{ legendpos }[1] . "' , ";
    } else {
	print RIN "smartlegend(x='right', y='bottom', ";
    }
    print RIN " col=c(1, 2), lty=c(1,2), legend = c(
 paste('phenotypic         b = ', sprintf(\"%3.3f\",z[[1]][[2]])),
 paste('from PEST-run  b = ', sprintf(\"%3.3f\",$args{ pestreg }))))\n\n";
  }
}

print RIN '
dev.off()
q()
';
close( RIN );
system("R -q < $filename --save > $filename\_out");
my $convert = 'convert ' . $args{ filename } . '.ps ' . $args{ filename } . '.' .$args{ export_format };
system("$convert");
my $rm = 'rm ' . $args{ filename } . '.ps';
system("$rm");
my $ret = $args{ filename } . '.' .$args{ export_format };
return( $ret );
}
#

sub get_pos_val {
  # get indizes of values in @a which have also the same values in @b
  # @b would cleaned out
  # @x has indizes - @y values from @a ( which included in @b)
  # usage: ($xr,$yr)=get_pos_val(\@a,\@b);
  # used in r_plot()
  my $ar = shift;
  my $br = shift;
  my $len = scalar @{$ar};
  @x = (); @y = ();
  my $b = shift @{$br};
  while( defined $b ) {
    my $i = 0; while($i<$len && $b ne @{$ar}[$i]){$i++;}
    if( $i<$len ){ push @x, $i; push @y, $b; }
    $b = shift @{$br};
  }
  return \@x,\@y;
}

sub umlaute {
  my $str = shift;
  print RIN 'newstr<-sub("_AE_","Ä", '.$str.")\n";
  print RIN 'newstr<-sub("_ae_","ä", newstr)' . "\n";
  print RIN 'newstr<-sub("_OE_","Ö", newstr)' . "\n";
  print RIN 'newstr<-sub("_oe_","ö", newstr)' . "\n";
  print RIN 'newstr<-sub("_UE_","Ü", newstr)' . "\n";
  print RIN 'newstr<-sub("_ue_","ü", newstr)' . "\n";
  print RIN 'newstr<-sub("_SS_","ß", newstr)' . "\n";
  print RIN $str."<-newstr\n";
}


############################################################
=pod

=head1 NAME

r_plot.pm

=head1 ABSTRACT

can be used to generate some graphs on the fly. unfortunately there
are only some static charts available. the data could come in either
from pure sql or directly by data as arrayreference. this library require R,
ImageMagick and ODBC (if sql would be used).

=head1 USAGE

use r_plot;
$outfilename = r_plot( %parameter_hash );

=head1 HASHSTRUCTURE

the keywords in the hash are fixed, but not all keywords would be used
in all charttypes... (need an detailed description what can be used
where)

=head2 filename

name of the outputfile without the extension.

=head2 sql

sql which should be used to give the data to R. this require an
working ODBC.

=head2 no_sql_elements

the number of elements which come back from the sql. this is needed to
decide the number of elements in the graph.

=head2 odbc_line

give the database name and the user to R. PostgreSQL should be work
out of the box. Microsoft SQL_Server need adoption on line 108. other
db engines are not tested so far.

=head2 microsoft_sql_server

set to 'yes' or something unlike 'no' if you use the Microsoft
SQL-server via ODBC (TDS driver (Sybase/MS SQL)).

=head2 data

give the real data as one arrayreference for one column. (there are
some problems if the number of elements are real big, because the
linelength in R is limited. this need an spliting and merging on
different lines use the 'c' operator to the same name)

=head2 chart_type

more than two lines are possible and also second y axis. in the last
case only two lines with the same x levels possible.

all type arguments from R high level plotting function

=head3 p

plot individual points.

=head3 l

plot lines.

=head3 b

plot points connected by lines.

=head3 o

plot points overlaid by lines.

=head3 h

plot vertical lines from points to the zero axis (high-density)

=head3 s or S

stepfunction plots. first the top of the vertical defines the point
else the bottom.

=head3 piechart

plot a rainbow piechart. only one dataline are possible.

=head3 barplot

plot an barplot. need two dataelements, first are traits, second
grouping. calculate and print the mean of traits.

=head3 barplot_lines

add an line to the barchart. the x values for the lines have to be
part of the x values from the barchart. also for simple barplots
without lines.

=head3 barcount

plot an barplot. represent the counts for levels. additional the
percentage of all records will be plotted. need one dataline.

=head3 histogramm

plot an combined histogramm. only one dataline possible. (originally
used to understand the functionality to combine more charts on R).

=head3 boxplot

plot boxplot plus means. two datalines needed, first trait, second
grouping.

=head2 chart_type2

so far only lineplots here available. all possibilitys from R type
argument (see chart_type).

=head2 range

given range for ylim. for calculating from data use 'min' or 'max' on
one position.

=head2 range2

given range for ylim on scale 2. for calculating from data use 'min' or
'max' on one position.


=head2 export_format

the export format could be all formats which are possible by
ImageMagick. mostly used are 'pdf' or 'png' for web use. originally R
produce postscript.

=head2 legend

if a legend is needed here define the elements for each line inside an
array.

the position of the legend inside the chart are sometimes not so
good. here is an generic algorithm needed to beautify this! :-(

=head2 legendpos

define the positon of the label manually. two elements needed:
[ left|center|right, top|center|bottom ].

=head2 second_y_axis

'yes' or 'no'. this describe the need of an second y axis for lineplots.

=head2 title

the title of the graph. normaly centered on top.

=head2 subtitel

subtitel of the graph. normaly centered on bottom.

=head2 xlabel

the description of the x axis.

=head2 ylabel

the description of the y axis.

=head2 mtext_l

here can be added aditional text on the left side. placed on top left
of the chart. here used to describe the meaning of the first y axis
for lineplots if there is a second.

=head2 mtext_r

here can be added aditional text on the right side. placed on top right
of the chart. here used to describe the meaning of the second y axis
for lineplots.

=head2 colors

if the chart should be an colored one. this option is only on some
combinations usefull. (need more adoption).

=head2 x_dates

have to be used if the values on the x-axis real dates, else R
interpret the dates as strings. the dates must be 'yyyy-mm-dd'(?). this is
a little bit tricky and not generic.... :-(

=head1 EXAMPLE

 my %parameter_hash = (
		       filename => $breeder,
		       data => [ \@dat_y, \@dat_e, \@dat_f_y, \@dat_f_e],
		       second_y_axis => 'no',
		       export_format => 'pdf',
		       chart_type => 'barplot_lines',
		       chart_type2 => 'b',
                       range       => [ 0, max ],
                       range2      => [ min, 100 ],
		       legend        => ['whole population', "breeder: $out_breeder"],
		       legendpos     => ['right', 'bottom'],
		       titel      => '"BLUE values of effect ' . $effect_class . '"',
		       subtitel   => '"' . $out_breeder . '"',
		       xlabel     => '"Timeaxis"',
	               ylabel     => '"BLUE"',
		       mtext_l    => '', # additional text
	               mtext_r    => '',
		       color      => 'yes',
		       x_dates    => 'no'
		       );

 $outfilename = r_plot( %parameter_hash );

 # possible use with LaTeX
   open ( $breeder, ">>$breeder" );
   print $breeder "\\subsection{Trait: $out_trait}\n\n";
   print $breeder "\\includegraphics[width= 150mm]{$args{ filename }} \n\n";
   close ( $breeder );

=head1 ToDo

long data possible for all direct data include or use reading from
file.

nice position for legend

more flexible charts :-)

=cut

#
1;

__END__
ok:
barcount (1)
boxplot (2)... trait + grouping
histogramm (1)
barplot (2)... trait + grouping
piechart (2)... names + counts!!! (keine lehren werte!!!)
