/* xxfamovrpt.p - Asset Movement Report at Assets Costs or                   *
 *                       Accumulated Depreciation.                           *
 *  Q. Hua 2001                                                              *
 * FAWineProj   - Fixed Assets Fix and Enhancements                          *
 *                Mod by CRP 4/06/04 to fix problems mentioned on item #1 of *
 *                Mark Weightman's specifications dated 27 May 2004 via email*
 * (CP01) Reconcile with totals with 32.5.14 15/6/04  (CP01)                 */
 /* CFP0171 ARM 16/11/05 Fix progress error msg                              */
 /* CFP0322 16/11/05 - Migrate correct version to CFP - domain check         *
 *  27/03/2010 CJ - Reworked this to allow this program and xxfamovext.p to  *
 *                  use xxfamovprc.p for internal processing                 *
 *  02/07/2010 CJ - Mods to add output directories using Standard Table      *
 *  09/08/2010 CJ - Mods on output directory processing                      *
 *  23/08/2010 CJ - Add TAX1 book to processing                              */

{mfdtitle.i}

def new shared var entity      like fa_entity   label "Entity".
def new shared var entity1     like fa_entity   label "To".
def new shared var asset       like fab_fa_id   label "Asset".
def new shared var asset1      like fab_fa_id   label "To".
def new shared var cls         like fa_facls_id label "Class".
def new shared var cls1        like fa_facls_id label "To".
def new shared var assacc      like faba_acct   label "Asset Account".
def new shared var assacc1     like faba_acct   label "To".
def new shared var depacc      like ast_ac_acct label "Accum Depn Account".
def new shared var depacc1     like ast_ac_acct label "To".
def new shared var method      like fab_famt_id label "Method".
def new shared var method1     like fab_famt_id label "To".
def new shared var pass_domain like fa_domain.
def new shared var pass_book   like fabk_id.
def new shared var start_per   like fabd_yrper.
def new shared var end_per     like fabd_yrper.
def new shared var prev_per    like fabd_yrper.
def new shared var v_startdt   like fa_startdt label 'Date' init today.
def new shared var v_enddt     like fa_startdt label 'To'   init today. 
def new shared var fisc_yr     as char format "x(4)".
def new shared var fisc_per    as char format "x(2)".
def new shared var rpttype     as char init "Report".

def new shared temp-table t_famov
    field famov_domain             like fa_domain
    field famov_entity             like fa_entity
    field famov_fabk_id            like fabk_id
    field famov_fa_id              like fa_id
    field famov_fa_desc            like fa_desc1
    field famov_startdt            like fa_startdt
    field famov_disp_dt            like fa_disp_dt
    field famov_chr01              like fa__chr01
    field famov_chr02              like fa__chr02
    field famov_chr03              like fa__chr03
    field famov_chr04              like fa__chr04
    field famov_startyr            as char
    field famov_loadyr             as char
    field famov_transper           as char
    field famov_tr_entity_fr       like fa_entity
    field famov_tr_entity_to       like fa_entity
    field famov_dateloaded         like fa__dte01
    field famov_dep_method         like fab_famt_id
    field famov_dep_type           like famt_type
    field famov_dep_life           like fab_life
    field famov_facls_id           like facls_id
    field famov_facls_desc         like facls_desc
    field famov_ast_acct           like faba_acct
    field famov_ast_acct_desc      like ac_desc
    field famov_ast_sub            like faba_sub
    field famov_dep_acct           like faba_acct
    field famov_dep_acct_desc      like ac_desc
    field famov_acc_dep_sub        like faba_sub
    field famov_per_dep_acct       like faba_acct
    field famov_per_dep_sub        like faba_sub
    field famov_per_dep_cc         like faba_cc
    field famov_op_wdv             like fa_puramt
    field famov_cl_wdv             like fa_puramt
    field famov_op_bkcost          like fab_amt
    field famov_additions          like fa_puramt
    field famov_additions_u        like fa_puramt
    field famov_additions_o        like fa_puramt
    field famov_disposals          like fa_puramt
    field famov_cl_bkcost          like fab_amt
    field famov_op_accum_depn      like fa_puramt
    field famov_start_dep          like fa_puramt
    field famov_start_dep_3        like fa_puramt
    field famov_start_dep_1_5      like fa_puramt
    field famov_adds_dep           like fa_puramt
    field famov_disp_dep           like fa_puramt
    field famov_cl_accum_depn      like fa_puramt
    field famov_costAmt            like fabd_peramt
    field famov_proc_on_disp       like fa_dispamt
    field famov_in_vAccumDepBk     like fabd_accamt
    field famov_in_costAmt         like fabd_peramt
    field famov_out_vAccumDepBk    like fabd_accamt
    field famov_out_costAmt        like fabd_peramt
    field famov_vAccumDepBk        like fabd_accamt
    index f_idx1 is primary
	famov_domain 
	famov_fabk_id 
	famov_entity 
	famov_chr04 
	famov_ast_sub 
	famov_fa_id 
    .

