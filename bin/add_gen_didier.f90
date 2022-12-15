program parente 
  ! program from Didier Boichard
  ! converted to f90 from EG
  ! also, here only male x female (or group 1 x group 2 are computed)
  ! add_gen_didier pedfile, subsetfile, outfile, n-animals
  ! the dimensions below have been included in the source and fixed. 
  ! on virtual machines it should not do any harm and should be large
  ! enough for most cases.
  ! gfortran can be used to compile it:
  ! gfortran -O3 add_gen_didier.f90 -static -o add_gen_didier
  ! gfortran -static -m32 -ffast-math -funroll-loops -ftree-loop-linear -ftree-vectorize -msse3 -O3 -o add_gen_didier add_gen_didier.f90

  ! this binary should run on all Linux i386 machines.
  implicit none 

  ! dimension
  integer nt,ande,anfi,ng,pran,dean,nam,nelva,nlistx,nimp,nig
  character*20 totanim
  !     parameter (nt=2700000)               ! tous / all
  parameter (nimp=1000)                 ! prob_orig
  parameter (ande=1960,anfi=2010)       ! intgen
  parameter (ng=30,nig=-30)             ! etr,ngen / vanrad
  parameter (pran=1901,dean=2010)       ! etr
  parameter (nam=4000,nelva=10000)      ! par, parente
  !     parameter (nlistx=2700000)            ! par2,par3
  !     include "blk.incl" 
  integer*4 i, j, k, n,ii,jj,kk,is,il,ne,eff,iopt(4),na,ie,ip,im 
  integer*4 je,nd,nlist(2),iad,iaf,ifail,ig,ig1,ig2 ,status
  character*128 str,sti,stc,jour, pedfile, datfile, outfile

  integer*4, allocatable :: lliste(:,:)
  !     integer*4 lliste(nlistx,2) 
  integer*4, allocatable :: pere(:),mere(:),ped(:,:),point(:)
  integer*2, allocatable :: sex (:), annai(:)
  !     integer*4 pere(nt),mere(nt),ped(2,nt), point(nt) 
  integer*4, allocatable :: ord(:),rord(:),id(:),ic(:),ndes(:)
  !     integer*2 sex(nt),annai(nt) 
  !     integer*4 ord(nt),rord(nt),id(nt),ic(nt),ndes(nt) 
  real*8 statis(106),x 
  !     real*8 f(0:nt),l(nt),d(nt) 
  real*8, allocatable :: f(:),l(:),d(:)
  logical ts,ts2(2,2),chy 

  !     include "formaten.incl" 
  !     include "add_gen_didier.incl" 
  !Eildert Groenveld 1504 END                                           
  ! pick up parameters:
  i = iargc ()
  if (i.ne.4 ) then
     print *,'add_gen_didier Pedfile, subsetfile, outfile, # animals'
     stop
  endif

  call getarg (1,pedfile) ; str = pedfile
  call getarg (2,datfile) ; sti = datfile
  call getarg (3,outfile) ; stc = outfile
  call getarg (4,totanim) ; read (totanim,*) nt; nlistx = nt
 
  ! somehow we need n+1:
  nt = nt + 1

  open (3,file=stc,form='formatted') ! list output file

  allocate (lliste (nlistx,2),                      stat=status)
  allocate (pere(nt),mere(nt),ped(2,nt), point(nt), stat=status)
  allocate (sex(nt),annai(nt),                      stat=status)
  allocate (ord(0:nt),rord(0:nt),id(nt),ic(nt),ndes(nt),stat=status)
  allocate (f(0:nt),l(nt),d(nt),                    stat=status) 

  call fdate(jour) 
  !     PRINT 990,jour 
  !     print 8001 
  !     print 1001 
  !     read(5,*) str 
  !     print 1002,str 

  !     print 8501 
  !     read (5,*) sti 
  !     print 8502,sti 

  !     print 1003 
  !     print *,'no if no output file' 
  !     read (5,*) stc 
  !     print 1004,stc 
  ts=.true. 
  if (stc.eq.'no') ts=.false. 
  do i=1, 2 
     do j=1, 2 
        ts2(i,j)=ts 
     end do
  end do

  nlist(1)=0 
  nlist(2)=0 
  open (9,file=sti,form='formatted') 
