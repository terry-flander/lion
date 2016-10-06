/* Modification History
 * Date     By       Id     Desc
 * -------- -------- ------ --------------------------------------------------
 * xxfamovprc.p - Asset Movement Processing                                  *
 *                                                                           *
 *                                                                           *
 *  27/03/2010 CJ - New program to allow xxfamovext.p and xxfamovrpt.p to    *
 *                  use this program for internal processing                 *
 *  02/07/2010 CJ - Mods to add output directories using Standard Table      *
 *  09/08/2010 CJ - Mods on output directory processing                      *
 * ************************************************************************* */

{mfdtitle.i}

def shared var entity           like fa_entity   label "Entity".
def shared var entity1          like fa_entity   label "To".               
def shared var asset            like fab_fa_id   label "Asset".
def shared var asset1           like fab_fa_id   label "To".
def shared var cls              like fa_facls_id label "Class".
def shared var cls1             like fa_facls_id label "To".
def shared var assacc           like faba_acct   label "Asset Account".
def shared var assacc1          like faba_acct   label "To".
def shared var depacc           like ast_ac_acct label "Accum Depn Account".
def shared var depacc1          like ast_ac_acct label "To".
def shared var method           like fab_famt_id label "Method".
def shared var method1          like fab_famt_id label "To".
def shared var pass_domain      like fa_domain.
def shared var pass_book        like fabk_id.
def shared var start_per        like fabd_yrper.
def shared var end_per          like fabd_yrper.
def shared var prev_per         like fabd_yrper.
def shared var v_startdt        like fa_startdt  label 'Date' init today.
def shared var v_enddt          like fa_startdt  label 'To'   init today. 
def shared var fisc_yr          as char format "x(4)".
def shared var fisc_per         as char format "x(2)".
def shared var rpttype          as   char.
def shared var batch            as log.

def shared temp-table t_famov
    field famov_domain             like fa_domain
    field famov_entity             like fa_entity
    field famov_fabk_id            like fabk_id
    field famov_fa_id              like fa_id
    field famov_fa_desc            like fa_desc1
    field famov_startdt            like fa_startdt
    field famov_disp_dt            like fa_disp_dt
    field famov_chr01              like fa__chr01                      /*CP01*/
    field famov_chr02              like fa__chr02
    field famov_chr03              like fa__chr03                      /*CP01*/
    field famov_chr04              like fa__chr04                      /*CP01*/
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

/* MFG/pro function f-sumcost */
{xxfadepfx.i} /* CALCULATE DEPRECIATION FUNCTIONS */

/* MFG/pro function get-accdep */
{xxfabkfx.i}  /* CALCULATE SUM OF BASIS FUNCTION */

define variable vrowid                as  rowid  no-undo.  
define variable vOldEntity            like fabd_entity  no-undo.  
define variable vNewEntity            like fabd_entity  no-undo.  
define variable vOldSub               like faba_sub  no-undo.  
define variable vNewSub               like faba_sub  no-undo.  
define variable vOldCC                like faba_cc   no-undo.  
define variable vNewCC                like faba_cc   no-undo.  
define variable vLastYrper            like fabd_yrper  no-undo.  
define variable vTransper             like fabd_yrper  no-undo.  
define variable l_error               like mfc_logical no-undo.
define variable vEntityChg            as char format "x(10)" no-undo.
define variable vSvcYr                as char no-undo.
define variable vSvcDt                like fa_startdt no-undo.
define variable vLddYr                as char no-undo.
define variable perDate               like fabd_yrper format "x(7)" no-undo.
define variable costAmt               like fabd_peramt no-undo.
define variable vAccumDepBk           like fabd_accamt no-undo.     
define variable total_in_costAmt      like fabd_peramt no-undo.
define variable total_in_vAccumDepBk  like fabd_accamt no-undo.     
define variable total_out_costAmt     like fabd_peramt no-undo.
define variable total_out_vAccumDepBk like fabd_accamt no-undo.     
define variable accDepr               like fabd_accamt no-undo.
define variable vFirstAssetDep        like fabd_accamt no-undo.
define variable netBook               like fabd_peramt no-undo.
define variable vBegYear              like fabd_yrper  no-undo.     
define variable vBegPeriod            like fabd_yrper  no-undo.    

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

def buffer b_t_famov for t_famov.
def buffer b-fabd_det for fabd_det.                      /* AM02 */
def buffer b1-fab_det for fab_det.
def buffer b1-fabd_det for fabd_det.

/* convert gl periods into dates */