define variable cyc_domain   as char init "LNAU,LNNZ,LNUS" no-undo.
define variable cyc_book     as char init "BOOK,TAX,KIRN,TAX1" no-undo.
define variable vSubCode     as char          no-undo.
define variable book         like fabk_id     no-undo.
define variable vClEntity    like fabd_entity no-undo.
define variable vrowid       as  rowid        no-undo.  
define variable vNewEntity   like fabd_entity no-undo.  
define variable vLastYrper   like fabd_yrper  no-undo.  
define variable vTransper    like fabd_yrper  no-undo.  
define variable l_error      like mfc_logical no-undo.
define variable vEntityChg   as char format "x(10)" no-undo.
define variable vSvcYr       as char          no-undo.
define variable vSvcDt       like fa_startdt  no-undo.
define variable vLddYr       as char          no-undo.
define variable perDate      like fabd_yrper format "x(7)" no-undo.
define variable costAmt      like fabd_peramt no-undo.
define variable vAccumDepBk  like fabd_accamt no-undo.     
define variable total_in_costAmt like fabd_peramt no-undo.
define variable total_in_vAccumDepBk  like fabd_accamt no-undo.     
define variable total_out_costAmt like fabd_peramt no-undo.
define variable total_out_vAccumDepBk  like fabd_accamt no-undo.     
define variable accDepr like fabd_accamt no-undo.
define variable vFirstAssetDep like fabd_accamt no-undo.
define variable netBook like fabd_peramt no-undo.
define variable vBegYear     like fabd_yrper  no-undo.     
define variable vBegPeriod   like fabd_yrper  no-undo.    

def var v_report as char view-as radio-set vertical
    radio-buttons 'Asset Cost Report Summary'                , 'cost',
                  'Asset Accm Depn Report Summary'           , 'acc dep',
                  'Asset Cost And Accum Depn Report Detail'  , 'detail'
label 'Report Type' no-undo.

def var dest        as char format "x"     init "R".
def var file        as char format "x(50)" label 'Output File'. 

def var v_cost      as decimal format "->,>>>,>>9.99".
def var tot_peramt  as decimal format "->,>>>,>>9.99".
def var tot_dispamt as decimal format "->,>>>,>>9.99".
def var closebal    as decimal format "->,>>>,>>9.99".
def var openwdv     as decimal format "->,>>>,>>9.99".
def var closewdv    as decimal format "->,>>>,>>9.99".
def var tot_dep     as decimal format "->,>>>,>>9.99".
def var add_dep     as decimal format "->,>>>,>>9.99".
def var v_acc_dep   as decimal format "->,>>>,>>9.99".
def var stdepn      as decimal format "->,>>>,>>9.99".  /* depn at start */
def var disprev     as decimal format "->,>>>,>>9.99".  /* depn rev on dis */
def var clsdepn     as decimal format "->,>>>,>>9.99".  /* close bal */
def var asseta      as char.
def var accumacc    as char.
def var assetdec    as char    format "x(20)".
def var accumdec    as char    format "x(20)".
def var depn        as char.
def var depndesc    as char.
def var v_amt       as dec.                                 /*CP01*/
def var v_prevper   as int.
def var v_glseq     like faba_glseq  no-undo.              /*CP01*/
def var i           as int.
def var j           as int.

def buffer b_t_famov for t_famov.

def var sub_op_bkcost like fab_amt.
def var sub_additions like fa_puramt.
def var sub_disposals like fa_puramt.
def var sub_cl_bkcost like fab_amt.

