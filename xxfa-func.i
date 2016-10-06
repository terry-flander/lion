/*------------------------------------------------------------------------

  File:         xxfa-func.i

  Description:  Various functions for Fixed Asset Support

  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     1.00 07Sep16  Terry    Created
          
------------------------------------------------------------------------*/
  
FUNCTION date2YearPeriod RETURNS CHARACTER
  (vp_domain as char, vp_date as date):
  
  def var vr_result as char no-undo.
  
  find first glc_cal no-lock
    where glc_domain = vp_domain
      and vp_date <> ?
      and glc_start <= vp_date
      and glc_end   >= vp_date no-error.
  if available glc_cal then
    vr_result = string(glc_year,"9999") + string(glc_per,"99").

  return vr_result.
   
END FUNCTION.   

PROCEDURE date2YearAndPeriod:
  def input param ip_domain   as char no-undo.
  def input param ip_date     as date no-undo.
  def output param op_year    as int no-undo.
  def output param op_per     as int no-undo.

  find first glc_cal no-lock 
    where glc_domain = ip_domain
      and glc_start <= ip_date
      and glc_end   >= ip_date no-error.
  if available glc_cal then
    assign
      op_per  = glc_per
      op_year = glc_year
      .
      
END PROCEDURE.   

FUNCTION yearPeriod2Date RETURNS DATE
  (vp_domain as char, vp_yearperiod as char, vp_start as logical):
  
  def var vr_result as date no-undo.
  
  find first glc_cal no-lock
    where glc_domain = vp_domain 
      and glc_year = int(substring(vp_yearperiod,1,4))
      and glc_per  = int(substring(vp_yearperiod,5,2)) no-error.
  if available glc_cal then
    vr_result = if vp_start then glc_start else glc_end.
  return vr_result.
   
END FUNCTION.   

FUNCTION previousPeriod RETURNS CHARACTER
  (vp_domain as char, vp_yearperiod as char):
  
  def var vr_result as char no-undo.
  
  find first glc_cal no-lock
    where glc_domain = vp_domain
      and glc_year = int(substring(vp_yearperiod,1,4))
      and glc_per  = int(substring(vp_yearperiod,5,2)) no-error.
  if available glc_cal then
    find prev glc_cal no-lock
      where glc_domain = vp_domain no-error.

  if available glc_cal then
    vr_result = string(glc_year,"9999") + string(glc_per,"99").
  
  return vr_result.
   
END FUNCTION.   

FUNCTION getDefaultBook RETURNS CHARACTER
  (vp_domain as char):
  
  def var vr_result as char no-undo.
  
  find first fab_det no-lock
    where fab_domain = vp_domain no-error.
  if available fab_det then
    vr_result = fab_fabk_id.

  return vr_result.
   
END FUNCTION.   

FUNCTION getDefaultEntity RETURNS CHARACTER
  (vp_domain as char, vp_userid as char):
  
  def var vr_result as char no-undo.
  
  find first code_mstr no-lock
    where code_value  = vp_userid
      and code_domain = vp_domain no-error.
  if available code_mstr then
  do:
    if code_cmmt begins '*' then
    do:
      find first en_mstr no-lock
        where en_domain = vp_domain no-error.
      if available en_mstr then
        vr_result = en_entity.
    end.
    else
      vr_result  = substring(code_cmmt,1,4).

  end.
  return vr_result.
   
END FUNCTION.

FUNCTION getLastGLSequence RETURNS INT
  (vp_domain as char, vp_fa_id as char):
  
  def var vr_result as int no-undo.
      
  find last faba_det no-lock
    where faba_fa_id  = vp_fa_id
      and faba_domain = vp_domain no-error.
  if available faba_det then
    vr_result = faba_glseq.

  return vr_result.
   
END FUNCTION.
 
FUNCTION filterEquipment RETURNS LOGICAL
  (vp_domain as char, vp_fa_id as char, vp_equip as char):

  def var vr_result as log init true.
     
  if vp_equip <> "" then
  do:
    vr_result = can-find(
        last fad_det 
          where fad_fa_id  = vp_fa_id
            and fad_domain = vp_domain
            and fad_desc   = vp_equip).
  end.
  return vr_result.

END FUNCTION.

FUNCTION filterProject RETURNS LOGICAL
  (vp_domain as char, vp_fa_id as char, vp_proj as char):

  def var vr_result as log init true.
     
  if vp_proj <> "" then
  do:
    vr_result = can-find(
        first faba_det 
          where faba_fa_id   = vp_fa_id
            and faba_domain  = vp_domain
            and faba_proj    = vp_proj 
            and faba_acctype = '4').
  end.
  
  return vr_result.

END FUNCTION.