18 read (9,*,end=19) i,ii 
  if (ii.lt.1.or.ii.gt.2) then 
     write (3, 8004) i,ii 
     ! print 8004,i,ii 
     stop 
  end if
  nlist(ii)=nlist(ii)+1 
  if (i.lt.1) stop 'number < 1 in the list' 
  if (nlist(ii).gt.nlistx)                                        &
       &    stop 'Increase the last parameter in the calling list!'  
  lliste(nlist(ii),ii)=i 
  goto 18 
19 close (9) 

  if (nlist(2).eq.0) then 
     write(3, 8005) nlist(1) 
  else 
     write(3, 8006) nlist(1) 
     write(3, 8007)nlist(2) 
     !       print 8006,nlist(1) 
     !       print 8007,nlist(2) 
  end if

  ! limitation of output ?????????????                                                  
  do i=1, 2 
     do j=1, 2 
        if (nlist(i)*nlist(j).gt.1000000) ts2(i,j)=.false. 
     end do
  end do


  ! lecture du pedigree                                                   
  n=0 
  chy=.false. 
  open (1,file=str,form='FORMATTED') 

1 read (1,*,end=2) i,j,k,jj,is 
  n=n+1 
  if (jj.le.11) then 
     jj=jj+2000 
     chy=.true. 
  else if (jj.le.100) then 
     jj=jj+1900 
     chy=.true. 
  end if
  if (i.ne.n) then 
     ! print 102,n,i 
     write (3, 102) n,i 
     stop 
  end if
  if (i.gt.nt.or.j.gt.nt.or.k.gt.nt) then 
     write (3, 101) nt,i,j,k
     !print 101 
     stop 
  end if
  pere(n)=j 
  mere(n)=k 
  if (j.lt.0) pere(n)=0 
  if (k.lt.0) mere(n)=0 
  annai (n)=jj 
  sex   (n)=is 
  goto 1 

2 if (chy) write (3, 103) 
  write (3, 900) n 
  close(1) 


  do ig=1, 2 
     do i=1, nlist(ig) 
        if (lliste(i,ig).gt.n) then 
           write (3, 8512) lliste(i,ig) 
           stop 
        end if
     end do
  end do
  do i=1, n 
     if (pere(i).gt.n) then ; write (3, 8513); stop; end if 
        if (mere(i).gt.n) then ; write (3, 8514); stop; end if 
        end do 

        ! *** renumerotation du plus vieux au plus jeune                        
        call comp_d (n, pere, mere, ped, ord, rord) 

        do ig=1, 2 
           do i=1, nlist(ig) 
              ndes(ord(lliste(i,ig)))=1 
           end do
        end do

        do i=1,n 
           point(i)=0 
           l(i)=0. 
           d(i)=0. 
        end do

        call meuw(n, ped, f, d, l, point,ndes) 

        if (ts) then 
           !open (3,file=stc,form='formatted') 
           do ig=1, 2 
              do i=1, nlist(ig) 
                 j=lliste(i,ig) 
                 !          if (ts2(ig,ig)) write (3,8888) j,j,f(ord(j)),ig,ig 
              end do
           end do
        end if