def var sub_op_accum_depn like fa_puramt.
def var sub_start_dep     like fa_puramt.
def var sub_adds_dep      like fa_puramt.
def var sub_disp_dep      like fa_puramt.
def var sub_cl_accum_depn like fa_puramt.

def var total_op_wdv like fab_amt.
def var total_cl_wdv like fab_amt.

def var total_op_bkcost like fab_amt.
def var total_additions like fa_puramt.
def var total_additions_o like fa_puramt.
def var total_additions_u like fa_puramt.
def var total_disposals like fa_puramt.
def var total_cl_bkcost like fab_amt.
def var total_proc_on_disp like fa_dispamt.

def var total_op_accum_depn like fa_puramt.
def var total_start_dep     like fa_puramt.
def var total_start_dep_3   like fa_puramt.
def var total_start_dep_1_5 like fa_puramt.
def var total_adds_dep      like fa_puramt.
def var total_disp_dep      like fa_puramt.
def var total_cl_accum_depn like fa_puramt.

define buffer b-fabd_det for fabd_det.                      /* AM02 */
define buffer b1-fabd_det for fabd_det.
def stream outfile.

find first fab_det where fab_domain = global_domain no-lock no-error.
if  available fab_det 
then book = fab_fabk_id.

/* find the first entity the user can access */
find first code_mstr where 
			code_domain = global_domain
		    and code_value = global_userid 
	    no-lock no-error.
if  available code_mstr 
then do:
    if  code_cmmt begins '*' 
    then do: 
        find first en_mstr where en_domain = global_domain no-lock no-error.
        assign 
	    entity  = en_entity
            entity1 = en_entity
	    .
    end.
    else assign 
	    entity  = substring(code_cmmt,1,4)
	    entity1 = substring(code_cmmt,1,4)
	    .
end. /* available code_mstr */