FUNCTION filterBook RETURNS LOGICAL
  (vp_domain as char, vp_fa_id as char, vp_book as char):

  def var vr_result as log init true.

  vr_result = can-find(
      first fab_det 
        where fab_fabk_id = vp_book
          and fab_domain  = vp_domain
          and fab_fa_id   = vp_fa_id).
  
  return vr_result.

END FUNCTION.
  
FUNCTION filterAccount RETURNS LOGICAL
  (vp_domain as char, vp_fa_id as char, vp_glseq as int, 
   vp_accFrom as char, vp_accTo as char, 
   vp_subFrom as char, vp_subTo as char, 
   vp_ctrFrom as char, vp_ctrTo as char):

  def var vr_result as logical no-undo.
  
  vr_result = can-find(
      last faba_det 
        where faba_fa_id    = vp_fa_id
          and faba_domain   = vp_domain
          and faba_acctype  = '3' /* Dep Exp Acct */
          and faba_glseq    = vp_glseq
          and faba_acct    >= vp_accFrom
          and faba_acct    <= vp_accTo
          and faba_sub     >= vp_subFrom
          and faba_sub     <= vp_subTo
          and faba_cc      >= vp_ctrFrom
          and faba_cc      <= vp_ctrTo).
  return vr_result.

END FUNCTION.

FUNCTION filterAccountByType RETURNS LOGICAL
  (vp_domain as char, vp_fa_id as char, vp_type as char, vp_glseq as int, vp_accFrom as char, vp_accTo as char):

  def var vr_result as logical no-undo.
  
  vr_result = can-find(
      last faba_det 
        where faba_fa_id    = vp_fa_id
          and faba_domain   = vp_domain
          and faba_acctype  = vp_type
          and (vp_glseq = ? or faba_glseq = vp_glseq)
          and faba_acct    >= vp_accFrom
          and faba_acct    <= vp_accTo).
  return vr_result.

END FUNCTION.

FUNCTION getAssetClassDescription RETURNS CHARACTER
  (vp_domain as char, vp_fa_facls_id as char): 

  def var vr_result as char no-undo.
  
  find first facls_mstr no-lock
    where facls_domain = vp_domain
      and facls_id     = vp_fa_facls_id no-error.
  vr_result = if available facls_mstr then facls_desc else "".
  
  return vr_result.

END FUNCTION.

FUNCTION getAssetProject RETURNS CHARACTER
  (vp_domain as char, vp_fa_id as char, vp_glseq as int): 

  def var vr_result as char no-undo.

  find first faba_det no-lock
    where faba_fa_id   = vp_fa_id
      and faba_domain  = vp_domain
      and faba_acctype = '4'
      and faba_glseq   = vp_glseq no-error.
  if available faba_det then
    vr_result = faba_proj.

  return vr_result.

END FUNCTION.

FUNCTION getAssetSubAccountByType RETURNS CHARACTER
  (vp_domain as char, vp_fa_id as char, vp_type as char): 

  def var vr_result as char no-undo.

  find last faba_det no-lock
      where faba_domain  = vp_domain
        and faba_fa_id   = vp_fa_id
        and faba_acctype = vp_type no-error.
  if available faba_det then 
    vr_result = faba_sub.

  return vr_result.

END FUNCTION.

  
PROCEDURE getAssetAccountByType:
  def input param ip_domain   as char no-undo.
  def input param ip_fa_id    as char no-undo.
  def input param ip_glseq    as int no-undo.
  def input param ip_type     as char no-undo.
  def output param op_acc     as char no-undo.
  def output param op_sub     as char no-undo.
  def output param op_cc      as char no-undo.

  find first faba_det no-lock
    where faba_fa_id   = ip_fa_id
      and faba_domain  = ip_domain
      and faba_acctype = ip_type
      and (ip_glseq = ? or faba_glseq = ip_glseq) no-error.
  if available faba_det then
    assign 
      op_acc = faba_acct
      op_sub = faba_sub
      op_cc  = faba_cc
      .
END PROCEDURE.      

PROCEDURE getGLAccountByType:
  def input param ip_domain   as char no-undo.
  def input param ip_fa_id    as char no-undo.
  def input param ip_type     as char no-undo.
  def output param op_acc     as char no-undo.
  def output param op_sub     as char no-undo.
  def output param op_desc    as char no-undo.

  find last faba_det no-lock
    where faba_domain  = ip_domain
      and faba_fa_id   = ip_fa_id
      and faba_acctype = ip_type no-error. 

  if available faba_det then
  do:
    find first ac_mstr no-lock
      where ac_domain = ip_domain
        and ac_code   = faba_acct no-error.
    assign 
      op_acc  = faba_acct
      op_sub  = faba_sub
      op_desc = if available ac_mstr then ac_desc else ''.
  end.      

