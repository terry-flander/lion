/*------------------------------------------------------------------------

  File:         xxscsrrpt_n.p

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
def var csvFileName     as char no-undo init "ShuttleRecovery".
def var okToOv          as log   no-undo.
def var wkDir           as char no-undo format "x(60)".

def stream csv.
def stream wkd.

def temp-table ttSelect no-undo
  field tEntity       like gltr_entity
  field tCtr          like gltr_ctr
  field tAcc          like gltr_acc
  index idx1 tEntity tCtr tAcc
  .

def temp-table ttResult no-undo
  field tt_line           as   int
  field tt_eff_dt         like gltr_eff_dt
  field tt_entity         like gltr_entity
  field tt_acc            like gltr_acc
  field tt_sub            like gltr_sub
  field tt_ctr            like gltr_ctr
  field tt_project        like gltr_project
  field tt_ref            like gltr_ref
  field tt_trType         as   char 
  field tt_site           as   char
  field tt_siteDesc       like si_desc
  field tt_part           as   char
  field tt_ptDesc         as   char
  field tt_pLine          as   char
  field tt_amt            like gltr_amt
  field tt_order          like tr_nbr
  field tt_TrNbr          as   char
  field tt_shuttleStd     like tr_lbr_std
  field tt_woTotQty       like tr_qty_loc
  field tt_shuttleRecAmt  like tr_lbr_std
  index idx1 tt_entity tt_ctr tt_acc
  .

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
  
  if search(csvFileName + "-Detail.csv") <> ? and not batchrun then 
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
  
  run loadSelect.
  run loadResult.
  run createDetailReport.
  run createSummaryReport.
  run createJournalReport.

  runok = yes.
  status default.
  
  if not batchrun then 
  do:
    if index(csvFileName,"/") > 0 then
      message "File" substring(csvFileName,r-index(csvFileName,"/") + 1)
              "has been created in directory"
              substring(csvFileName,1,r-index(csvFileName,"/") - 1)
              "."
              view-as alert-box.
    else message "File" csvFileName "has been created in your home directory."
               view-as alert-box.
  end.
end.

PROCEDURE loadSelect :

  EMPTY TEMP-TABLE ttSelect.
  
  DEF BUFFER gltr_hist FOR gltr_hist.
  
  FOR EACH en_mstr NO-LOCK
     WHERE en_domain EQ global_domain
       AND en_entity >= entity
       AND en_entity <= entityTo :
  
      FIND FIRST gltr_hist NO-LOCK
           WHERE gltr_domain EQ global_domain
             AND gltr_entity EQ en_entity USE-INDEX gltr_ctr NO-ERROR.
      
      DO WHILE AVAIL(gltr_hist) :
      
          CREATE ttSelect.
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
  for each ttSelect
    where tAcc < account or tAcc > accountTo:
    delete ttSelect.
  end.

END PROCEDURE.  /* loadSelect */

PROCEDURE loadResult: 

  EMPTY TEMP-TABLE ttResult.
  DEF BUFFER gltr_hist FOR gltr_hist.

  for each ttSelect:
  
    for each gltr_hist no-lock
      where gltr_domain = global_domain
        and gltr_entity = tEntity         
        and gltr_ctr    = tCtr
        and gltr_acc    = tAcc
        and gltr_eff_dt >= dateFrom
        and gltr_eff_dt <= dateTo 
        and gltr_sub    >= sub
        and gltr_sub    <= subTo
      use-index gltr_ctr :
      accumulate gltr_ref(count).

      create ttResult.
      assign      
        tt_line      = (accum count gltr_ref)
        tt_eff_dt    = gltr_eff_dt
        tt_entity    = gltr_entity
        tt_acc       = gltr_acc
        tt_sub       = gltr_sub
        tt_ctr       = gltr_ctr
        tt_project   = gltr_project
        tt_ref       = gltr_ref
        tt_amt       = gltr_amt
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
            tt_trType     = tr_type
            tt_site       = tr_site
            tt_part       = tr_part
            tt_ptDesc     = if available pt_mstr then pt_desc1 else ""
            tt_pLine      = if available pt_mstr then pt_prod_line else ""
            tt_order      = tr_nbr
            tt_TrNbr      = string(tr_trnbr)
            tt_siteDesc   = getSiteDescription(tr_domain, tr_site)
            tt_shuttleStd = tr_lbr_std
            .
          run getShuttleRecovery(tr_domain, tr_site, tr_part, dateFrom, dateTo, output tt_woTotQty, output tt_shuttleRecAmt).
        end.
      end.
  
    end.
  end.

