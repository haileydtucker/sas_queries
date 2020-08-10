	/******************************************************************/
	/* This macro subsets the current table and compares it to the    */
	/* orginal_table that was created before Delete Adjustment was    */
	/* attempted to be made. Great example of nested for loops.       */
	/*Hailey Tucker, 07/2020                                          */
	/******************************************************************/


options mprint mlogic symbolgen;

%macro ifrs17_delete_check(slam_lasr_library_name=SAS SLAM LASR ($rgfstm::perspectiveVersion),
    outdir=$main::basepath/log/out_17, table_name=custom_sl_journal_flat, testdir=$main::basepath/test_files,
    ICG_code = , ICG_code_short = ,  EOP_check = N, delete = N);
    %rsk_mkdirs_and_verify(&outdir.);
    %rsk_mkdirs_and_verify(&testdir.);

    libname SLAMLSR meta liburi = "SASLibrary?@name='&slam_lasr_library_name'" metaout=data;
    libname out "&outdir";
    libname test "&testdir";

    %if &EOP_check = N
        %then %do;
    /*Keeping rows from current table where the TK is in original table*/
    /*The table generated should be the same as original if no rows were deleted*/
    proc sql;
        create table test.updated_&ICG_code_short as
		select min(ACCOUNTING_EVENT_TK) as ACCOUNTING_EVENT_TK, ASOFDATE, GL_ACCOUNT_ID, INSURANCE_CONTRACT_GROUP_ID from SLAMLSR.&table_name
        where INSURANCE_CONTRACT_GROUP_ID contains &ICG_code;
        quit;
    %end;
    %else %do;
    proc sql;
        create table test.updated_&ICG_code_short as
		select min(ACCOUNTING_EVENT_TK) as ACCOUNTING_EVENT_TK, ASOFDATE, GL_ACCOUNT_ID, INSURANCE_CONTRACT_GROUP_ID from SLAMLSR.&table_name
        where INSURANCE_CONTRACT_GROUP_ID contains &ICG_code and ENTRY_TYPE_CD = "ERECLASS";
        quit;
    %end;

    /*Extracting number of observations in the original_table for ICG Code*/
	proc sql noprint;
        create table result_&ICG_code_short
        as select * from test.orig_&ICG_code_short;
        %let orig_obs=&sqlobs;
    quit;

    /*Extracting number of observations in the new table to compare to original for ICG Code*/
    proc sql noprint;
        create table result_&ICG_code_short
        as select * from test.updated_&ICG_code_short;
        %let updated_obs=&sqlobs;
    quit;

    %if &delete = 'N'
       %then %do; /*when this is uncommented the cycle hangs*/
        %if &orig_obs = &updated_obs
        %then %do;
            %put --------------------------------------------------------;
            %put TEST_PASSES: NO ENTRIES WERE DELETED;
            %put --------------------------------------------------------;
            %end;
        %else %do;
           proc export data=updated_&ICG_code_short dbms=csv
                           outfile="&outdir/updated_&ICG_code_short..csv"
                           replace;
                       run;
           proc export data=test.orig_&ICG_code_short dbms=csv
                           outfile="&outdir/orig_&ICG_code_short..csv"
                           replace;
                       run;
           %put ERROR: Entries were deleted for &ICG_code;
           %put ------------------------------;
           %put Unexpected results indicating that entries were deleted;
           %put Check updated_&ICG_code_short and orig_&ICG_code_short in out_17 to see what &ICG_code entries were deleted;
           %put ------------------------------;
           %end;
      %end;
    %else %do;
        %if &orig_obs = &updated_obs
        %then %do;
                   proc export data=updated_table_&ICG_code_short dbms=csv
                                   outfile="&outdir/updated_&ICG_code_short..csv"
                                   replace;
                               run;
                   proc export data=test.orig_&ICG_code_short dbms=csv
                                   outfile="&outdir/orig_&ICG_code_short..csv"
                                   replace;
                               run;
                   %put ERROR: Entries were not deleted for &ICG_code;
                   %put ------------------------------;
                   %put Unexpected results indicating that entries were not deleted;
                   %put Check updated_&ICG_code_short and orig_&ICG_code_short in out_17 to see what &ICG_code entries exist that should have been deleted;
                   %put ------------------------------;
             %end;
        %else %do;
            %put --------------------------------------------------------;
            %put TEST_PASSES: CORRECT ENTRIES WERE DELETED;
            %put --------------------------------------------------------;
           %end;
     %end;

%mend;
