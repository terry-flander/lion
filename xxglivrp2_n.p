/*------------------------------------------------------------------------

  File:         xxglivrp2_n.p

  Description:  Shuttle Recovery Report, based on:
                GL - Inventory Transaction Report 
                
  History:
  
  Version Date     Author   Description
  ------- -------- -------- ---------------------------------------------
     1.00 03Oct16  Terry    Refactored original and add Recovery fields
          
------------------------------------------------------------------------*/

{mfdtitle.i "3"}

def var account         as char no-undo.
def var accountTo       as char no-undo.
def var dateFrom        as date no-undo.
def var dateTo          as date no-undo.
def var entity          as char no-undo.
def var entityTo        as char no-undo.
def var sub             as char no-undo.
def var subTo           as char no-undo.
def var csvFileName     as char no-undo init "xxglivrp.txt".
def var trType          as char no-undo.
def var site            as char no-undo.
def var part            as char no-undo.
def var ptDesc          as char no-undo.
def var pLine           as char no-undo.
def var icQty           as char no-undo.
def var okToOv          as log   no-undo.
def var wkDir           as char no-undo format "x(60)".
def var siteDesc        like si_desc    no-undo.
def var shuttleStd      like tr_lbr_std no-undo.
def var woTotQty        like tr_qty_loc no-undo.
def var shuttleRecAmt   like tr_lbr_std no-undo.

def var Order AS char   no-undo.
def var trNbr AS char   no-undo.

def stream csv.
def stream wkd.

DEF TEMP-TABLE ttResults NO-UNDO
    FIELD tEntity AS CHAR
    FIELD tCtr    AS CHAR
    FIELD tAcc    AS CHAR
  INDEX idx1 tEntity tCtr tAcc.

FUNCTION getSiteDescription RETURNS CHARACTER
  (vp_domain as char, vp_site as char):
  
  find first si_mstr no-lock
    where si_domain = vp_domain
      and si_site   = vp_site no-error.
  return (if available si_mstr then si_desc else "").
  
END FUNCTION.

form
  skip(1)
  dateFrom         colon 20                      label "Effective Date"
  dateTo           colon 45                      label "To"
  entity           colon 20 format "x(4)"        label "Entity"
  entityTo         colon 45 format "x(4)"        label "To"
  account          colon 20                      label "Account"
  accountTo        colon 45                      label "To"
  sub              colon 20                      label "Sub-Account"
  subTo            colon 45                      label "To"
  skip(1)
  csvFileName      colon 20 format "x(40)"       label "File Name"
  skip
  with frame a side-labels width 80.

input stream wkd thru echo $WKD no-echo.
import stream wkd unformatted wkDir.
input stream wkd close.

csvFileName = wkdir + "/" + csvFileName.

find last glc_cal where glc_domain = global_domain
                  and   glc_end    < date(month(today),01,year(today))
                  no-lock no-error.

if available glc_cal then
do:
   assign 
      dateFrom = glc_start
      dateTo   = glc_end.

   display 
      dateFrom
      dateTo
   with frame a.
end.