END PROCEDURE.      

FUNCTION getPeriodDepreciation RETURNS DECIMAL
  (vp_domain as char, vp_fa_id as char, vp_book as char, vp_start_per as char, vp_end_per as char):
  
  def var vr_result     as decimal no-undo.
  def var vl_current    as log no-undo init false.

  for each fabd_det fields(fabd_peramt) no-lock
      where fabd_fa_id   = vp_fa_id 
        and fabd_domain  = vp_domain
        and fabd_fabk_id = vp_book
        and fabd_post    = true
        and fabd_yrper  >= vp_start_per 
        and fabd_yrper  <= vp_end_per:
    vr_result  = vr_result + fabd_peramt.
  end.
  return vr_result.
  
END FUNCTION.

PROCEDURE getDepreciationAmounts:

  def input param ip_domain as char no-undo.
  def input param ip_fa_id  as char no-undo.
  def input param ip_book   as char no-undo.
  def input param ip_syrper as char no-undo.
  def input param ip_eyrper as char no-undo.

  def output param op_open_accum  as dec no-undo.
  def output param op_per_accum   as dec no-undo.
  def output param op_close_accum as dec no-undo.
  def output param op_variance    as dec no-undo.
  def output param op_report      as log no-undo.
  def output param op_message     as char no-undo.
  
  def var vl_hasgap           as log  no-undo init false.
  def var vl_per13            as log  no-undo init false.
  def var vl_unposted         as log  no-undo init false.
  def var vl_last             as char no-undo.
  def var vl_first_unposted   as char no-undo.
  def var vl_last_unposted    as char no-undo.
  
  def var vl_start_per        as char no-undo.
  def var vl_end_per          as char no-undo.
  
  assign
    vl_start_per = ip_syrper
    vl_end_per   = ip_eyrper
    .
  if vl_end_per matches "*12" then
    substring(vl_end_per,5,2) = "13".
  
  for each fabd_det no-lock
      where fabd_fa_id   = ip_fa_id 
        and fabd_domain  = ip_domain
        and fabd_fabk_id = ip_book
        and fabd_yrper   <= vl_end_per /* don't look after reporting period */
      use-index fabd_fa_id:
     if fabd_post then
     do:
       op_close_accum = op_close_accum + fabd_peramt.
       if fabd_yrper < vl_end_per then
         op_open_accum = op_open_accum + fabd_peramt.
       if fabd_yrper >= vl_start_per then
         op_per_accum = op_per_accum + fabd_peramt.
       if vl_unposted then
         vl_hasgap = true.
     end.
     else
     do:
        if vl_first_unposted = "" then vl_first_unposted = fabd_yrper.
        assign
          op_variance      = op_variance + fabd_peramt
          vl_last_unposted = fabd_yrper
          vl_unposted      = true
          .
     end.
     if fabd_yrper matches "*13" then
       vl_per13 = true.
     vl_last = fabd_yrper.
  end.
  
  assign 
    op_message = "C:" 
      + (if vl_last < vl_end_per then "Full" else "") + "-"
      + (if vl_hasgap then "Gap" else "") + "-"
      + (if vl_unposted = true then "Unposted" else "") + "-"
      + (if vl_per13 = true then "13" else "") + ","
      + (if vl_hasgap then vl_first_unposted + "-" + vl_last_unposted else "")
    op_report = vl_hasgap or vl_unposted or vl_per13
    .
  
END PROCEDURE.
  
FUNCTION getLastAccumulatedDepreciation RETURNS DECIMAL
  (vp_domain as char, vp_fa_id as char, vp_book as char, vp_yrper as char):

  def var vr_result     as decimal no-undo.
  def var vl_current    as log no-undo init false.
  def var vl_fabd_yrper like fabd_yrper no-undo.

  find last fabd_det no-lock
    where fabd_fa_id   = vp_fa_id 
      and fabd_domain  = vp_domain
      and fabd_fabk_id = vp_book
      and fabd_yrper   <= vp_yrper /* don't look after reporting period */
      and fabd_post    = true use-index fabd_fa_id no-error.
  if available fabd_det then 
  do:
    vl_fabd_yrper = fabd_yrper.
    for each fabd_det fields(fabd_accamt) no-lock
      where fabd_fa_id   = vp_fa_id 
        and fabd_domain  = vp_domain
        and fabd_fabk_id = vp_book
        and fabd_yrper   = vl_fabd_yrper
        and fabd_post    = true use-index fabd_fa_id:
      vr_result = vr_result + fabd_accamt.
    end.
  end.
  return vr_result.

END FUNCTION.