find first glc_cal where 
			 glc_domain = pass_domain
		     and glc_year   = int(substr(start_per,1,4))
		     and glc_per    = int(substr(start_per,5,2)) 
	     no-lock.

assign v_startdt = glc_start.

/* find the previous glc_cal period prior to the FROM period */

find prev glc_cal where glc_domain = pass_domain no-lock.
if  glc_per < 10 
then prev_per = string(glc_year) + '0' + string(glc_per).
else prev_per = string(glc_year) + string(glc_per).
    
/* convert gl periods into dates */

find first glc_cal where 
		     glc_domain = pass_domain
		 and glc_year   = int(substr(end_per,1,4))
		 and glc_per    = int(substr(end_per,5,2)) 
	 no-lock.

v_enddt = glc_end.

for each fa_mstr where 
			fa_domain   = pass_domain
		    and fa_entity   >= entity 
		    and fa_entity   <= entity1 
		    and fa__dte01   >= 09/01/1949             /*CP01*/
		    and fa__dte01   <= v_enddt                /*CP01*/
		    and fa_id       >= asset 
		    and fa_id       <= asset1   
		    and fa_facls_id >= cls 
		    and fa_facls_id <= cls1 
		    and (fa_disp_dt  = ?                      /*CP01*/
                        or (fa_disp_dt <> ?                   /*CP01*/
                           and fa_disp_dt >= v_startdt        /*CP01*/
                           and fa_disp_dt <= v_enddt))        /*CP01*/
            no-lock 
	    break 
	    by fa_entity 
	    by fa_facls_id
	    :

    find first fab_det where
			fab_domain  = pass_domain
		    and fab_fabk_id = pass_book
	    no-lock no-error.
    if  not available fab_det
    then leave.

    if  not can-find(first fab_det where 
				fab_domain  = pass_domain
			    and fab_fabk_id = pass_book
			    and fab_fa_id   = fa_id) 
    then next. 

    find last faba_det where 
				faba_domain = pass_domain
			    and faba_fa_id  = fa_id 
		    no-lock no-error.
    if  available faba_det 
    then v_glseq = faba_glseq. /* latest records */
    else v_glseq = 0.
    
    if  not can-find(first faba_det where 
					faba_domain  = pass_domain
                                    and faba_acctype = '1'
                                    and faba_fa_id   = fa_id
                                    and faba_acct   >= assacc
                                    and faba_acct   <= assacc1) 
    then next.
                                     
    if  not can-find(first faba_det where 
					faba_domain  = pass_domain
                                    and faba_acctype = '2'
                                    and faba_fa_id   = fa_id
                                    and faba_acct   >= depacc
                                    and faba_acct   <= depacc1) 
    then next. 
     
    if not can-find(last faba_det where 
				    faba_domain    = pass_domain
				and faba_fa_id     = fa_id             /*CP01*/
				and faba_acctype   = '3' /* Dep Exp Acct  CP01*/
				and faba_glseq     = v_glseq no-lock)  
    then next.   /*CP01*/

    if  not can-find(first faba_det where 
					faba_domain  = pass_domain
                                    and faba_fa_id   = fa_id        /*CP01*/
                                    and faba_acctype = '4' no-lock)    /*CP01*/
    then next.          /*CP01*/
    
    find first facls_mstr where 
				facls_domain = pass_domain
			    and facls_id     = fa_facls_id 
		    no-lock.

    assign
        vSvcDt = ?
        vSvcYr = "N/A"
	.

    find last fab_det where
			fab_det.fab_domain   = pass_domain
		    and fab_det.fab_fa_id    = fa_id
		    and fab_det.fab_fabk_id  = pass_book
		no-lock no-error.

    if  available fab_det
    then vSvcDt = fab_date.
    else vSvcDt = fa_startdt.

    if  vSvcDt <> ? 
    then do:
	run fa-get-per(
		       input pass_domain,
		       input vSvcDt,
		       output vSvcYr
		       ).
       if  vSvcYr <> "N/A"
       then vSvcYr = substr(vSvcYr,1,6).
    end.

    vLddYr = "N/A".

    /*
    if  fa__dte01 <> ? 
    then do:
	run fa-get-per(
		       input pass_domain,
		       input fa__dte01,
		       output vLddYr
		       ).
       if  vLddYr <> "N/A"
       then vLddYr = substr(vLddYr,1,6).
    end.
    */

    if  fa__dte01 <> ? 
    then do:
	run fa-get-per(
		       input pass_domain,
		       input fa__dte01,
		       output vBegPeriod
		       ).
        if  vBegPeriod <> "N/A"
        then vLddYr = substr(vBegPeriod,1,6).
    end.

    find last fab_det where
			fab_domain  = pass_domain
		    and fab_fa_id   = fa_id
		    and fab_fabk_id = pass_book
	    no-lock no-error.

    find famt_mstr where
		    famt_domain = pass_domain
	        and famt_id     = fab_famt_id
	    no-lock no-error.