repeat:
  assign
    dateFrom  = if dateFrom = low_date then ? else dateFrom
    dateTo    = if dateTo = hi_date then ? else dateTo
    entityTo  = if entityTo = hi_char then "" else entityTo
    accountTo = if accountTo = hi_char then "" else accountTo
    subTo     = if subTo = hi_char then "" else subTo
    .

  update
    dateFrom
    dateTo
    entity
    entityTo
    account
    accountTo
    sub
    subTo
    csvFileName
    with frame a.

  if csvFileName = "" then
  do:
      message "ERROR: FILE NAME CANNOT BE BLANK. Please re-enter.".
      next-prompt csvFileName with frame a.
      undo, retry.
  end.
  
  if search(csvFileName) <> ? and not batchrun then 
  do:
      message "WARNING: FILE ALREADY EXISTS. OK to override?" update okToOv.
      if okToOv = ? or okToOv = no then
          undo, retry.
  end.

  bcdparm = "".
  {mfquoter.i dateFrom}
  {mfquoter.i dateTo}
  {mfquoter.i entity}
  {mfquoter.i entityTo}
  {mfquoter.i account}
  {mfquoter.i accountTo}
  {mfquoter.i sub}
  {mfquoter.i subTo}
  {mfquoter.i csvFileName}

  assign
    dateFrom  = if dateFrom = ? then low_date else dateFrom
    dateTo    = if dateTo = ? then hi_date else dateTo
    entityTo  = if entityTo = "" then hi_char else entityTo
    accountTo = if accountTo = "" then hi_char else accountTo
    subTo     = if subTo = "" then hi_char else subTo.

  {mfselbat.i}

  status default "Extract now running. Please wait ...".
  
  output stream csv to value(csvFileName).

  export stream csv delimiter ","
    "Line"
    "Date"
    "Entity"
    "Account"
    "Sub-Account"
    "Cost Centre"
    "Project"
    "Transaction Reference"
    "Transaction Type"
    "Site"
    "Site Description"
    "SKU"
    "Description"
    "Prod Line"
    "Amount"
    "Order"
    "TrNbr"
    "Shuttle Std"
    "WO Quantity"
    "Total Shuttle Recovery"
    .
         

  RUN loadResults.

  FOR EACH ttResults,
      EACH gltr_hist no-lock
     WHERE gltr_domain EQ global_domain
       AND gltr_entity EQ tEntity         
       AND gltr_ctr    EQ tCtr
       AND gltr_acc    EQ tAcc
       and gltr_eff_dt >= dateFrom
       and gltr_eff_dt <= dateTo 
       and gltr_sub    >= sub
       and gltr_sub    <= subTo
    use-index gltr_ctr :

    accumulate gltr_ref(count).
    
    assign
      trType       = ""
      site          = ""
      part          = ""
      ptDesc        = ""
      pLine         = ""
      Order         = ""
      TrNbr         = ""
      siteDesc      = ""
      shuttleStd    = 0
      woTotQty      = 0
      shuttleRecAmt = 0
      .

    if gltr_tr_type = "IC" then 
    do:
      find tr_hist no-lock
        where tr_domain = global_domain
          and tr_trnbr  = integer(gltr_doc) no-error.
      if available tr_hist then 
      do:
        find pt_mstr no-lock
          where pt_domain = global_domain
            and pt_part   = tr_part no-error.
        assign
          trType     = tr_type
          site       = tr_site
          part       = tr_part
          ptDesc     = if available pt_mstr then pt_desc1 else ""
          pLine      = if available pt_mstr then pt_prod_line else ""
          order      = tr_nbr
          TrNbr      = string(tr_trnbr)
          siteDesc   = getSiteDescription(tr_domain, tr_site)
          shuttleStd = tr_lbr_std
          .
        run getShuttleRecovery(tr_domain, tr_site, tr_part, dateFrom, dateTo, output woTotQty, output shuttleRecAmt).
      end.
    end.

    export stream csv delimiter ","
      (accum count gltr_ref)
      gltr_eff_dt
      gltr_entity
      gltr_acc
      gltr_sub
      gltr_ctr
      gltr_project
      gltr_ref
      trType
      site
      siteDesc
      part
      ptDesc
      pLine
      gltr_amt
      order  
      trNbr  
      shuttleStd
      woTotQty
      shuttleRecAmt
      .
  end.

  output stream csv close.
  runok = yes.
  status default.
  
  if not batchrun then 
  do:
    if index(csvFileName,"/") > 0 then
      message "File" substring(csvFileName,r-index(csvFileName,"/") + 1)
              "has been created in directory"
              substring(csvFileName,1,r-index(csvFileName,"/") - 1)
              "with" (accum count gltr_ref) "lines."
              view-as alert-box.
    else message "File" csvFileName "has been created in your home"
               "directory with" (accum count gltr_ref) "lines."
               view-as alert-box.
  end.
end.

PROCEDURE loadResults :

  EMPTY TEMP-TABLE ttResults.
  
  DEF BUFFER gltr_hist FOR gltr_hist.
  
  FOR EACH en_mstr NO-LOCK
     WHERE en_domain EQ global_domain
       AND en_entity >= entity
       AND en_entity <= entityTo :
  
      FIND FIRST gltr_hist NO-LOCK
           WHERE gltr_domain EQ global_domain
             AND gltr_entity EQ en_entity USE-INDEX gltr_ctr NO-ERROR.
      
      DO WHILE AVAIL(gltr_hist) :
      
          CREATE ttResults.
          ASSIGN
              tEntity = gltr_entity
              tCtr    = gltr_ctr
              tAcc    = gltr_acc.
      
          FIND FIRST gltr_hist NO-LOCK
               WHERE gltr_domain EQ global_domain
                 AND gltr_entity EQ tEntity
                 AND gltr_ctr    EQ tCtr
                 AND gltr_acc    > tAcc  USE-INDEX gltr_ctr NO-ERROR.
      
          IF NOT AVAIL(gltr_hist) THEN
              FIND FIRST gltr_hist NO-LOCK
                   WHERE gltr_domain EQ global_domain
                     AND gltr_entity EQ tEntity
                     AND gltr_ctr    > tCtr  USE-INDEX gltr_ctr NO-ERROR.
      
      END.  /* avail(gltr_hist) */
  
  END.  /* each en_mstr */
  
  /* remove outside Account or cost centre range */
  for each ttResults
    where tAcc < account or tAcc > accountTo:
    delete ttResults.
  end.

END PROCEDURE.  /* loadResults */

PROCEDURE getShuttleRecovery:
  def input param ip_domain   like tr_domain  no-undo.
  def input param ip_site     like tr_site    no-undo.
  def input param ip_part     like tr_part    no-undo.
  def input param ip_fromDt   like tr_date    no-undo.
  def input param ip_toDt     like tr_date    no-undo.
  
  def output param op_wo_qty  like tr_qty_loc no-undo.
  def output param op_rec_amt like tr_lbr_std no-undo.
  
  for each tr_hist no-lock
    where tr_hist.tr_domain = ip_domain
      and tr_hist.tr_site   = ip_site
      and tr_hist.tr_type   = "RCT-WO"
      and tr_hist.tr_part   = ip_part
      and tr_hist.tr_date  >= ip_fromDt 
      and tr_hist.tr_date  <= ip_toDt:
    assign
      op_wo_qty  = op_wo_qty + tr_qty_loc
      op_rec_amt = op_rec_amt + (tr_qty_loc * tr_lbr_std)
      .
  end.

END PROCEDURE.