mainloop: 
repeat on endkey undo, return:

    /* clear temp-table */
    for each t_famov:
        delete t_famov.
    end.
    
    update
        start_per colon 20  end_per  label "To" colon 45
        entity    colon 20  entity1  colon 45
        book      colon 20
        asset     colon 20  asset1   colon 45
        cls       colon 20  cls1     colon 45
        assacc    colon 20  assacc1  colon 45
        depacc    colon 20  depacc1  colon 45
        method    colon 20  method1  colon 45
        skip(1)
        v_report colon 20
        skip(1)
    with frame a side-labels.
    
    update 
        v_report help 'Choose a report to process.' colon 20 skip
    with frame a.
    
    if  v_report = 'detail' 
    then message 'The report is too large and will be outputted to a file.'.
    
    vSubCode = "FAS_FAM_Report".
    {gprun.i ""xxstdtabgt.p"" "(""OUTPUT"", vSubCode, output file)"}
    file =  if  file = "" 
	    then "/tmp/" + vSubCode + "_" + trim(global_domain) + ".csv"
	    else file + vSubCode + "_" + trim(global_domain) + ".csv" 
	    .

    do transaction:
    
        update 
           file 
           help 'Enter the file name the report will be outputted to.' colon 20 
           skip(1) 
        with frame a.
    
        if  file = '' 
        and v_report = 'detail' 
        then do: 
            {mfmsg.i 40 3}
            undo, retry.
        end.
    
    end. /* do transaction */
    
    if  file <> '' 
    then output stream outfile to value(file).
    
    assign
        entity1 = hi_char when entity1 = ""
        asset1  = hi_char when asset1 = ""
        cls1    = hi_char when cls1 = ""
        assacc1 = hi_char when assacc1 = ""
        depacc1 = hi_char when depacc1 = ""
        method1 = hi_char when method1 = ""
	.
    
    bcdparm = "".
    
    {mfquoter.i start_per}
    {mfquoter.i end_per}
    {mfquoter.i entity}
    {mfquoter.i entity1}
    {mfquoter.i book}
    {mfquoter.i asset}
    {mfquoter.i asset1}
    {mfquoter.i cls}
    {mfquoter.i cls1}
    {mfquoter.i assacc}
    {mfquoter.i assacc1}
    {mfquoter.i depacc}
    {mfquoter.i depacc1}
    {mfquoter.i method}
    {mfquoter.i method1}
    {mfquoter.i file}
    {mfquoter.i v_report}
    
    {mfselbpr.i "printer" 132}
    {mfphead.i}
    
    pass_domain = global_domain.

    do j = 1 to num-entries(cyc_book):
        if  book <> ""
        and book <> entry(j,cyc_book)
        then next.
        pass_book = entry(j,cyc_book).
        {gprun.i ""xxfamovprc.p""}
    end.

    if  v_report = 'cost' 
    then do:
    
        display '*** ASSET COST REPORT SUMMARY ***' skip(1)  with centered.
        put 
	    'Opening Balance'   at 69
	    'Closing Balance'   at 120
	    'Entity'            at 1
	    'Book'              at 8
	    'Class'             at 13
	    'Class Description' at 19
	    'Asset Acct'        at 40
	    'Acct Description'  at 51
	    'Assets at Cost'    at 70
	    'Additions'         at 92
	    'Disposals'         at 109
	    'Assets at Cost'    at 121 
	    skip
	    '------'               at 1
	    '----'                 at 8
	    '-----'                at 13
	    '--------------------' at 19
	    '----------'           at 40
	    '----------------'     at 51
	    '----------------'     at 68
	    '----------------'     at 85
	    '----------------'     at 102
	    '----------------'     at 119
	    skip
	    .
    
        if  file <> '' 
        then put stream outfile 
	      '*** ASSET COST REPORT SUMMARY ***' skip(1)
	      'Entity,Book,Class,Class Description,Asset Acct,Acct Description,'
	      'Opening Balance Assets at Cost,Additions,Disposals,'
	      'Closing Balance Assets at Cost' skip
	      '------,----,-----,-----------------,----------,----------------,'
	      '---------------,---------,---------,'
	      '---------------' 
	      skip
	      .
    
        for each t_famov no-lock 
	        break 
	        by famov_fabk_id
	        by famov_ast_acct
	        :
    
            assign 
	        sub_op_bkcost = sub_op_bkcost + famov_op_bkcost
	        sub_additions = sub_additions + famov_additions
	        sub_disposals = sub_disposals + famov_disposals
	        sub_cl_bkcost = sub_cl_bkcost + famov_cl_bkcost
	        .
        
            if  last-of(famov_ast_acct)
            then do:
    
                put 
		    famov_entity 
		    famov_fabk_id                      at 8
		    famov_facls_id      format 'x(4)'  at 13
		    famov_facls_desc    format 'x(20)' at 19
		    famov_ast_acct                     at 40
		    famov_ast_acct_desc format 'x(16)' at 51
		    sub_op_bkcost                      at 68
		    sub_additions                      at 85
		    sub_disposals                      at 102
		    sub_cl_bkcost                      at 119
		    skip
		    .
            
                if file <> '' 
	        then put stream outfile unformatted
	                famov_entity        ','
	                famov_fabk_id       ','
	                famov_facls_id      ','
	                famov_facls_desc    ','
	                famov_ast_acct      ','
	                famov_ast_acct_desc ','
	                sub_op_bkcost       ','
	                sub_additions       ','
	                sub_disposals       ','
	                sub_cl_bkcost 
	                skip
		        .
            	
	        assign 
		    total_op_bkcost = total_op_bkcost + sub_op_bkcost
		    total_additions = total_additions + sub_additions
		    total_disposals = total_disposals + sub_disposals
		    total_cl_bkcost = total_cl_bkcost + sub_cl_bkcost
		    sub_op_bkcost = 0
		    sub_additions = 0
		    sub_disposals = 0
		    sub_cl_bkcost = 0
		    .
            
            end. /* if last-of(famov_ast_acct) */
            
        end. /* for each t_famov */ 
        
        put 
	    '================' at 68
	    '================' at 85
	    '================' at 102
	    '================' at 119
	    'TOTALS'           at 60
	    total_op_bkcost    at 68
	    total_additions    at 85
	    total_disposals    at 102
	    total_cl_bkcost    at 119
	    .
    
        if  file <> '' 
        then put stream outfile unformatted
	        ',,,,,,'
	        '================,'
	        '================,'
	        '================,'
	        '================,'
                skip
                ',,,,,'
                'TOTALS,' 
                total_op_bkcost ','  
                total_additions ','  
                total_disposals ','  
                total_cl_bkcost
	        .
    
        assign 
	    total_op_bkcost = 0
	    total_additions = 0
	    total_disposals = 0
	    total_cl_bkcost = 0
	    .
     
    end. /* cost report */
    else
    if  v_report = 'acc dep' 
    then do:
    
        display '*** ASSET ACCUMULATED DEPRECIATION REPORT SUMMARY ***' 
        skip(1)  with centered.
    
        put 
           'Opening Balance'   at 71
           'Depreciation On'   at 88
           'Depreciation On'   at 105
           'Depreciation'      at 125
           'Closing Balance'   at 139
           'Entity'            at 1
           'Book'              at 8
           'Class'             at 13
           'Class Description' at 19
           'Expense Acct'      at 40
           'Acct Description'  at 53
           'Accum Depn'        at 76
           'Assets at Start'   at 88
           'Additions'         at 111
           'On Disposals'      at 125
           'Accum Depn'        at 144
           skip
           '------'               at 1
           '----'                 at 8
           '-----'                at 13
           '--------------------' at 19
           '------------'         at 40
           '----------------'     at 53
           '----------------'     at 70
           '----------------'     at 87
           '----------------'     at 104
           '----------------'     at 121
           '----------------'     at 138
           skip.
           
        if file <> '' then 
        put stream outfile
            '*** ASSET ACCUMULATED DEPRECIATION REPORT SUMMARY ***' 
            skip
            'Entity,Book,Class,Class Description,'                 /*CP01*/
            'Expense Acct,Stat Class,Stat PFO Class,Tax Class,'
	    'Acct Description,Opening Balance Accum Depn,'
            'Depn On Assets at Start, Depn On Additions,'
            'Depn On Disposals, Closing Balance Accum Depn' 
             skip
            '------,----,-----,--------------------,'              /*CP01*/
            '------------,----------,--------------,---------,'    /*CP01*/
            '----------------,----------------,----------------,'
            '----------------,----------------,----------------,'     
            skip.
    	
        for each t_famov 
	    no-lock 
	    break 
	    by famov_fabk_id
	    by famov_dep_acct
	    :
    
	    assign 
	      sub_op_accum_depn = sub_op_accum_depn + famov_op_accum_depn
	      sub_start_dep     = sub_start_dep     + famov_start_dep
	      sub_adds_dep      = sub_adds_dep      + famov_adds_dep
	      sub_disp_dep      = sub_disp_dep      + famov_disp_dep
	      sub_cl_accum_depn = sub_cl_accum_depn + famov_cl_accum_depn
	      .
              
	    if  last-of(famov_dep_acct) 
	    then do:
	        put 
		    famov_entity
		    famov_fabk_id                      at 8
		    famov_facls_id      format 'x(4)'  at 13
		    famov_facls_desc    format 'x(20)' at 19
		    famov_dep_acct                     at 40
		    famov_dep_acct_desc format 'x(16)' at 53
		    sub_op_accum_depn                  at 70
		    sub_start_dep                      at 87
		    sub_adds_dep                       at 104
		    sub_disp_dep                       at 121
		    sub_cl_accum_depn                  at 138
		    skip
		    .
    
		if  file <> '' 
		then put stream outfile unformatted
			famov_entity        ','
			famov_fabk_id       ','
			famov_facls_id      ','
			famov_facls_desc    ','
			famov_chr01         ','                      /*CP01*/
			famov_chr02         ','                      /*CP01*/
			famov_chr03         ','                      /*CP01*/
			famov_dep_acct      ','
			famov_dep_acct_desc ','
			sub_op_accum_depn   ','
			sub_start_dep       ','
			sub_adds_dep        ','
			sub_disp_dep        ','
			sub_cl_accum_depn   ','
			skip
			.
		
		assign 
		    total_op_accum_depn = total_op_accum_depn 
					    + sub_op_accum_depn    
		    total_start_dep     = total_start_dep + sub_start_dep
		    total_adds_dep      = total_adds_dep  + sub_adds_dep
		    total_disp_dep      = total_disp_dep  + sub_disp_dep
		    total_cl_accum_depn = total_cl_accum_depn 
					    + sub_cl_accum_depn
		    sub_op_accum_depn   = 0 
		    sub_start_dep       = 0
		    sub_adds_dep        = 0
		    sub_disp_dep        = 0
		    sub_cl_accum_depn   = 0
		    .
    
	    end. /* if last-of(famov_ast_acct) */
           
	end. /* for each t_famov */
        
	put 
	    '================'  at 70
	    '================'  at 87
	    '================'  at 104
	    '================'  at 121
	    '================'  at 138
	    'TOTALS'            at 62
	    total_op_accum_depn at 70
	    total_start_dep     at 87
	    total_adds_dep      at 104
	    total_disp_dep      at 121
	    total_cl_accum_depn at 138
	    .
    
	if  file <> '' 
	then put stream outfile unformatted
	        ',,,,,,'
	        '================,' 
	        '================,' 
	        '================,' 
	        '================,' 
	        '================,' skip
	        ',,,,,'
	        'TOTALS,'           
	        total_op_accum_depn ','
	        total_start_dep     ','
	        total_adds_dep      ','
	        total_disp_dep      ','
	        total_cl_accum_depn
	        .
        
	assign 
	    total_op_accum_depn = 0
	    total_start_dep     = 0
	    total_adds_dep      = 0
	    total_disp_dep      = 0
	    total_cl_accum_depn = 0
	    .
    
    end. /* accum depn report */
    else do:
    
        put stream outfile unformatted
            '*** ASSET COST AND ACCUMULATED DEPRECIATION REPORT DETAIL ***' skip
            'Entity,Book,Asset,Asset Description,Service Book Date,'
            'Service Period,Date Loaded,Loaded Period,Transfer Period,Entity From,Entity To,'
            'Disposal Date,Class,Class Desc,Stat Class,'
            'Tax Class,Asset Acct,Asset Acct Desc,Asset Sub-Acct,'
	    'Accum Depn Acct,Accum Depn Acct Desc,Accum Depn Sub Acct,DepnExp Acct,'
	    'Depn Exp Sub Acct,Depn Exp CC,Depn Method,Depn Type,Life,Opening Balance WDV,'
	    'Closing Balance WDV,Opening Balance Assets At Cost,'
	    'Additions >$1000,Additions <=$1000,Transfer In - Cost,'
	    'Transfer Out - Cost,Disposal Cost,Closing Balance Assets At Cost,'
	    'Opening Balance Accum Depn,Depreciation Current Period - Declining Bal,'
	    'Depreciation Current Period - Straight Line,'
	    'Accum Dep to DOT-Transfer In,Accum Dep to DOT-Transfer Out,'
	    'Depn Rev On Disposals,Closing Balance Accum Depn,Proceeds on Disposal'
	    skip.
    /*
            '------,------,------,------,------,------,'
            '------,------,------,------,------,------,'
            '------,------,------,------,------,------,'
            '------,------,------,------,------,------,'
            '------,------,------,------,------,------,'
            '------,------,------,------,------,------,'
            '------,------,------,------,------,------,'
            skip.
    */
    
        for each t_famov 
		no-lock 
		break 
		by famov_domain 
		by famov_fabk_id 
		by famov_entity 
		by famov_chr04 
		by famov_ast_sub 
		by famov_fa_id
		:

            put stream outfile unformatted
                famov_entity         ','
                famov_fabk_id        ','
                famov_fa_id          ','
                famov_fa_desc        ','
                famov_startdt        ','
                famov_startyr        ','
                famov_dateloaded     ','
                famov_loadyr         ','
                famov_transper       ','
		famov_tr_entity_fr   ','
		famov_tr_entity_to   ','
                famov_disp_dt        ','
                famov_facls_id       ','
                famov_facls_desc     ','
                famov_chr01          ','                          /*CP01*/
                famov_chr03          ','                          /*CP01*/
                famov_ast_acct       ','
                famov_ast_acct_desc  ','
	        famov_ast_sub        ','
                famov_dep_acct       ','
                famov_dep_acct_desc  ','
	        famov_acc_dep_sub    ','
	        famov_per_dep_acct   ','
	        famov_per_dep_sub    ','
	        famov_per_dep_cc     ','
	        famov_dep_method     ','
                famov_dep_type       ','
                famov_dep_life       ','
                famov_op_wdv         ','
                famov_cl_wdv         ','
                famov_op_bkcost      ','
                famov_additions_o    ','
                famov_additions_u    ','
	        famov_in_costAmt     ','
	        famov_out_costAmt    ','
                famov_disposals      ','
                famov_cl_bkcost      ','
                famov_op_accum_depn  ','
                famov_start_dep_3    ','
                famov_start_dep_1_5  ','
	        famov_in_vAccumDepBk ','
	        famov_out_vAccumDepBk ','
                famov_disp_dep       ','
                famov_cl_accum_depn  ','
	        famov_proc_on_disp   
	        skip
		.  
            
            assign 
	        total_op_wdv        = total_op_wdv        + famov_op_wdv
	        total_cl_wdv        = total_cl_wdv        + famov_cl_wdv
	        total_op_bkcost     = total_op_bkcost     + famov_op_bkcost
	        total_additions     = total_additions     + famov_additions
	        total_additions_o   = total_additions_o   + famov_additions_o
	        total_additions_u   = total_additions_u   + famov_additions_u
	        total_disposals     = total_disposals     + famov_disposals
	        total_cl_bkcost     = total_cl_bkcost     + famov_cl_bkcost
	        total_op_accum_depn = total_op_accum_depn + famov_op_accum_depn
	        total_start_dep_3   = total_start_dep_3   + famov_start_dep_3
	        total_start_dep_1_5 = total_start_dep_1_5 + famov_start_dep_1_5
	        total_adds_dep      = total_adds_dep      + famov_adds_dep
	        total_disp_dep      = total_disp_dep      + famov_disp_dep
	        total_cl_accum_depn = total_cl_accum_depn + famov_cl_accum_depn
	        total_out_costAmt     = total_out_costAmt + famov_out_costAmt
	        total_out_vAccumDepBk = total_out_vAccumDepBk + famov_out_vAccumDepBk
	        total_in_costAmt      = total_in_costAmt + famov_in_costAmt
	        total_in_vAccumDepBk  = total_in_vAccumDepBk + famov_in_vAccumDepBk
	        total_proc_on_disp  = total_proc_on_disp + famov_proc_on_disp
	        .
                   
        end. /* for each t_famov */
    
        put stream outfile unformatted
            ',,,,,,,,,,,,,,,,,,,,,,,,,,,'                            /*CP01*/
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,'
            '================,' skip
            ',,,,,,,,,,,,,,,,,,,,,,,,,,,' 
            'TOTALS,'
            total_op_wdv         ',' 
            total_cl_wdv         ','
            total_op_bkcost      ','
            total_additions_o    ','
            total_additions_u    ','
	    total_in_costAmt     ','
	    total_out_costAmt    ','
            total_disposals      ','
            total_cl_bkcost      ','
            total_op_accum_depn  ','
            total_start_dep_3    ','
            total_start_dep_1_5  ','
	    total_in_vAccumDepBk ','
	    total_out_vAccumDepBk ','
            total_disp_dep       ','
            total_cl_accum_depn  ','
            total_proc_on_disp   
	    .
        
        assign 
           total_op_wdv          = 0
           total_cl_wdv          = 0
           total_op_bkcost       = 0
           total_additions       = 0
           total_additions_o     = 0
           total_additions_u     = 0
           total_disposals       = 0
           total_cl_bkcost       = 0
           total_op_accum_depn   = 0
           total_start_dep       = 0
           total_start_dep_3     = 0
           total_start_dep_1_5   = 0
           total_adds_dep        = 0
           total_disp_dep        = 0
           total_cl_accum_depn   = 0
           total_proc_on_disp    = 0
           total_in_costAmt      = 0
           total_in_vAccumDepBk  = 0
           total_out_costAmt     = 0
           total_out_vAccumDepBk = 0
           .
    
    end. /* detail report (show all) */
    
    put stream outfile unformatted
        skip(2)
        '===================================================================='
        skip
        '===================================================================='
        skip
        "Period:,From:," start_per ",To:," end_per
        skip
        "Entity:,From:," entity ",To:," entity1 
        skip
        "Book:,From:," book ",To:," book 
        skip
        "Asset:,From:," asset ",To:," asset1
        skip
        "Class:,From:," cls ",To:," cls1
        skip
        "Asset Account:,From:," assacc ",To:," assacc1
        skip
        "Accum Depn Account:,From:," depacc ",To:," depacc1
        skip
        "Forecast Method:,From:," method ",To:," method1
        skip(2)
        .
    
    output stream outfile close.

    {mfrtrail.i}
    
end. /* repeat, mainloop */
        