FUNCTION getSalvageAmount RETURNS DECIMAL
  (vp_domain as char, vp_fa_id as char, vp_book as char):
  
  def var vr_result     as decimal no-undo.
  
  for each fab_det fields(fab_salvamt) no-lock
    where fab_fa_id   = vp_fa_id
      and fab_domain  = vp_domain
      and fab_fabk_id = vp_book:
     assign
      vr_result = vr_result + fab_salvamt.
  end.

  return vr_result.

END FUNCTION.

FUNCTION getBookValue RETURNS DECIMAL
  (vp_domain as char, vp_fa_id as char, vp_book as char, vp_startdt as date):
  
  def var vr_result     as decimal no-undo.
  
  for each fab_det fields(fab_amt) no-lock
     where fab_domain  = vp_domain
       and fab_fa_id   = vp_fa_id
       and fab_fabk_id = vp_book          
       and fab_date < vp_startdt:
    vr_result = vr_result + fab_amt.

  end.

  return vr_result.

END FUNCTION.

FUNCTION getMethod RETURNS CHARACTER
  (vp_domain as char, vp_fa_id as char, vp_book as char):
  
  def var vr_result     like fab_famt_id no-undo.
  
  find first fab_det no-lock
    where fab_fa_id   = vp_fa_id                    
      and fab_domain  = vp_domain
      and fab_fabk_id = vp_book no-error.
  if available fab_det then
    vr_result = fab_famt_id.
  
  return vr_result.

END FUNCTION.             

FUNCTION getLife RETURNS DECIMAL
  (vp_domain as char, vp_fa_id as char, vp_book as char):
  
  def var vr_result     like fab_life no-undo.
  
  find first fab_det no-lock
    where fab_fa_id   = vp_fa_id                    
      and fab_domain  = vp_domain
      and fab_fabk_id = vp_book no-error.
  if available fab_det then
    vr_result = fab_life.
  
  return vr_result.

END FUNCTION.

FUNCTION getDepreciationOverrideDate RETURNS DATE
  (vp_domain as char, vp_fa_id as char, vp_book as char):
  
  def var vr_result     like fab_ovrdt no-undo.
  
  find first fab_det no-lock
    where fab_fa_id   = vp_fa_id                    
      and fab_domain  = vp_domain
      and fab_fabk_id = vp_book no-error.
  if available fab_det then
    vr_result = fab_ovrdt.
  
  return vr_result.

END FUNCTION.

FUNCTION getBookStartDate RETURNS DATE
  (vp_domain as char, vp_fa_id as char, vp_book as char, vp_default as date):

  def var vr_result     as date no-undo.

  find last fab_det no-lock
    where fab_det.fab_domain        = vp_domain
            and fab_det.fab_fa_id   = vp_fa_id
            and fab_det.fab_fabk_id = vp_book no-error.
  if available fab_det then 
    vr_result = fab_date.
  else
    vr_result = vp_default.
    
  return vr_result.
  
END FUNCTION.


FUNCTION getDepreciationType RETURNS CHARACTER
  (vp_domain as char, vp_fa_id as char, vp_fabk_id as char):
  
  def var vr_result     as char no-undo.
        
  find last fab_det no-lock 
    where fab_domain  = vp_domain
      and fab_fa_id   = vp_fa_id
      and fab_fabk_id = vp_fabk_id no-error.
  if available fab_det then
    find first famt_mstr no-lock 
      where famt_domain = vp_domain
        and famt_id     = fab_famt_id no-error.
  vr_result = if available fab_det and available famt_mstr then famt_type else "N/A".

  return vr_result.

END FUNCTION.
 
FUNCTION inDateRange RETURNS LOGICAL
  (vp_testDate as date, vp_startDate as date, vp_endDate as date):

  return vp_testDate <> ? and vp_startDate <> ? and vp_endDate<> ? and vp_testDate >= vp_startDate and vp_testDate <= vp_endDate.
  
END FUNCTION.

PROCEDURE getLocationAccount:
  def input param ip_domain   as char no-undo.
  def input param ip_faloc_id as char no-undo.
  def input param ip_entity   as char no-undo.
  def output param op_sub     as char no-undo.
  def output param op_cc      as char no-undo.

  find faloc_mstr no-lock
     where faloc_domain = ip_domain
       and faloc_id     = ip_faloc_id
       and faloc_entity = ip_entity no-error.

  if available faloc_mstr then 
    assign
      op_sub = faloc_user1
      op_cc  = faloc_user2
      .

END PROCEDURE.

FUNCTION setDecliningBalance RETURNS DECIMAL
  (vp_type as char, vp_amt as dec): 
  
  return if vp_type = "3" then vp_amt else 0.
  
END FUNCTION.

FUNCTION setStraightLine RETURNS DECIMAL
  (vp_type as char, vp_amt as dec): 
  
  return if index("1,5",vp_type) > 0 then vp_amt else 0.
  
END FUNCTION.