/********* CREATE AND POPULATE THE TEMP-TABLE USED FOR THE REPORT **********/

    create t_famov.
    assign 
	   famov_domain        = fa_domain
	   famov_entity        = fa_entity
           famov_fabk_id       = pass_book
           famov_fa_id         = fa_id
           famov_fa_desc       = fa_desc
           famov_chr01         = fa__chr01                      /*CP01*/
           famov_chr03         = fa__chr03                      /*CP01*/
           famov_chr04         = if  pass_book = "TAX" 
	                         then fa__chr03 
	                         else fa__chr01
           famov_startdt       = vSvcDt
           famov_startyr       = vSvcYr
           famov_loadyr        = vLddYr
           famov_dateloaded    = fa__dte01
           famov_dep_method    = if  available fab_det 
				 then fab_famt_id 
				 else "N/A"
           famov_dep_type      = if  available famt_mstr 
				 then famt_type 
				 else "N/A"
           famov_dep_life      = if  available fab_det 
				 then fab_life 
				 else ?
           famov_disp_dt       = fa_disp_dt
           famov_facls_id      = fa_facls_id
           famov_facls_desc    = facls_desc
           famov_start_dep     = 0                          /*CP01*/
           famov_start_dep     = 0                          /*CP01*/
           famov_op_accum_depn = 0                          /*CP01*/
           famov_cl_accum_depn = 0                          /*CP01*/
	   famov_proc_on_disp  = fa_dispamt
	   .

    vrowid = rowid(t_famov).

    find last faba_det where 
			    faba_domain  = pass_domain
			and faba_fa_id   = fa_id
			and faba_acctype = '1' 
		no-lock.

    find first ac_mstr where 
			ac_domain = pass_domain
		    and ac_code   = faba_acct 
	    no-lock no-error.

    assign 
	famov_ast_acct        = faba_acct
	famov_ast_sub         = faba_sub
	famov_ast_acct_desc   = if available ac_mstr 
			        then ac_desc
                                else ''.                /* CFP0171 */
     
    find last faba_det where 
			    faba_domain  = pass_domain
                        and faba_fa_id   = fa_id
                        and faba_acctype = '2' 
		no-lock.

    find first ac_mstr where 
			ac_domain = pass_domain
		    and ac_code   = faba_acct 
	    no-lock no-error.

    assign 
	famov_dep_acct         = faba_acct
	famov_acc_dep_sub      = faba_sub
	famov_dep_acct_desc    = if available ac_mstr 
				 then ac_desc
                                 else ''.              /* CFP0171 */
     
    find last faba_det where 
			faba_domain  = pass_domain
		    and faba_fa_id   = fa_id
		    and faba_acctype = '3' 
	    no-lock.

    assign 
	famov_per_dep_acct     = faba_acct
	famov_per_dep_sub      = faba_sub
	famov_per_dep_cc       = faba_cc
	.
     