END PROCEDURE.

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
  op_rec_amt = round(op_rec_amt,2).

END PROCEDURE.

PROCEDURE createDetailReport:

  output stream csv to value(csvFileName + "-Detail.csv").

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
         
  for each ttResult
    by tt_line:
    export stream csv delimiter ","
      tt_line
      tt_eff_dt     
      tt_entity     
      tt_acc        
      tt_sub        
      tt_ctr        
      tt_project    
      tt_ref        
      tt_trType     
      tt_site       
      tt_siteDesc   
      tt_part       
      tt_ptDesc     
      tt_pLine      
      tt_amt        
      tt_order      
      tt_TrNbr      
      tt_shuttleStd    
      tt_woTotQty      
      string(tt_shuttleRecAmt, "->>>,>>>,>>9.99") 
      .
  end.
  output stream csv close.

END PROCEDURE.

PROCEDURE createSummaryReport:
  
  def var lineNumber    as int no-undo.
  
  output stream csv to value(csvFileName + "-Summary.csv").

  export stream csv delimiter ","
    "Line"
    "Item"
    "Item Description"
    "Site"
    "Site Description"
    "Total Shuttle Recovery"
    .
         
  for each ttResult
    break by tt_site by tt_part:
    
    accumulate tt_shuttleRecAmt (total by tt_site by tt_part).
    
    if last-of(tt_part) then
    do:
      lineNumber = lineNumber + 1.
      
      export stream csv delimiter ","
        lineNumber
        tt_part    
        tt_ptDesc
        tt_site       
        tt_siteDesc
        string(accum total by tt_part tt_shuttleRecAmt, "->>>,>>>,>>9.99")
        .
    end.
    
    if last-of(tt_site) then
    do:
      lineNumber = lineNumber + 1.
      
      export stream csv delimiter ","
        lineNumber
        ""    
        ""
        tt_site + " Subtotal"       
        ""
        string(accum total by tt_site tt_shuttleRecAmt, "->>>,>>>,>>9.99")
        .
    end.
    
  end.
  output stream csv close.

END PROCEDURE.

PROCEDURE createJournalReport:
  
  def var lineDesc    as char no-undo.
  
  output stream csv to value(csvFileName + "-Journal.csv").

  export stream csv delimiter ","
    "Line"
    "Entity"
    "Account"
    "Sub-Account"
    "Cost Centre"
    "Line Description"
    "Document"
    "Address"
    "Recovery Amount"
    ""
    "Entity"
    "Account"
    "Sub-Account"
    "Cost Centre"
    "Project"
    "Description"
    "Line Description"
    "Document"
    "Address"
    "Negative Recovery Amount"
    .
         
  for each ttResult
    by tt_line:
    
    lineDesc = tt_part + " shuttle recovery " + string(month(tt_eff_dt)) + "-" + string(year(tt_eff_dt)).
    
    export stream csv delimiter ","
      tt_line
      tt_entity     
      tt_acc        
      tt_sub        
      tt_ctr
      lineDesc
      ""
      ""
      string(tt_shuttleRecAmt, "->>>,>>>,>>9.99") 
      ""
      tt_entity
      "6106"
      tt_sub
      "3510"
      ""
      ""
      lineDesc
      ""
      ""    
      string(tt_shuttleRecAmt * -1, "->>>,>>>,>>9.99") 
      .
  end.
  output stream csv close.

END PROCEDURE.
