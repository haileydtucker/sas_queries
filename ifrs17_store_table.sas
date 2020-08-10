/********************************************************************/
/* Storing custom_sl_journal_flat before Deletion Adjustments are   */
/* attempted to be made.                                            */
/* Hailey Tucker, 07/2020                                           */
/********************************************************************/

options mprint mlogic symbolgen;

%macro ifrs17_store_table(slam_lasr_library_name=SAS SLAM LASR ($rgfstm::perspectiveVersion),
table_name=custom_sl_journal_flat, testdir=$main::basepath/test_files, ICG_code = , ICG_code_short = , EOP_check = N);
    %rsk_mkdirs_and_verify(&testdir.);

    libname SLAMLSR meta liburi = "SASLibrary?@name='&slam_lasr_library_name'" metaout=data;
    libname test "&testdir";

    %if &EOP_check = N
    %then %do;
    /*Querying based on lowed tk number also corresponding to ICG ID*/
    proc sql;
        create table test.orig_&ICG_code_short as
    select min(ACCOUNTING_EVENT_TK) as ACCOUNTING_EVENT_TK, ASOFDATE, GL_ACCOUNT_ID, INSURANCE_CONTRACT_GROUP_ID from SLAMLSR.&table_name
    where INSURANCE_CONTRACT_GROUP_ID contains &ICG_code;
    %let resultcount=&sqlobs;
        quit;
    %end;
    %else %do;
    /*Querying based on lowed tk number also corresponding to ICG ID*/
    proc sql;
        create table test.orig_&ICG_code_short as
    select min(ACCOUNTING_EVENT_TK) as ACCOUNTING_EVENT_TK, ASOFDATE, GL_ACCOUNT_ID, INSURANCE_CONTRACT_GROUP_ID from SLAMLSR.&table_name
    where INSURANCE_CONTRACT_GROUP_ID contains &ICG_code and ENTRY_TYPE_CD = 'ERECLASS';
    %let resultcount=&sqlobs;
        quit;
    %end;

    /*Creating a table of just tk num (to later extract in supercase.pl) for ICG_code*/
    proc sql;
        create table test.tk_extract_&ICG_code_short as
    select ACCOUNTING_EVENT_TK from test.orig_&ICG_code_short;
        quit;

    /*Exporting to a csv so Perl can extract tk for ICG_code*/
    proc export data=test.tk_extract_&ICG_code_short dbms=csv
        outfile="&testdir/tk_extract_&ICG_code_short..csv"
        replace;
    run;

    /*Will throw error if no entries were queried*/
    %if &resultcount = 0
    %then %do;
                   %put ERROR: No entries existed for given requirements;
                   %put ------------------------------;
                   %put Unexpected results indicating that entries were deleted;
                   %put ------------------------------;
               %end;
            %else %do;
                   %put --------------------------------------------------------;
                   %put TEST_PASSES: Expected entries are available;
                   %put --------------------------------------------------------;
               %end;

%mend;