/* get opening accumulated depreciation for each asset */
    for each fabd_det where 
			fabd_domain  = pass_domain
		    and fabd_fa_id   = fa_id 
		    and fabd_fabk_id = pass_book 
		    and fabd_yrper   = prev_per use-index fabd_fa_id 
	    no-lock:     
        famov_op_accum_depn = fabd_accamt + famov_op_accum_depn.
    end.

 /* Start of new change - CP01 */

    for each fabd_det where 
			fabd_domain  = pass_domain
		    and fabd_fa_id   = fa_id
		    and fabd_fabk_id = pass_book
		    and fabd_post    = yes                     
		    and fabd_yrper  <= end_per use-index fabd_fa_id 
	    no-lock
	    break 
	    by fabd_yrper
	    :

	if  first-of(fabd_yrper) 
	then famov_cl_accum_depn = 0.

        assign 
            famov_cl_accum_depn = famov_cl_accum_depn + fabd_accamt
	    .
    end.  /* End of CP01 */

    assign 
	famov_op_bkcost = f-sumcost(fa_Id,fa_domain,pass_book)          /*CP01*/
	famov_cl_bkcost = f-sumcost(fa_id,fa_domain, pass_book)
	.

    /* Recalculate Opening Bal Assets */

    v_amt = 0.                                                       /*CP01*/
    for each fab_det where 
			fab_domain = pass_domain
                    and fab_fa_id   = fa_id                          /*CP01*/
                    and fab_fabk_id = pass_book 
	    no-lock:                                                 /*CP01*/
        if  fab_date <  v_startdt 
	then v_amt = v_amt + fab_amt.                                /*CP01*/
    end.                                                             /*CP01*/

    if  v_amt = 0 
    then famov_op_bkcost = 0.                                       /*CP01*/

    /* if new additions then put in additions with depreciation */
    /* if fa_startdt >= v_startdt and fa_startdt <= v_enddt then */

    if  fa__dte01 >= v_startdt 
    and fa__dte01 <= v_enddt 
    then do:
        assign 
	   famov_additions   = famov_cl_bkcost
	   famov_additions_o = if  famov_cl_bkcost <= 1000 
			       then 0 
			       else famov_cl_bkcost
	   famov_additions_u = if  famov_cl_bkcost > 1000 
			       then 0
			       else famov_cl_bkcost
           famov_start_dep   = famov_cl_accum_depn
	   .
    end. /* new additions */

    /* if not new additions, calculate their depreciation */

    else do:

        assign 
	   famov_additions   = 0
	   famov_additions_u = 0
	   famov_additions_o = 0
	   .
            
        for each fabd_det where 
				fabd_domain   = pass_domain
                            and fabd_fa_id    = fa_id
                            and fabd_fabk_id  = pass_book
                            and fabd_post     = true                 /*CP01*/
                            and fabd_yrper   >= start_per
                            and fabd_yrper   <= end_per use-index fabd_fa_id 
		    no-lock:

	    famov_start_dep = fabd_peramt + famov_start_dep.

        end. /* for each fabd_det */

    end. /* existing assets */
        
    if  famov_dep_type = "3"
    then famov_start_dep_3 = famov_start_dep.
    else
    if  index("1,5",famov_dep_type) > 0
    then famov_start_dep_1_5 = famov_start_dep.

    if  fa_disp_dt >= v_startdt 
    and fa_disp_dt <= v_enddt 
    then assign 
            famov_disposals = famov_cl_bkcost                         /*CP01*/
            famov_disp_dep  = famov_cl_accum_depn                     /*CP01*/
	    .
    else famov_disposals = 0.

    /*Recalculated Closing Bal.Assets at cost                           *CP01*/

    assign                                                              /*CP01*/
         famov_cl_bkcost       = famov_cl_bkcost - famov_disposals      /*CP01*/
         famov_cl_accum_depn   = famov_cl_accum_depn - famov_disp_dep   /*CP01*/
         famov_op_bkcost       = famov_cl_bkcost -  famov_additions     /*CP01*/
                                  +  famov_disposals                    /*CP01*/
         famov_op_accum_depn   = famov_cl_accum_depn - famov_start_dep  /*CP01*/
                                  - famov_adds_dep  + famov_disp_dep    /*CP01*/
         famov_op_wdv          = famov_op_bkcost - famov_op_accum_depn  /*CP01*/
         famov_cl_wdv          = famov_cl_bkcost - famov_cl_accum_depn  /*CP01*/
	 .