8888    format (2i8,f7.4,2i2) 

        n=n + 1 
        do i=1, n 
           point(i)=0 
           l(i)=0. 
        end do

        do ig1=1, 2 
           do ig2=ig1, 2 
              call statt(x,statis,0) 
              write (3,'('' '')') 
              write (3, '(''Groups '',I12,'' x '',I12)') ig1,ig2 
              write (3, '(''****************'')')
              !! EG to speed up computation
              if (ig1.ne.ig2) then! do only male x female
                 do i=1,nlist(ig1) 
                    ii=1 
                    if (ig1.eq.ig2) ii=i+1 
                    do j=ii, nlist(ig2) 
                       ip=ord(lliste(i,ig1)) 
                       im=ord(lliste(j,ig2)) 
                       ped(1,n)=ip 
                       ped(2,n)=im 
                       call consang(n,ped,f,d,l,point) 
                       !          if (ts2(ig1,ig2)) write (3,8888) lliste(i,ig1),              &
                       !    &      lliste(j,ig2),f(n),ig1,ig2                                  
                       call statt(f(n),statis,1) 
                    end do
                 end do
              end if
              call statt(x,statis,2) 
           end do
        end do

        call fdate(jour) 
        write (3, 991) jour 
        if (ts) close(3) 

101     format (///'Animal, sire or dam Id larger than parameter NT '/    &
             &           ' If Ids are correct, increase NT (Parameter 4) ',        &
             &           4I12)                          
102     format (///'Animals are not recoded sequentially ',               &
             &           'or the file not sorted'/                              &
             &           ' Check row ',i8,' and animal ',i8)                    
103     format (///'Some birth year were found to be less than 100'/      &
             &        'They were recoded with the following rules : '/          &
             &        '  2000 was added to values < 11'/                        &
             &        '  1900 was added to values > 10 and <100'/               &
             &        '  Values > 100 were unchanged')                          