/* Determine if asset has been transferred */

    for each fabd_det
        fields( fabd_domain fabd_fa_id fabd_faloc_id
                fabd_facls_id fabd_entity fabd_transfer fabd_yrper
                fabd_fabk_id fabd_trn_loc)
        where 
	        fabd_det.fabd_domain = pass_domain
	    and fabd_fa_id           = fa_id
	    and fabd_transfer        = yes
	    and fabd_yrper          >= start_per
	    and fabd_yrper          <= end_per
	    and fabd_fabk_id         = pass_book
        no-lock 
        break 
        by fabd_yrper  
        by fabd_faloc_id 
        by fabd_fa_id
        :
        
    /* Only accumulate and display results if new asset */
    
        if  last-of(fabd_fa_id) 
        then do: 
    
	    assign
	        vFirstAssetdep = 0
	        costAmt        = 0
	        accDepr        = 0
		.
	    for each b1-fab_det
	        fields( b1-fab_det.fab_domain 
		        b1-fab_det.fab_fa_id 
		        b1-fab_det.fab_fabk_id 
		        b1-fab_det.fab_amt )
		    where
		        b1-fab_det.fab_domain  = pass_domain 
		    and b1-fab_det.fab_fa_id   = fabd_fa_id
		    and b1-fab_det.fab_fabk_id = pass_book
		    no-lock
		    :
	        costAmt = costAmt + b1-fab_det.fab_amt.
	    end. /* FOR EACH b1-fab_det */
		      
	    for each b1-fabd_det
	        fields( b1-fabd_det.fabd_domain 
		        b1-fabd_det.fabd_fa_id 
		        b1-fabd_det.fabd_fabk_id 
		        b1-fabd_det.fabd_yrper 
		        b1-fabd_det.fabd_accamt )
		    where 
		        b1-fabd_det.fabd_domain   = pass_domain 
		    and b1-fabd_det.fabd_fa_id    = fabd_det.fabd_fa_id
		    and b1-fabd_det.fabd_fabk_id  = pass_book
		    and b1-fabd_det.fabd_yrper    = fabd_det.fabd_yrper
		    no-lock
		    :
	        accDepr = accDepr + b1-fabd_det.fabd_accamt.
	    end. /* FOR EACH b1-fabd_det */
    
	    assign
	        netBook = costAmt - accDepr
	        perDate = substring(fabd_yrper,1,4) + "/" +
		          substring(fabd_yrper,5,2)
	        .
    
/* Full Depreciation Check */
    
	    if  netBook ge 0 
	    then do:
    
/* get the yrper prior to the transfer */
    
	        find last b-fabd_det where 
			        b-fabd_det.fabd_domain = fabd_det.fabd_domain
			    and b-fabd_det.fabd_fa_id  = fabd_det.fabd_fa_id
			    and b-fabd_det.fabd_yrper  < fabd_det.fabd_yrper
		       no-lock no-error.
    
	        if  available b-fabd_det 
	        then do:
    
		    if  b-fabd_det.fabd_entity <> fabd_det.fabd_entity
		    then do:

    
			find faloc_mstr where
				        faloc_domain = fabd_det.fabd_domain
				    and faloc_id     = fabd_det.fabd_faloc_id
				    and faloc_entity = fabd_det.fabd_entity
				no-lock no-error.

			if  available faloc_mstr
			then assign
		                vOldSub = faloc_user1
		                vOldCC  = faloc_user2
				.

			find faloc_mstr where
				        faloc_domain = b-fabd_det.fabd_domain
				    and faloc_id     = b-fabd_det.fabd_faloc_id
				    and faloc_entity = b-fabd_det.fabd_entity
				no-lock no-error.

			if  available faloc_mstr
			then assign
		                vNewSub = faloc_user1
		                vNewCC  = faloc_user2
				.

		        assign
			    vEntityChg   = "Entity Change"
			    vOldEntity   = b-fabd_det.fabd_entity
			    vNewEntity   = fabd_det.fabd_entity
			    vTransPer    = fabd_det.fabd_yrper
			    .
    
		        for each b1-fabd_det where 
			        b1-fabd_det.fabd_domain   = pass_domain
			    and b1-fabd_det.fabd_fa_id    = fa_id
			    and b1-fabd_det.fabd_fabk_id  = pass_book
			    and b1-fabd_det.fabd_post     = true     
			    and b1-fabd_det.fabd_yrper   >= start_per
			    and b1-fabd_det.fabd_yrper  <= b-fabd_det.fabd_yrper use-index fabd_fa_id 
		          no-lock:
    
			    assign vFirstAssetdep = 
				      b1-fabd_det.fabd_peramt + vFirstAssetdep.
    
		         end.
    
		    end.
		    else vEntityChg = "Same Entity".
    
	        end.
    
/* 
	Get the beginning of the current year for calcs
	- default to beginning of current year for transfer
*/
    
	        assign 
		     substr(vBegYear,1,4) = substr(fabd_det.fabd_yrper,1,4)
		     substr(vBegYear,5,2) = '01'
		     .
	         
/* 
	if the load date is in the current year that the transfer is
	in, then we need to make vBegYear go right back to capture
	ALL depreciation for the asset
*/   
	    	
	        if  substr(vBegYear,1,4) = substr(vBegPeriod,1,4)
	        then vBegYear = '190001'.
	         
	        vAccumDepBk = 0.
    
/* get the ytd depn and accum depn to DOT - BOOK */
/* find the last yrper to calc accum depn for DOT */
    
	        find last b-fabd_det where 
			        b-fabd_det.fabd_domain  = fabd_det.fabd_domain
			    and b-fabd_det.fabd_fa_id   = fabd_det.fabd_fa_id
			    and b-fabd_det.fabd_yrper   < fabd_det.fabd_yrper
			    and b-fabd_det.fabd_fabk_id = pass_book
		        no-lock no-error.
    
	        if  available b-fabd_det 
	        then do:
		    vLastYrper = b-fabd_det.fabd_yrper.        
		    for each b-fabd_det where 
			        b-fabd_det.fabd_domain  = 
						    fabd_det.fabd_domain
			    and b-fabd_det.fabd_fa_id   = 
						    fabd_det.fabd_fa_id
			    and b-fabd_det.fabd_yrper   = vLastYrper
			    and b-fabd_det.fabd_fabk_id = pass_book
		        no-lock:
		        vAccumDepBk = vAccumDepBk + b-fabd_det.fabd_accamt.
		    end. 
	        end.
	          
	        if  vEntityChg = "Entity Change"
	        then do:
    
 		    buffer-copy t_famov to b_t_famov.
    
		    find t_famov where rowid(t_famov) = vrowid no-error.
		    if available t_famov
		    then assign
		           b_t_famov.famov_start_dep = 
			         b_t_famov.famov_start_dep - vFirstAssetdep
		           t_famov.famov_start_dep        = vFirstAssetdep
		           t_famov.famov_transper         = vTransPer
		           b_t_famov.famov_transper       = vTransPer
		           t_famov.famov_entity           = vOldEntity
		           t_famov.famov_tr_entity_fr     = vOldEntity
		           t_famov.famov_tr_entity_to     = vNewEntity
		           b_t_famov.famov_tr_entity_fr   = vOldEntity
		           b_t_famov.famov_tr_entity_to   = vNewEntity
		           b_t_famov.famov_entity         = vNewEntity
			   b_t_famov.famov_ast_sub        = vOldSub
			   b_t_famov.famov_acc_dep_sub    = vOldSub
			   b_t_famov.famov_per_dep_sub    = vOldSub
			   b_t_famov.famov_per_dep_cc     = vOldCC
			   t_famov.famov_ast_sub          = vNewSub
			   t_famov.famov_acc_dep_sub      = vNewSub
			   t_famov.famov_per_dep_sub      = vNewSub
			   t_famov.famov_per_dep_cc       = vNewCC
		           t_famov.famov_out_costAmt      = costAmt
		           t_famov.famov_out_vAccumDepBk  = vAccumDepBk
		           t_famov.famov_cl_accum_depn    = 
			       if  vNewEntity = t_famov.famov_entity
			       then t_famov.famov_cl_accum_depn
			       else 0 
		           b_t_famov.famov_cl_accum_depn    = 
			       if  vNewEntity = b_t_famov.famov_entity
			       then b_t_famov.famov_cl_accum_depn
			       else 0 
		           b_t_famov.famov_op_wdv         = 0
		           b_t_famov.famov_op_bkcost      = 0
		           b_t_famov.famov_op_accum_depn  = 0
		           t_famov.famov_cl_bkcost        = 0 
		           t_famov.famov_cl_wdv           = 0 
		           b_t_famov.famov_in_costAmt     = costAmt
		           b_t_famov.famov_in_vAccumDepBk = vAccumDepBk
		           .
    
		    if  famov_dep_type = "3"
		    then assign
			     t_famov.famov_start_dep_3 = 
					     t_famov.famov_start_dep
			     b_t_famov.famov_start_dep_3 = 
					     b_t_famov.famov_start_dep
			     .
		    else
		    if  index("1,5",famov_dep_type) > 0
		    then assign
			     t_famov.famov_start_dep_1_5 = 
					     t_famov.famov_start_dep
			     b_t_famov.famov_start_dep_1_5 = 
					     b_t_famov.famov_start_dep
			     .

	        end. /* if  vEntityChg = "Entity Change" */
    
	    end. /* if  netBook > 0 */

        end. /* if  last-of(fabd_fa_id) */
    
    end. /*  for each fabd_det  */ 

end. /* for each fa_mstr */

procedure fa-get-per.

    define input  parameter i_domain  like fa_domain   no-undo.
    define input  parameter i_date    as date          no-undo.
    define output parameter o_per     as character     no-undo.

    find first glc_cal where 
			glc_cal.glc_domain = i_domain 
		    and glc_start         <= i_date
		    and glc_end           >= i_date
	        no-lock no-error.
    if  available glc_cal
    then o_per = string(glc_year,"9999") + string(glc_per,"99").
    
end procedure.