900     format (///' Number of individuals : ',i8) 
903     format ('Sex, first and last birth year ',                        &
             &        'of the reference population')                            
910     format (' Size of reference population : ', i8) 
911     format (' Reference population is empty !!!') 
990     format ('Date and time of start : ',a128) 
991     format (/'Date and time of end : ',a128) 
1000    format ('            External Origins'/                           &
             &        '            ****************')                           
1001    format (//'Type name of pedigree file') 
1002    format ('Input file :',a128) 
1003    format (/'Type name of output file') 
1004    format ('Output file :',a128) 
1101    format (' Origins      : ',i8) 
1102    format (///' Initial Values'/                                     &
             &           ' **************')                                     
1104    format (' Errors in pedigree file : ',i8) 
1200    format (///'    Females '/                                       &
             &            '    ******* '/                                       &
             &            'Year       N ',10i6)                                 
1210    format (///'    Males'/                                          &
             &            '    ********** '/                                    &
             &            'Year       N ',10i6)                                 
2000    format (//'         Generation Intervals'/                        &
             &          '         ********************')                        
2100    format (/'             ALL PROGENY '                              &
             &        /'             ***********')                              
2110    format (/'             REPRODUCING PROGENY'                       &
             &        /'             *******************')                      
2120    format (/'             REPRODUCERS with MORE than 30 PROGENY '    &
             &        /'             *************************************')    
2105    format (/'**************************************************',    &
             & '****************************'                                   &
             &        /'Birth                Descendants                  ',    &
             & '        Number'                                                 &
             &        /'                Males          Females             ',   &
             & 'Males          Females'                                         &
             &        /'Year         Sire    Dam      Sire    Dam        ',     &
             & 'Sire    Dam      Sire    Dam'                                   &
             &        /'***************************************************',   &
             & '***************************')                                   
3000    format(/'      Inbreeding'                                        &
             &       /'  Meuwissen s Method'                                    &
             &       /'  ******************')                                   
3100    format (///'           Inbreeding Statistics'/                    &
             &           '           *********************'///                  &
             & ' Total Number of individuals             : ',i8/                &
             & ' Number of inbred individuals            : ',i8/                &
             & ' Mean inbreeding of inbred individuals   : ',f8.3/              &
             & ' Maximum inbreeding                      : ',f8.3//             &
             & '       Frequency per class')                                    
4000    format ('First and last years : ',i6) 
4001    format (' Birth year : ',i5 /                                     &
             &        ' Sex        : ',i3)                                      
4002    format ('with at least one known parent') 
4003    format ('with two known parents') 
4004    format (' Number : ',i8) 
4005    format (' Equivalent number of known generations : ',f8.2/        &
             &        ' Average number of ancestors            : ',f10.1/       &
             &         ' Generations  Fractions')                               


5001    format ('Number of replicates, ') 
5002    format (///'   Effective number of residual founder genomes'/     &
             &           '   ********************************************'///   &
             & ' Sex of reference population     : ',i6/                        &
             & ' First and last birth year       : ',2i5/                       &
             & ' Number of replicates            : ',i5)                        
5003    format (' Number of segregating genes : ',i10) 
5004    format (//' Effective number of founder genomes ' /               &
             &          ' *********************************** ')                
5005    format (//' Mean and Standard Deviation over ',i5,                &
             & ' replicates : ',2f10.2///'               Distribution' )        
5006    format (i5,i6,2x,50a1) 

6001    format ('Number of generations to be considered ? (0=all)' ) 
6002    format (i4 , ' generations considered') 
6003    format ('All generations considered') 
6004    format ('Error in the pedigree file'                              &
             &  /'Pedigree discarded for ',i8,' individuals'                    &
             &  /'sire and dam are coded -1')                                   
6006    format (//' Number of groups of founders considered : ',i4) 
6007    format (' Within group relathionship ',i3,' : ',f8.4) 
6008    format ('The individual ',i8,' has more than ',i5,'ancestors') 
6009    format ('Maximum matrix size : ',i5) 


7001    format ('Number of ancestors') 
7002    format (///'         Probabilities of gene origins'/              &
             &           '         *****************************'///            &
             & ' Number of major ancestors                  : ',i6/             &
             & ' Sex of reference population                : ',i6/             &
             & ' First and last birth year of reference population : ',2i5)     
7003    format (' Number of non parents   : ',i8) 
7005    format (' Size of reference population (known parents) : ', i8) 
7006    format (' Number of founders    : ',i8) 
7007    format (' Effective number of founders (classical approach) : ',  &
             &  f10.1)                                                          
7008    format (///                                                       &
             & '   #    Id  Sex BYear          Contributions          ',        &
             & '   Sire    Dam  #Progeny   Lower    Upper'/                     &
             & '                        total    marginal    cumulated',        &
             & '                           Bound    Bound' )                    
7009    format(i4,i8,i3,i6,f8.4,2f12.4,3i8,2f10.2) 
7010    format (//' Lower Bound : ',f10.2                                 &
             &         /' Upper Bound : ',f10.2)                                


8001    format ('       Relationship Coefficients'/                       &
             &        '       *************************'/' ')                   
8002    format ('Type file name of individuals of interest ') 
8003    format ('File of individuals of interest :',a128) 
8004    format ('Individual : ',i8,' Group ',i5,                          &
             & '   the code should be 1 or 2')                                  
8005    format ('Number of individual studied :',i8) 
8006    format ('Group 1 :',i8) 
8007    format ('Group 2 :',i8) 
8008    format ('The size of the problem ',i8,                            &
             & ' is higher than dimension (nam) ',i8)                           
8009    format ('Relationship Statistics'                                 &
             &       /'***********************')                                
8010    format (//'Group 1'/'*******') 
8011    format (  'Group 2'/'*******') 
8012    format ('Groups 1 and 2'/'**************') 
8013    format (/                                                      &
             &      ' Individual studied                 : ',i8/                &
             &      ' Number of coefficients             : ',i10/               &
             &      ' Mean coefficient                   : ',f8.3/              &
             &      ' Standard deviation of coefficients : ',f8.3///            &
             &      '                 Distribution of coefficients')            
8014    format (i3,'-',i3,'  :  ',i3,' : ',100a1) 
8015    format ('Error in pedigree coding') 
8017    format ('Individual Values'/'*****************') 
8117    format ('(zero values are omitted)') 
8018    format ('Complete matrix') 
8019    format (/'Inbreeding'/'**********') 
8020    format ('No inbreeding in group 1') 
8021    format ('No inbreeding in group 2') 
8022    format (/'Relationship'/'************') 
8023    format (/'Within group 1') 
8024    format (/'Within group 2') 
8025    format ('No relationship within group 1') 
8026    format ('No relationship within group 2') 
8027    format (/'Between groups 1 and 2') 
8028    format ('No relationship between groups 1 and 2') 

8500    format ('       Average relationship'/                            &
             &        '       ********************'/' ')                        
8501    format ('Name of file of individual to characterize ?') 
8502    format ('Name of file of individual to characterize : ',a128) 
8503    format ('Name of file of mates (no if no file) ? ') 
8504    format ('Name of file of mates : ',a128) 
8505    format ('Sampling of mates according to sex and birth year') 
8506    format(///' Type the 4 following parameters'/                  &
             &        '  1: Number of mates (0=all, -1=help)'/                  &
             &        '  2: Sex of mates '/                                     &
             &        '  3: First birth year '/                                 &
             &        '  4: Last birth year')                                   
8507    format ('This programme estimates the average relationship'       &
             &   /'between some individuals (usually males) considered',        &
             &    'individually'                                                &
             &   /'and a subpopulation (usually female). It requires 3 ',       &
             &    'parameters :'                                                &
             &   /'Parameter 1 determines the subpopulation'                    &
             &   /'   0 : all mates born within the period are considered'      &
             &   /'   n : a sample of n individuals is considered'              &
             &  //'Parameters 2 and 3 are the first and last birth years'       &
             &   /'  of the subpopulation of mates'                             &
             &   /'  The first birth year should be less than or equal ',       &
             &    'to the last one'                                             &
             &   /'ENJOY PEDIG ! ')                                             
8508    format(' Year coding is incorrect ') 
8509    format ('Option 1 incorrect : type 0 (=all) or a positive number') 
8510    format (/'Selection of mates'/                                    &
             & '    Number (0=all)    : ',i8/                                   &
             & '    Sex               : ',i8/                                   &
             & '    First birth year  : ',i8/                                   &
             & '    Last birth year   : ',i8)                                   
8511    format (///' Number of individuals studied : ',i8) 
8512    format ('Individual',i8,' in the list has a too high Id') 
8513    format ('Sire',i8,' has a too high Id') 
8514    format ('Dam ',i8,' has a too high Id') 
8515    format (' Number of mates       : ',i8) 
8516    format (//'    Individual ',i6,i8/                                &
             &          '    **************************')                       
8517    format (//                                                     &
             &      ' Number of coefFicients             : ',f10.0/             &
             &      ' Mean of coefficients               :   ',e16.10/            &
             &      ' Standard deviation of coefficients :   ',f8.3///          &
             &      '              Distribution of Coefficients')               
8518    format (i3,'-',i3,'  :  ',f9.0,1x,i3,' : ',100a1) 

9001    format ('       Relationship Statistics'/                         &
             &        '       ***********************'/' ')                     
9002    format(///' Type the following parameters '/                   &
             &        '  1:Option   2:First birth year'/                        &
             &        '  3:Last birth year  4: # samples  5: Sample size '//    &
             &        '   Option -1 : help'/                                    &
             &        '   Option  0 : males '/                                  &
             &        '   Option  1 : whole female population '/                &
             &        '   Option  2 : females within herd '/                    &
             &        '   Option  3 : sampling within region'/                  &
             &        '   Option  4 : sampling within each region'/             &
             &        '   Option  5 : samples of male x female couples')        
9003    format (//'    Region',i3/                                        &
             &          '    **********'//                                      &
             &          ' Population available ',i6)                            
9004    format (//                                                        &
             &      ' Number of samples                 : ',f5.0/               &
             &      ' Average sample size               : ',f8.1/               &
             &      ' Number of coefficients            : ',f10.0/              &
             &      ' Mean of coefficients              : ',f8.3/               &
             &      ' Standard deviation of coefficients: ',f8.3///             &
             &      '                Distribution of coefficients')             
9005    format (i3,'-',i3,'  :  ',f9.0,1x,i3,' : ',100a1) 
9006    format ('Number of candidates :',i8) 
9007    format ('Number of male candidates   :',i8) 
9008    format ('Number of female candidates :',i8) 
9009    format ('Number of herds   :',i8) 
9010    format ('Number of selected herds :',i8) 
9011    format ('Number of females        :',i8) 
9012    format ('Number of regions :',i8) 
9020    format(/' OPTION MALES'/                                       &
             &         ' ****************************************'/             &
             & ' Population : males born from first and last birth year')       
9021    format(/' OPTION SAMPLING WITHIN THE FEMALE POPULATION'/       &
             &         ' ***********************************************'/      &
             & ' Population : females born from first and last birth year')     
9022    format (/i5,' random samples of size ',i5) 
9023    format (' ERROR : the number of samples is incorrect'/         &
             &         ' it should be between 1 and nelva= ',i6)                
9024    format (' ERROR : the size of the samples is incorrect'/       &
             &         ' it should be between 2 and nam= ',i6)                  
9025    format(/' OPTION SAMPLING OF FEMALES WITHIN HERD'/             &
             &         ' ****************************************'/             &
             & ' Population : females born from first and last birth year'/     &
             & ' Parameter 5 is not used')                                      
9026    format ('All herds are considered') 
9027    format (i8,' herds are sampled') 
9028    format (' ERROR : number of herds incorrect'/                  &
             &         ' it should be between 0 et nelva= ',i6)                 
9030    format(/' OPTION SAMPLING OF FEMALES WITHIN REGION'/           &
             &         ' ******************************************'/           &
             & ' Population : females born from first and last birth year')     
9040    format(/' OPTION SAMPLING OF FEMALES IN EACH REGION'/           &
             &         ' ******************************************'/           &
             & ' Population : females born from first and last birth year')     
9041    format (i5,' samples per region of size ',i6) 
9050    format(/' OPTION SAMPLING OF MALE x FEMALE COUPLES '/          &
             &         ' ************************************************'/     &
             & ' Population : animals born from first and last birth year')     
9051    format (/i5,' random couples') 
9060    format (/' First birth year : ',i5/                              &
             &          ' Last birth year  : ',i5)                              
9061    format (' ERROR : First birth year larger than last birth year') 
1501    format ('This programme requires 5 parameters :'                  &
             &       /'Parametre 1 determines the population analysed '         &
             &       /'   0 : males. Sex is coded 1 in the file'                &
             &       /'   1 : females. Sex is coded 2'                          &
             &       /'   2 : females within herd'                              &
             &       /'   3 : females within region. The region is defined'     &
             &    /'by the first 2 digits of the herd Id (coded with 8 digits)' &
             &       /'This option provides one overall estimate based'         &
             &       /'on one sample per region'                                &
             &       /'   4 : females within region. One estimate per region,'  &
             &     /'if the region has a number of females at least equal to 10'&
             &       /'times the sample size'                                   &
             &       /'   5 : male x female couples. n samples of size 2')      
1502    format (/'Parameters 2 and 3 are the first and last birth years'  &
             &       /'  of the population considered'                          &
             &   /'  The first year must be less than or equal to the last year'&
             &       /'  Years include are coded with for digits (ex 1997)')    
1503    format (/'Parameter 4 is the number of samples'                   &
             &       /'  This parameter is 1 per region with option 3 '         &
             &       /'  In option 2, if it is 0, all herds are analysed.'      &
             &       /' In option 5, il is the number of couples considered')   
        stop 
        !    END if
      end program parente
      subroutine statt(x,statis,io) 
        implicit none 
        integer*4 io, nm,i,ii,j,jj,k,l 
        real*8  statis(*),x 
        character*1 etoile 

        ! include "formaten.incl" 
        include "add_gen_didier.incl" 

        if (io.eq.0) then 
           do i=1, 106 
              statis(i)=0.d0 
           end do
           return 

        else if (io.eq.1) then 
           statis(3)=statis(3) + 1.d0 
           statis(4)=statis(4) + x 
           statis(5)=statis(5) +x*x 
           k=6+int(100.d0 * x) 
           statis(k)=statis(k)+1.d0 
           return 

        else if (io.eq.2) then 
           etoile='*' 
           if (statis(3).gt.0.d0) then 
              statis(4)=statis(4)/statis(3) 
              statis(5)=statis(5) - statis(3)*statis(4)*statis(4) 
              statis(5)=dsqrt(statis(5)/statis(3)) 
           end if
           write (3, 8517) statis(3),statis(4),statis(5) 
      !    print *,'lllK',statis(3),statis(4),statis(5) 
           do i=1, 100 
              k=int(.5 + 100.*statis(5+i)/statis(3)) 
              if (statis(5+i).gt.0) write (3, 8518) i-1,i,statis(5+i),k,         &
                   &     (etoile,l=1,k)                                               
           end do
        end if
        return 
      END subroutine statt

      subroutine comp_d (n,sire, dam,ped,ord,rord) 
        implicit none 
        integer*4 n,sire(*),dam(*),ped(2,*),nbit,k,i,j,ks,kd 
        !       integer*4 ord(*), rord(*) 
        integer*4 ord(0:n),rord(0:n)

        !include "formaten.incl" 
        include "add_gen_didier.incl" 

        nbit=0 
        do i=1, n 
           ord(i)=0 
        end do
        k=0 
        do while (k.lt.n .and. nbit.le.20) 
           nbit=nbit + 1 
           do i=1, n 
              if (ord(i).eq.0) then 
                 if (sire(i).le.0 .or. ord(sire(i)).ne.0) then 
                    if (dam(i) .le.0 .or. ord( dam(i)).ne.0) then 
                       k=k+1 
                       ord(i)=k 
                       rord(k)=i 
                    end if
                 end if
              end if
           end do
           !        print *,nbit,k,n                                               
        end do

        !  Test qu'il n'y a pas de boucle dans le pedigree                      
        j=0 
        if (k.ne.n) then 
           do i=1,n 
              if (ord(i).eq.0) then 
                 j=j+1 
                 if (j.lt.100) print '(3i10)',i,sire(i),dam(i) 
                 sire(i)=0 
                 dam(i)=0 
                 k=k+1 
                 ord(i)=k 
                 rord(k)=i 
              end if
           end do
        end if
        if (j.gt.0) write (3, 900) j 

        do i=1, n 
           j=rord(i) 
           ped(1,i)=sire(j) 
           ped(2,i)=dam(j) 
           if (ped(1,i).gt.0) ped(1,i)=ord(sire(j)) 
           if (ped(2,i).gt.0) ped(2,i)=ord(dam(j)) 
        end do

        DO i=1,n 
           if (i.le.ped(1,i) .or. i.le.ped(2,i)) then 
              write (3, '(''Problem in coding pedigree'')') 
              write (3, '(3I12)') i, ped(1,i),ped(2,i) 
              stop 
           end if
           ks=ped(1,i) 
           kd=ped(2,i) 
           ped(1,i)=max(ks,kd) 
           ped(2,i)=min(ks,kd) 
        end do
        return 
      END subroutine comp_d


      !*** Methode de Meuwissen                                               
      subroutine meuw(n, ped, f, d, l ,point,ndes) 
        implicit none 
        integer*4 n, ped(2,*), point(*),ndes(*),np,npar 
        integer*4 ninbr, i, j,k, ik, is, id, ks, kd 
        real*8 f(0:n), d(*), l(*),r, fi 


        ninbr=0 
        f(0)=-1.d0 
        DO i=1,n 
           point(i)=0 
        end do
        DO i=1,n 
           if (ped(1,i).gt.0) ndes(ped(1,i))=ndes(ped(1,i))+1 
           if (ped(2,i).gt.0) ndes(ped(2,i))=ndes(ped(2,i))+1 
        end do
        npar=0 
        do i=1, n 
           if (ndes(i).gt.0) npar=npar+1 
        end do
        !      print *, 'Coefficients initiaux calcules (parents + candidats) : 
        if (npar.eq.0) return 

        DO i=1,n 
           if (ndes(i).gt.0) then 
              is=ped(1,i) 
              id=ped(2,i) 
              ped(1,i)=max(is,id) 
              ped(2,i)=min(is,id) 
              d(i)=.5d0 - .25d0*(f(is)+f(id)) 
              if (is.eq.0.or.id.eq.0) then 
                 f(i)=0.d0 
              else 
                 np=0 
                 fi=-1.d0 
                 l(i)=1.d0 
                 j=i 
                 do while(j.ne.0) 
                    k=j 
                    r=.5d0 * l(k) 
                    ks=ped(1,k) 
                    kd=ped(2,k) 
                    if (ks.gt.0) then 
                       l(ks)=l(ks) + r 
                       do while(point(k).gt.ks) 
                          k=point(k) 
                       end do
                       if (ks.ne.point(k)) then 
                          point(ks)=point(k) 
                          point(k)=ks 
                       end if
                       if (kd.gt.0) then 
                          l(kd)=l(kd) + r 
                          do while(point(k).gt.kd) 
                             k=point(k) 
                          end do
                          if (kd.ne.point(k)) then 
                             point(kd)=point(k) 
                             point(k)=kd 
                          end if
                       end if
                    end if
                    fi=fi + l(j)*l(j)*d(j) 
                    l(j)=0.d0 
                    k=j 
                    j=point(j) 
                    point(k)=0 
                    np=np+1 
                 end do
                 f(i)=fi 
                 if (fi.gt.0.000001d0) ninbr=ninbr + 1 
              end if
           end if
        end do


        !      PRINT 3000,ninbr                                                 
        ! 3000 FORMAT (' Nb de parents consanguins : ',I8)                      
        RETURN 
      END subroutine meuw

      !*** Methode de Meuwissen                                               
      subroutine consang(i, ped, f, d, l ,point) 
        implicit none 

        integer*4 ped(2,*), point(*) 
        integer*4 i, j,k, ik, is, id, ks, kd 
        real*8 f(0:i), d(*), l(*),r, fi 

        is=ped(1,i) 
        id=ped(2,i) 
        ped(1,i)=max(is,id) 
        ped(2,i)=min(is,id) 
        d(i)=.5d0 - .25d0*(f(is)+f(id)) 
        if (is.eq.0.or.id.eq.0) then 
           f(i)=0.d0 
           return 
        end if
        fi=-1.d0 
        l(i)=1.d0 
        j=i 
        do while(j.ne.0) 
           k=j 
           r=.5d0 * l(k) 
           ks=ped(1,k) 
           kd=ped(2,k) 
           if (ks.gt.0) then 
              l(ks)=l(ks) + r 
              do while(point(k).gt.ks) 
                 k=point(k) 
              end do
              if (ks.ne.point(k)) then 
                 point(ks)=point(k) 
                 point(k)=ks 
              end if
              if (kd.gt.0) then 
                 l(kd)=l(kd) + r 
                 do while(point(k).gt.kd) 
                    k=point(k) 
                 end do
                 if (kd.ne.point(k)) then 
                    point(kd)=point(k) 
                    point(k)=kd 
                 end if
              end if
           end if
           fi=fi + l(j)*l(j)*d(j) 
           l(j)=0.d0 
           k=j 
           j=point(j) 
           point(k)=0 
        end do
        f(i)=fi 

        RETURN 
      END subroutine consang
