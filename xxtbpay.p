/** xxtbpay.p  - SP2 and SP6 VERSION                                          */
/*                                                                           */
/* All rights reserved worldwide.  This is an unpublished work.              */
/******************************************************************************/
/* ACE88   03/12/07 JWL    Transactional Banking                             */
/* ACE88   16/01/08 D Ng   Run NotifySbl.p directly rather than thru gprun.i */
/* ACE88   17/01/08 D Ng   Fix some XML fields                               */
/*                         Change amount field format from 99,999,999.99 to  */
/*                              9999999999                                   */
/* ACE88   22/01/08 D Ng   Leading zero for cheque no                        */
/*                         Display message 'Processing, please wait'         */
/* JB01    23/04/08 Jarrod Change International Control Ref to use MFG Seq   */
/* JB02    01/05/08 Jarrod Use ctry_mstr.ctry_code1 for iso36 code           */
/* ACE88   07/05/08 Miguel use gpgetver.p to know what Service Pack is intalled */ 
/* ACE88   07/05/08 Miguel Domestic payments print absolut amounts, never negatives */
/* JB03    07/08/08 Jarrod Changed logic for tracking which cheques were created
                           to be sent                                        */
/* DN01    15/08/08 D Ng   Remit type change                                 */
/* DN02    19/08/08 D Ng   Fax # should be taken from vd__chr09, not ad_fax  */
/* JB04    05/09/08 Jarrod Send Remarks in Narrative  for ATO Vouchers       */
/* JB05    15/09/08 Jarrod Change output file names to include domain        */
/* JB06    02/10/08 Jarrod Warn and give errors if ckfrm 1 for International */
/* JB07    09/10/08 Jarrod Make Currenty and BeneRoute UPPER CASE            */
/* JB08    15/10/08 Jarrod For Domestic payments,send Banks Country not vend */
/* JB09    19/11/08 Jarrod Export the Staging Table before sending           */
/* JB10    03/08/12 Jarrod HD915929  Stop from sending funky characters      */ 
/* BA01    24/09/12 BA01   Migrate to WebMethods & performance tune-up       */
/* BA02    04/10/12 BA02   Reverted the performance tune-up                  */
/* JB11    11/04/13 Jarrod Don't use Sort Name for international             */
/* JB12    22/07/13 Jarrod Add Email address for International Payments      */
/* JB13    27/08/13 Jarrod HD993877 Add invoice number at place 61-          */
/* JB14    13/11/13 Jarrod remittances for Int Payments                      */
/* JB15    20/05/14 Jarrod remittances for Int Payments part 2               */
 
{mfdtitle.i "1.12"}
{cxcustom.i "xxtbpay.p"}
{&APCKPRT-P-TAG1}

{gldydef.i new}
{gldynrm.i new}
{gpglefdf.i}
{NotifySbl-v.i}
{gprunpdf.i "mcpl" "p"}

/* NRM SEQUENCE GENERATOR  JB01 */
{gpnbrgen.i}
    
/* &GLOBAL-DEFINE DEBUG . */
define variable bank              like bk_code                NO-UNDO .
define VARIABLE bank1             like bk_code                NO-UNDO . 
define VARIABLE ckfrm             like apc_ckfrm              NO-UNDO .
define VARIABLE cknbr             like ck_nbr                 NO-UNDO .
define variable ckdate            like ap_date INIT TODAY     NO-UNDO .
define variable effdate           like ap_effdate INIT TODAY  NO-UNDO .
define variable audit_trail       like mfc_logical INIT NO    NO-UNDO .
define variable print_rmk         like mfc_logical INIT NO    NO-UNDO .
define variable print_test        like mfc_logical INIT NO    NO-UNDO .

define variable init-daybook        like dy_dy_code  no-undo.
define variable duedate            like ap_date no-undo.
define variable NextSeq            AS INT FORMAT 9 no-undo.  
define variable TempFile           AS CHAR NO-UNDO.

DEF VAR VOkay                      AS LOGICAL NO-UNDO.

DEF VAR VBankName AS CHAR EXTENT 2 FORMAT "x(30)" NO-UNDO .

DEF BUFFER Bufbk_mstr FOR bk_mstr.
DEF BUFFER Buf1Ad_mstr FOR Ad_mstr.
DEF BUFFER BufAp_mstr FOR Ap_mstr.
DEF BUFFER BufVo_mstr FOR Vo_mstr.

DEF VAR VCurrency1 AS CHAR NO-UNDO INIT "AUD,CAN,CHF,EUR,FJD,GBP,NZD,SGD,USD,JPY,HKD".
DEF VAR VCurrency2 AS CHAR NO-UNDO INIT "AU,CA,CH,EU,FJ,GB,NZ,SG,US,JP,HK".

DEF stream scim.
def stream strxml.

DEFINE VARIABLE pString    AS CHARACTER   NO-UNDO.
DEFINE VARIABLE pErrStatus AS INTEGER     NO-UNDO.
DEFINE VARIABLE pMessage   AS CHARACTER   NO-UNDO.
DEFINE VARIABLE pFirstTime AS LOGICAL     NO-UNDO.
DEFINE VARIABLE VErrorList1 AS CHAR        NO-UNDO.
DEFINE VARIABLE VErrorList2 AS CHAR        NO-UNDO.

DEFINE VARIABLE VBeneAcccount   AS CHAR        NO-UNDO.
DEFINE VARIABLE VBeneHolder     AS CHAR        NO-UNDO.
DEFINE VARIABLE VCurrency       AS CHAR        NO-UNDO.
DEFINE VARIABLE VSwift          AS CHAR        NO-UNDO.
DEFINE VARIABLE VBeneRoute1     AS CHAR        NO-UNDO.
DEFINE VARIABLE VBeneRouteType  AS CHAR        NO-UNDO.

DEFINE VARIABLE cVersion    AS CHARACTER   NO-UNDO.

DEF TEMP-TABLE TBank
    FIELD domain         LIKE ad_domain
    FIELD Bank           like bk_code
    FIELD ckfrm          like apc_ckfrm
    FIELD AccountType    LIKE ad_addr
    FIELD ckdate         like ap_date
    FIELD effdate        like ap_effdate
    FIELD duedate        like ap_date
    FIELD audit_trail    like mfc_logical
    FIELD print_rmk      like mfc_logical
    FIELD print_test     like mfc_logical
    FIELD batch          like ap_batch
    FIELD DayBook        like dy_dy_code
    FIELD PaymentFile    AS CHAR 
    FIELD Entity         LIKE bk_entity
    FIELD Currency       AS CHAR 
    FIELD BaseCurrency   AS CHAR
    FIELD ExcRate1       AS DEC
    FIELD ExcRate2       AS DEC
    FIELD TYPE  LIKE bk0_type
  INDEX main IS PRIMARY UNIQUE domain Bank ckfrm .

DEF BUFFER BufTBank FOR TBank.
DEF BUFFER Bufck_mstr FOR ck_mstr. 
DEF BUFFER Bufckd_det FOR ckd_det.

DEF TEMP-TABLE TVendorList
    FIELD TBankCode LIKE Bk_mstr.Bk_code
    FIELD TVendor   LIKE ap_mstr.ap_vend
    FIELD TAlreadyPrinted AS LOGICAL 
    FIELD TPriorityNumber AS CHAR
    FIELD TSortBy         AS CHAR
    INDEX main TBankCode TVendor.

DEF BUFFER BufTVendorList FOR TVendorList.

DEF TEMP-TABLE TVendorTOT
    FIELD TBankCode LIKE Bk_mstr.Bk_code
    FIELD TVendor   LIKE ap_mstr.ap_vend
    FIELD TTotal    AS DEC
    FIELD TCkref    LIKE ck_mstr.ck_ref
    FIELD TRowid    AS ROWID
    FIELD TChKNbr   LIKE ck_nbr
    FIELD TVoRef    LIKE vo_ref
    FIELD TInvoice  LIKE vo_invoice
    FIELD TDate     AS DATE
    FIELD TRemarks  LIKE ap_rmk
    FIELD TCkFrm    LIKE ap_ckfrm
    FIELD TType     LIKE vo_type
    FIELD TCurrency AS CHAR 
    INDEX main TBankCode TVendor TCkref TRowid  .

DEF BUFFER BufTVendorTOT FOR TVendorTOT.

/* JB03 store the new cheques created */
DEF TEMP-TABLE ttNewCk NO-UNDO
    FIELD tDomain AS CHAR
    FIELD tBank   AS CHAR
    FIELD tRef    AS CHAR
    FIELD tRowid  AS ROWID
  INDEX idx1 tDomain tBank tRef
  INDEX idx2 IS PRIMARY tRowid .


define variable vTempDir      as cha NO-UNDO .

/* XML */
DEF VAR vSSID                AS CHAR NO-UNDO.
DEF VAR VIdentifier          AS CHAR NO-UNDO INIT "01".
DEF VAR VCustCode            AS CHAR NO-UNDO.
DEF VAR VCreateDate          AS DATE FORMAT 99/99/99 NO-UNDO INIT TODAY.
DEF VAR VCreateTime          AS CHAR NO-UNDO.
DEF VAR VRemitName           AS CHAR NO-UNDO INIT "Lion Nathan AU".
DEF VAR VPayRef              AS CHAR NO-UNDO.
DEF VAR VLineIdent           AS CHAR NO-UNDO INIT "02".
DEF VAR Vreference           AS CHAR NO-UNDO. 
DEF VAR VBBSB                AS CHAR NO-UNDO.
DEF VAR VBAccount            AS CHAR NO-UNDO.
DEF VAR VRemitLine           AS CHAR NO-UNDO INIT "03" .
DEF VAR VRemitInvNo          AS CHAR NO-UNDO.
DEF VAR VRemitDate           AS CHAR NO-UNDO.
DEF VAR VRemitSignPlus       AS CHAR NO-UNDO INIT "+".
DEF VAR VRemitSignPMinus     AS CHAR NO-UNDO INIT "-".
DEF VAR VTotPayments         AS INT  NO-UNDO.
DEF VAR VTotRemit            AS INT  NO-UNDO.
DEF VAR VHashTot             AS DEC  NO-UNDO.
DEF VAR VTrailIdent          AS CHAR INIT "99".
DEF VAR VPaymentType         AS CHAR NO-UNDO. 
DEF VAR VDomPaymentType      AS CHAR NO-UNDO. 
DEF VAR VRemitType           AS CHAR NO-UNDO.
DEF VAR VDelType             AS CHAR NO-UNDO.
DEF VAR VNarrative           AS CHAR NO-UNDO.
DEF VAR VCountryCode         AS CHAR NO-UNDO.
DEF VAR VRemitMultiLines     AS INT NO-UNDO.
/* HSBC */
DEF VAR VCreateDate1         AS CHAR NO-UNDO.
DEF VAR VCenturyDate         AS CHAR NO-UNDO.
DEF VAR VRecipient           AS CHAR NO-UNDO.
DEF VAR VPriorityCode        AS CHAR NO-UNDO INIT "P".
DEF VAR VPriorityNumber      AS CHAR NO-UNDO.

/* CitiBank */
DEF VAR VPAI                 AS CHAR NO-UNDO.
DEF VAR VPiUID               AS CHAR NO-UNDO.

DEF VAR VControlRef          AS CHAR NO-UNDO.
DEF VAR VLineNo              AS INT  NO-UNDO.
DEF VAR VDebitRef            AS CHAR NO-UNDO.
DEF VAR VTotalDebits         AS DEC FORMAT ">>>>>>>>>>>>>>9.99" NO-UNDO.
DEF VAR VtotalCredits        AS DEC  NO-UNDO.
DEF VAR VSeqNo               AS INT  NO-UNDO.
DEF VAR VChKNbr              AS CHAR NO-UNDO.

DEF VAR VPartyname           AS CHAR NO-UNDO.
DEF VAR VPartyStreet         AS CHAR NO-UNDO EXTENT 4.
DEF VAR VPartyCity           AS CHAR NO-UNDO.
DEF VAR VPartyPost           AS CHAR NO-UNDO.
DEF VAR VPartyCountry        AS CHAR NO-UNDO.
DEF VAR VBeneLocation        AS CHAR  NO-UNDO.
DEF VAR VAcctLocation        AS CHAR  NO-UNDO.
DEF VAR VPartyAcctLoc        AS CHAR  NO-UNDO.
DEF VAR VTotLin              AS INT NO-UNDO.
DEF VAR VRemarks             AS CHAR    NO-UNDO.
DEF VAR VRemarks1            AS CHAR    NO-UNDO.
DEF VAR VFaxNumber           AS CHAR NO-UNDO.

DEF VAR VtotVendPayments     AS DEC     NO-UNDO.

DEF VAR VPaymentRef           AS CHAR NO-UNDO.
DEF VAR VCreditRef            AS CHAR NO-UNDO.


DEF VAR VPass                AS INT     NO-UNDO.

DEF VAR Vaddr1               LIKE ad_mstr.Ad_Line1.
DEF VAR Vaddr2               LIKE ad_mstr.Ad_Line1.
DEF VAR Vaddr3               LIKE ad_mstr.Ad_Line1.
DEF VAR VaddrCity            LIKE ad_mstr.ad_City.
DEF VAR VaddrState           LIKE ad_mstr.ad_State.
DEF VAR VaddrZip             LIKE ad_mstr.Ad_Zip.
DEF VAR VIntCurrencyList     AS CHAR INIT "EUR". 
DEF VAR VEuroZone            AS CHAR NO-UNDO. 
DEF VAR VPrint               AS LOGICAL NO-UNDO.
DEF VAR VAlreadyPrinted      AS LOGICAL NO-UNDO.

def var vcSort                like ad_mstr.ad_sort  no-undo.
def var vcAddr1               like ad_mstr.ad_line1 no-undo.
def var vcAddr2               like ad_mstr.ad_line2 no-undo.
def var vcAddr3               like ad_mstr.ad_line3 no-undo.
def var vcCity                like ad_mstr.ad_city  no-undo.
def var vcState               like ad_mstr.ad_state no-undo.
def var vcZip                 like ad_mstr.ad_zip   no-undo.
def var vcCtry                like ad_mstr.ad_ctry  no-undo.

DEF VAR fRate  like exr_rate  NO-UNDO.
DEF VAR fRate2 LIKE exr_rate2 NO-UNDO.
DEF VAR iErrorCode like msg_nbr no-undo.

/* JB02 */
FUNCTION getISO316 RETURNS CHAR
    (INPUT pCtry AS CHAR) :

  FOR FIRST ctry_mstr FIELDS (ctry_code1) NO-LOCK
      WHERE ctry_ctry_code EQ pCtry :
      RETURN ctry_code1.
  END.  /* for first */

  RETURN "".

END FUNCTION.  /* getISO316 */

/* JB08 */
FUNCTION getBankCountry RETURNS CHAR
    (INPUT pBank AS CHAR) :
  DEF BUFFER bfad_mstr FOR ad_mstr.

  FIND       bfad_mstr NO-LOCK
       WHERE bfad_mstr.ad_domain EQ global_domain 
         AND ad_addr             EQ pBank NO-ERROR.
      
  IF AVAIL(bfad_mstr) THEN
      RETURN caps(SUBSTR(bfad_mstr.ad_ctry,1,2)).

  RETURN "".

END FUNCTION. /* getBankCountry */

/* JB10 - remove special characters from char strings */
FUNCTION char_xml RETURNS CHAR
    (INPUT pChar AS CHAR ) :

  IF pChar EQ ? THEN
      pChar = "".

  ASSIGN
      pChar = replace(pChar, "~n", " ")
      pChar = REPLACE(pChar,"~`"," ")
      pChar = REPLACE(pChar,"~~"," ").

  RETURN trim(STRING(pChar)).

END FUNCTION. /* char_xml */

FUNCTION formatCurrency RETURNS CHARACTER
  (vp_currency as char):
  def var vp_result   as char no-undo init "9999999999999.99".
  
  find first cu_mstr no-lock
    where cu_cur = vp_currency no-error.
  if available cu_mstr and cu_rnd_mthd = "0" then
    vp_result = "999999999999999".
  return vp_result.
  
END FUNCTION.

/* Session Trigger JB03 ,
   whenever a ck_mstr record is written to, 
   and the reference is changed, it is an ADD */
ON WRITE OF ck_mstr NEW new-ck_mstr OLD old-ck_mstr DO:    

    /* if they are setting the new ref, we save it */
    IF old-ck_mstr.ck_ref EQ "" AND
       new-ck_mstr.ck_ref NE ""THEN DO :
        FIND ttNewCk 
             WHERE tRowid EQ ROWID(new-ck_mstr) NO-ERROR.
        IF NOT AVAIL(ttNewCk) THEN DO:
            CREATE ttNewCk.
            tRowid = ROWID(new-ck_mstr).
        END.
        ASSIGN
            tDomain = new-ck_mstr.ck_domain
            tBank   = new-ck_mstr.ck_bank
            tRef    = new-ck_mstr.ck_ref.        
    END. /* setting new chk_nbr */
END.  /* write-of */



VCustCode = IF global_domain = "LNAU"  /* The Customer ID for AU is LNFAU  */
                THEN "LNFAU"
            ELSE "LNFNZ" .   /* The Customer ID for NZ is LNFNZ  */
vcreatetime = SUBstr(STRING(TIME,"HH:MM:SS"),1,2) + 
              SUBstr(STRING(TIME,"HH:MM:SS"),4,2) +
              SUBstr(STRING(TIME,"HH:MM:SS"),7,2).
VRemitName  = global_domain + STRING(TODAY,"999999"). 

/* set up the EuroZone countries */
FIND FIRST stdd_det WHERE stdd_det.stdd_domain = global_domain
                      AND stdd_det.stdd_code = 'Vouch'
                      AND stdd_det.stdd_subcode = 'EuroZone' NO-LOCK NO-ERROR.
VEuroZone = IF AVAILABLE stdd_det
    THEN stdd_txtvalue ELSE "".
               

    /* XML END */
           
           
ASSIGN 
    vTempDir = "AUTOPAYM-" + CAPS(GLOBAL_domain).  /* JB05 */

FORM
   bank           colon 25 LABEL "From Bank" VBankName[1] NO-LABEL 
   bank1          colon 25 LABEL "To Bank"   VBankName[2] NO-LABEL 
                  SKIP(1)
   ckdate         colon 25 LABEL "Check Date"
   effdate        colon 25 LABEL "Effective Date"
   audit_trail    colon 25 LABEL "Print Audit Trail"
   print_rmk      colon 25 LABEL "Print Voucher Remarks"
with frame a side-labels width 80.

FORM 
    "Cheque Generation complete ... " SKIP
    "Sending data ... please  wait  " SKIP
    WITH FRAME f CENTERED OVERLAY ROW 12 NO-BOX NO-LABELS.

FORM 
    "Cheque Generation complete ... " SKIP
    "Sending data ... please  wait  " SKIP
    "XML files generated ...wait " SKIP 
    WITH FRAME G CENTERED OVERLAY ROW 12 NO-BOX NO-LABELS.

FORM 
    "No Cheques were Selected" SKIP    
    WITH FRAME h CENTERED OVERLAY ROW 12 NO-BOX NO-LABELS.


FIND FIRST gl_ctrl NO-LOCK 
     WHERE gl_domain EQ global_domain.

EMPTY TEMP-TABLE tVendorTot NO-ERROR.
EMPTY TEMP-TABLE tVendorList NO-ERROR.

repeat:
    HIDE FRAME f.
    HIDE FRAME g.
    CLEAR FRAME a.

   mainloop:
   /* SEPARATED THE USER INTERFACE FROM TRANSACTION BLOCK */
   do on error undo, retry:

      set bank 
          HELP "Enter starting bank"
          with frame a.


      /* VALIDATE FROM BANK */
      for first bk_mstr
          where bk_domain = global_domain and bk_code = bank
      no-lock: end. /* FOR FIRST bk_mstr */

      if not available bk_mstr
      then do:
         /* NOT A VALID BANK */
         {pxmsg.i &MSGNUM=1200 &ERRORLEVEL=3}
         bell.
         next-prompt  bank  with frame a.
         undo mainloop, retry.
      end.
      ELSE
          DISPLAY bk_mstr.bk_desc @ VBankName[1] WITH FRAME a.
         
      RELEASE bk_mstr NO-ERROR.

      set bank1 
           HELP "Enter ending bank" 
          with frame a.

      /* VALIDATE TO BANK */
      for first bk_mstr
          where bk_domain = global_domain and bk_code = bank1
      no-lock: end. /* FOR FIRST bk_mstr */

      if not available bk_mstr
      then do:
         /* NOT A VALID BANK */
         {pxmsg.i &MSGNUM=1200 &ERRORLEVEL=3}
         bell.
         next-prompt  bank1  with frame a.
         undo mainloop, retry.
      end.
      ELSE
          DISPLAY bk_mstr.bk_desc @ VBankName[2] WITH FRAME a.

      IF Bank1 < bank  
      THEN DO:
           MESSAGE "Invalid Bank Range" VIEW-AS ALERT-BOX.
           next-prompt bank1 with frame a.
           undo mainloop, retry.
      END.
      
      UPDATE 
             ckdate
             effdate
             audit_trail
             print_rmk 
             HELP "Press F1 to execute"
          WITH FRAME a.

      {mfmsg.i 832 1} /* Processing ... Please wait */

      RUN ValidateEntries IN THIS-PROCEDURE (OUTPUT VOkay).

      hide message no-pause.

      IF NOT VOkay THEN
          undo mainloop, retry.
      ELSE DO: 
          {mfmsg.i 832 1} /* Processing ... Please wait */

          RUN pGenCIMFile IN THIS-PROCEDURE.

          batchrun = YES.  /* To ignore Pause from user interaction routines */
          run pRunCIMLoad IN THIS-PROCEDURE (INPUT ""). 
          batchrun = NO.
          RUN pGetCIMErrors (OUTPUT VErrorList1,
                             OUTPUT VErrorList2).
          IF VErrorList1 <> "" THEN DO:
              MESSAGE VErrorList1 SKIP
                      VErrorList2  VIEW-AS ALERT-BOX.
              UNDO mainloop, LEAVE.

          END.
          RUN MoveFiles IN THIS-PROCEDURE.

          hide message no-pause.

          IF CAN-FIND(FIRST ttNewCk) THEN DO:
              DISPLAY WITH FRAME F.
              PAUSE 1 NO-MESSAGE.          
              RUN GenerateXML IN THIS-PROCEDURE. 
              HIDE FRAME F.

              DISPLAY WITH FRAME G.
              PAUSE 1 NO-MESSAGE.
          END.
          ELSE DO:
              DISPLAY WITH FRAME h.
              PAUSE 3.
              HIDE FRAME h.
          END.
          
          LEAVE MAinloop.
      END.
   END. /* do on error undo, retry: */
   RUN SENDXML IN THIS-PROCEDURE.
END.




PROCEDURE ValidateEntries:

    DEFINE OUTPUT PARAM VOkay AS LOGICAL NO-UNDO. 

    FOR EACH TBank: DELETE TBank. END.

    EMPTY TEMP-TABLE ttNewCk. /* JB03 */
        MainBlock:
        for each ap_mstr fields( ap_domain ap_amt ap_bank ap_batch ap_ckfrm ap_curr
                                 ap_date ap_effdate ap_entity ap_open ap_ref
                                 ap_remit ap_rmk ap_type ap_vend)
                                 use-index ap_open
                 where ap_mstr.ap_domain = global_domain and ap_open = yes
                   AND ap_type = "VO"
                   and ( ap_bank >= bank AND ap_bank <= bank1 ) NO-LOCK,
            EACH vo_mstr FIELDS ( vo_domain vo_amt_chg vo_disc_chg vo_ref )
                   WHERE  vo_mstr.vo_domain = global_domain and  vo_ref = ap_ref
                     AND (vo_amt_chg <> 0 or vo_disc_chg <> 0) NO-LOCK,
            EACH bk_mstr FIELDS (bk_domain bk_code bk_entity  bk_Check bk_curr )
                         WHERE bk_domain = global_domain
                           and bk_code = ap_bank no-lock:

            FIND bk0_mstr WHERE bk0_domain = global_domain 
                            AND bk0_code   = bk_code NO-LOCK NO-ERROR.
            IF NOT AVAILABLE (bk0) THEN NEXT.

            IF bk0_type = "I" AND NOT CAN-FIND (vd0_mstr WHERE vd0_domain = ap_domain AND 
                                                               vd0_addr   = ap_vend)   
            THEN NEXT.

            FIND TBank WHERE TBank.domain = global_domain
                         AND TBank.Bank   = ap_bank
                         AND TBank.ckfrm  = ap_Ckfrm NO-ERROR.

            IF NOT AVAILABLE TBank 
            THEN DO:
                CREATE TBank.
                ASSIGN TBank.domain = global_domain
                       TBank.Bank   = ap_bank
                       TBank.audit_trail = IF trim(ap_Ckfrm) = "3" THEN TRUE ELSE  audit_trail
                       TBank.print_rmk   = print_rmk
                       TBank.print_test  = print_test
                       TBank.BATCH       = ""
                       TBank.DayBook     = ""
                       TBank.ckfrm       = ap_Ckfrm
                       TBank.ckdate      = ckdate
                       TBank.effdate     = effdate
                       TBank.entity      = bk_entity                       
                       TBank.TYPE        = IF AVAILABLE bk0_mstr
                                           THEN bk0_type ELSE ""
                       TBank.Currency    = bk_mstr.bk_curr  
                       TBank.BaseCurrency = gl_ctrl.gl_base_curr.

                                                             
                TBank.AccountType = IF trim(TBank.ckfrm) = "4" OR trim(TBank.ckfrm) = "3" THEN "EDI" ELSE "". 
                TBank.PaymentFile = TRIM(TBank.Bank) + TRIM(TBank.ckfrm) +
                                    STRING(MONTH(TODAY),"99") + STRING(DAY(TODAY),"99") + 
                                       IF trim(TBank.ckfrm) > "2" THEN ".pmt" ELSE ".CHQ" .

                {gprunp.i "mcpl" "p" "mc-get-ex-rate"
                                    "(bk_mstr.bk_curr,
                                      gl_ctrl.gl_base_curr,
                                      "" "",
                                      TODAY,
                                      OUTPUT fRate,
                                      OUTPUT fRate2,
                                      OUTPUT iErrorCode)"}

               IF iErrorCode = 0 THEN
                   ASSIGN TBank.excRate1 = fRate 
                          TBank.excRate2 = fRate2 . 

                                       
                /* Need to delete the Payment file if it has been already created for today 
                   Trying to run it more than once on the same day will cause QAD to stop
                   processing the payments */
                
                if TBank.PaymentFile <> "" and
                   SEARCH(TBank.PaymentFile) <> ?
                   then OS-DELETE VALUE(TBank.PaymentFile) no-error. 

                assign
                    gl_trans_type = "AP"
                    gl_trans_ent  = TBank.entity
                    gl_effdt_date = TBank.effdate.


                /* PERFORM THE TEST */
                {gprun.i ""gpglef.p""
                     "( input  gl_trans_type,
                        input  gl_trans_ent,
                        input  gl_effdt_date,
                        input  1,
                        output gpglef
                     )" }

                 VOkay = if gpglef > 0 THEN FALSE ELSE TRUE. 
                 IF NOT VOkay THEN LEAVE MainBlock.

            END.
        END.  /* for each ap_mstr */
        
        /* JB06 : if there is ckfrm 1 for international bank,
           we need to warn and exit because apckprt won't 
           handle it */
        FOR EACH TBank :
            IF TBank.currency <> TBank.BaseCurrency AND 
                TBank.ckfrm EQ "1" THEN Do:

                /* International Bank # has payments with Check Form 1 */
                {pxmsg.i &MSGNUM=9654 
                         &ERRORLEVEL=4 
                         &MSGARG1=TBank.Bank
                         &PAUSEAFTER=TRUE}
                vOKAY = FALSE.
            END.  /* ckfrm 1, International */
        END.  /* each TBank */
        /* End JB06 */


END PROCEDURE.  /* ValidateEntries */


procedure pGenCIMFile:

    output stream scim TO value(vTempDir + ".cim").

     FOR EACH TBank:
         /* CIM the Bank Details across */
         put stream scim unformatted
             " " chr(34) + TBank.Bank + chr(34) " ".
         put stream scim skip.   /* Enter Key */

         put stream scim unformatted
             " " chr(34) + TBank.ckfrm + chr(34) " ".
         put stream scim skip.   /* Enter Key */

         IF TBank.ckfrm = "4" OR TBank.ckfrm = "3"
         THEN DO: 
         
             put stream scim unformatted
                 " " chr(34) + TBank.AccountType + chr(34) " ".
             put stream scim skip.   /* Enter Key */
         END.
         else DO:

            /**** Get MFG version *****/
            {gprun.i ""gpgetver.p"" "('1', OUTPUT cVersion)"}
 
            /*** Service Pack 6  ****/
            IF INDEX(cVersion,"SP6") > 0 THEN DO:
                 put stream scim UNFORMATTED                      /* for SP2 do not include , for SP6 include  */
                     " " chr(34) + 'No' + chr(34) " ".            /* for SP2 do not include , for SP6 include  */
                 put stream scim skip.   /* Enter Key */          /* for SP2 do not include , for SP6 include  */
             
            END. 

         end.

         /* JB03 - leave the next cheque number to default by system
         put stream scim unformatted
             " " chr(34) + String(TBank.StartCkNbr,"999999") + chr(34) " ".
           */
         PUT STREAM scim UNFORMATTED " - ".   /* JB03 */

         put stream scim unformatted
             " " chr(34) + String( TBank.ckdate,"99/99/99") + chr(34) " ".
      

         put stream scim unformatted
         " " chr(34) + String(TBank.EFFdate,"99/99/99") + chr(34) " ".
         

         put stream scim unformatted
         " " chr(34) + (IF TBank.audit_trail THEN 'Yes' ELSE 'No') + chr(34) " ".
       

                                                            
         put stream scim unformatted
         " " chr(34) + (IF TBank.print_rmk THEN 'Yes' ELSE 'No')  + chr(34) " ".
        

         put stream scim unformatted
         " " chr(34) + (IF TBank.print_test THEN 'YES' ELSE "No")  + chr(34) " ".
         put stream scim skip.
 
          
         IF TBank.currency <> TBank.BaseCurrency AND TBank.ckfrm = "3" then Do:
              put stream scim skip.
              

              /* 
              put stream scim unformatted
                       " " chr(34) + "0.75"  + chr(34) " ".
              put stream scim unformatted
                       " " chr(34) + "1.0"  + chr(34) " ".          
              */

              put stream scim unformatted
                       " " chr(34) + string(TBank.excRate1)  + chr(34) " ".
              put stream scim unformatted
                       " " chr(34) + string(TBank.excRate2)  + chr(34) " ".  



             put stream scim skip.
         end.
         

         IF TBank.ckfrm = "4" THEN DO:        
             put stream scim unformatted
                 " " chr(34) + TBank.PaymentFile  + chr(34) " ".
             put stream scim skip.   /* Enter Key */
         END.

         /* output to anywhere except a printer - we no longer print the cheques */
         put stream scim unformatted
         " " chr(34) + "out1"  + chr(34) " ".
         put stream scim skip.   /* Enter Key */

         /* have all cheques printed correctly? OR All Payments have been processed */
         put stream scim skip(1).   /* Enter Key */



         IF TBank.ckfrm = "1" OR TBank.ckfrm = "3"   /* Payment Specifications */
         THEN DO:
             put stream scim unformatted
                 " " chr(34) + "out2"  + chr(34) " ".
             put stream scim skip.   /* Enter Key */
         END.

         /* 
         IF TBank.audit_trail THEN DO:
             put stream scim SKIP(1).   /* Enter Key */
             put stream scim SKIP(1).   /* Enter Key */
         END.
         */

         /* Jim - added this 14/03/2008*/
         /* IF  TBank.ckfrm = "3"  THEN  put stream scim skip.  */
         
     END.
      
     put stream scim " " ".".   /* End */
     output stream scim close.

end procedure.


procedure pRunCIMLoad:
     
DEF INPUT PARAMETER ip_type AS CHARACTER NO-UNDO.
    
   output to
     value(vTempDir + ".out").

   input from
       value(vTempDir + ".cim").
    
    {gprun.i ""apckprt.p""}  
   
    input close.
    output close.
end procedure.

PROCEDURE MoveFiles:

      DEF VAR VCommand AS CHAR NO-UNDO.
      DEF VAR VTime    AS CHAR NO-UNDO.
      DEF VAR NewFile  AS CHAR NO-UNDO.
      
      VTime = STRING(TIME,"HH:MM:SS").
      Vtime = REPLACE (VTime ,":" , "").
      

      FOR EACH Tbank WHERE trim(TBank.ckfrm) = "4" OR trim(TBank.ckfrm) = "3"  :
           NewFile = trim(Tbank.PaymentFile) + STRING(TODAY,"999999") + VTime. 

          OS-RENAME value(Tbank.PaymentFile) VALUE(NewFile).

      END.


END.

PROCEDURE GenerateXML:


    FIND FIRST stdd_det WHERE stdd_det.stdd_domain = global_domain
                          AND stdd_det.stdd_code = 'ExtMsg'
                          AND stdd_det.stdd_subcode = 'SSID'
                          AND ENTRY(1,stdd_det.stdd_txtvalue) BEGINS 'MFG'
                        NO-LOCK NO-ERROR.
    vSSID = IF AVAIL stdd_det 
            THEN ENTRY(2, stdd_det.stdd_txtvalue) ELSE "MFG".

    /* make sure the temp table has the latest DB values..
       this is because we don't trust the trigger, so we stored
       rowid's, and now we refresh them  JB03 */

    OUTPUT TO VALUE("cheques-debug-" + LC(global_domain) + ".out") /* JB05 */
        UNBUFFERED APPEND.  
    PUT UNFORMATTED "Run Date / Time : " string(today) " " string(time,"hh:mm:ss") skip.
    FOR EACH ttNewCk :
        FIND ck_mstr NO-LOCK WHERE ROWID(ck_mstr) EQ tRowid NO-ERROR.
        IF AVAIL(ck_mstr) THEN DO:
            ASSIGN
                ttNewCk.tDomain = ck_domain
                ttNewCk.tBank   = ck_bank
                ttNewCk.tRef    = ck_ref.        
            PUT UNFORMATTED " " ck_ref SKIP.
        END.  /* avail ck_mstr */        
    END.  /* each ttNewCk */
    PUT SKIP.
    OUTPUT CLOSE.  /* Jb03 */


    FOR EACH TBank BREAK BY TBank.TYPE:
        IF FIRST-OF(TBank.TYPE) 
            THEN RUN BuildXML (INPUT TBank.TYPE).

    END.

END PROCEDURE. /* GenerateXML */



PROCEDURE BuildXML:

    DEF INPUT PARAM VBankType AS CHAR NO-UNDO.


    vDoctype = IF VBankType = "D" 
               THEN "ACEDomBankXML"
               ELSE "ACEIntBankXML".


     ASSIGN vKeyValue    = "ck_ref" + string(TODAY,"999999") + STRING(TIME)
            VTotPayments = 0
            VTotRemit    = 0
            VHashTot     = 0
            vTableName = "ck_mstr"
            VTotLin      = 0.

    DO VPass = 1 TO 2: 
   

        FOR EACH BufTbank 
           WHERE BufTbank.TYPE = VBankType,  /* Domestic/International */
            EACH ttNewCk
           WHERE ttNewCk.tDomain = global_domain
             AND ttNewCk.tBank   = bufTBank.Bank,
            EACH ck_mstr 
           WHERE ck_domain =  global_domain
             AND ck_ref    = ttNewCk.tRef NO-LOCK, 
            EACH ckd_det 
           WHERE ckd_domain = global_domain
             AND ckd_ref    = ck_ref NO-LOCK,
            EACH ap_mstr 
           WHERE ap_domain = ck_domain
             AND ap_type   = "CK"
             AND ap_ref    = ckd_ref 
             AND ap_ckfrm  = BufTBank.ckfrm  NO-LOCK, /* JB03 */            
           FIRST ad_mstr 
           WHERE ad_mstr.ad_domain = global_domain
             and ad_mstr.ad_addr   = ap_mstr.ap_vend NO-LOCK,
           FIRST vo_mstr 
           WHERE vo_domain = ck_domain
             AND vo_ref    = ckd_voucher NO-LOCK,
           FIRST Bk_mstr 
           WHERE Bk_mstr.bk_domain = global_domain
             AND Bk_mstr.Bk_code   = BufTbank.Bank NO-LOCK BREAK 
            BY BufTbank.TYPE 
            BY Bk_mstr.Bk_code
            BY ap_mstr.ap_vend 
            BY ck_mstr.ck_ref:


            IF VPass = 1  THEN DO: /* Accumulate totals */
    
                RUN AccumTotalPerVendor (Bk_mstr.Bk_code,
                                         ap_mstr.ap_vend,
                                         ckd_amt,
                                         ROWID(ckd_det),
                                         ck_mstr.ck_ref,
                                         ck_nbr,
                                         vo_ref,
                                         vo_invoice,
                                         ap_date,
                                         ap_rmk,
                                         ap_ckfrm,
                                         vo_type,
                                         Bk_mstr.Bk_curr).
                                    


            END.  /* vVass = 1 */

            ELSE DO: /*  IF VPass = 2  - process */

                /* this is Domestic XML */
                IF VBankType = "D" THEN DO:
        
                    IF FIRST(BufTbank.TYPE) THEN DO:
        
                        vcreatetime = SUBstr(STRING(TIME,"HH:MM:SS"),1,2) + 
                                      SUBstr(STRING(TIME,"HH:MM:SS"),4,2) +
                                      SUBstr(STRING(TIME,"HH:MM:SS"),7,2).
        
                        VPayRef     = STRING(DAY(TODAY),"99") +
                                      STRING(MONTH(TODAY),"99") + vcreatetime.

                        /* Prepare header */
                        ASSIGN 
                            vParameters =   global_domain
                                + "~n" + vSSID    /* header */  
                                + "~n" + VIdentifier /* header */
                                + "~n" + VCustCode  /* header */
                                + "~n" + STRING(VCreateDate,"99/99/99") /* header */
                                + "~n" + VCreateTime /* header */
                                + "~n" + VRemitName  /* header */
                                + "~n" + VPayRef /* header end */ .
            
                         /* vParameters = vParameters + "~n<EndLoop>" .    */
             
                        /* Header Send */
                        run NotifySbl.p (?,                                           
                             vDocType,
                             vTableName,               /* Table Name     */
                             vKeyValue,                /* Key Value      */
                             vaction,                  /* Action         */
                             vParameters,              /* Parameter List */  
                             ?,              /* A copy of the Current record */ 
                             OUTPUT vStatus).
                    END. /* IF FIRST(BufTbank.TYPE)  */

                    
                    /* JB08 : get the country from the bank */
                    vCountryCode = getBankCountry(Bk_mstr.Bk_code).                    

                    FIND LAST vod_det 
                        WHERE vod_det.vod_domain = global_domain 
                          AND vod_det.vod_ref    = vo_ref 
                          USE-INDEX vod_ref NO-LOCK NO-ERROR.
                    VRemitMultiLines = vod_det.vod_ln . /* last line nbr used */

                    FIND FIRST vod_det 
                         WHERE vod_det.vod_domain = global_domain 
                           AND vod_det.vod_ref    = vo_ref 
                        NO-LOCK USE-INDEX vod_ref.

                    vRemitdate  = STRING(TODAY).
                    VRemarks1 = ''.
        
                    IF LAST-OF(ap_mstr.ap_vend) THEN DO:  
   
                        VtotVendPayments = 0.  /* total payment for a particular Vendor */
                        FOR EACH TVendorTOT 
                           WHERE TVendorTOT.TBankCode = Bk_mstr.Bk_code  
                             AND TVendorTOT.TVendor   = ap_mstr.ap_vend 
                           BREAK BY TVendorTOT.TCkref :

                            IF FIRST-OF(TVendorTOT.TCkref) THEN
                                VtotVendPayments = 0.  /* total payment for a particular Vendor */

                            VtotVendPayments =  VtotVendPayments + TVendorTOT.TTOTAL.

                            IF LAST-OF(TVendorTOT.TCkref) THEN DO:

                                ASSIGN VBBSB = ""
                                       VBAccount = "".

                                /* get BSB and account details */
                                FIND FIRST csbd_det WHERE csbd_domain = global_domain
                                                       AND csbd_addr   = ap_mstr.ap_vend
                                                       AND csbd_bank   = Bk_code NO-LOCK NO-ERROR.
                                IF NOT AVAILABLE csbd_det THEN
                                    FIND FIRST csbd_det 
                                         WHERE csbd_domain = global_domain
                                           AND csbd_addr   = ap_mstr.ap_vend NO-LOCK NO-ERROR.

                                IF TVendorTOT.Tckfrm = '4' THEN
                                     ASSIGN VBBSB = IF AVAIL csbd_det THEN csbd_branch ELSE ""
                                            VBAccount = IF AVAIL csbd_det THEN csbd_bk_acct ELSE "".

                                VPaymentType = IF TVendorTOT.TCkFrm = "1" THEN  "C" ELSE "D". /* Cheques for now *  C = Cheques, D = EFT */
        
                                IF VPaymentType = "C" THEN  
                                    VRemitType = "P".
                                ELSE DO:
                                    FIND vd_mstr WHERE vd_domain = global_domain
                                                   AND vd_addr   = ad_addr NO-LOCK.

                                    /* DN01 */
                                    VRemitType = (IF vd_mstr.vd__chr09 MATCHES "*@*" THEN "E"
                                                  ELSE (IF vd_mstr.vd__chr09 = "" THEN "N"
                                                        ELSE "F")).

                                END.
        
                                IF VRemitType = "E" THEN  /* Send the email address */
                                    ASSIGN Vaddr1    = substr(vd_mstr.vd__chr09,1,35)
                                           Vaddr2    = substr(vd_mstr.vd__chr09,36)
                                           Vaddr3    = ""
                                           VaddrCity = ""
                                           VaddrState = ""
                                           VaddrZip   = "".
                                ELSE ASSIGN Vaddr1     = ad_mstr.Ad_Line1
                                            Vaddr2     = ad_mstr.Ad_Line2
                                            Vaddr3     = ad_mstr.Ad_Line3
                                            VaddrCity  = ad_mstr.ad_City
                                            VaddrState = ad_mstr.ad_State
                                            VaddrZip   = ad_mstr.ad_Zip. 
        
                                VDelType     = IF VRemitType = "P" THEN "P" ELSE "N" . 
        
                                /* if this is a cheque payment and vo_type = "R" then
                                   the cheque is to be returned to Lion Nathan to 
                                   be hand delivered later on */
                                IF TVendorTOT.TType = "R" AND VPaymentType = "C" THEN
                                     VDelType = "R" .
        
                                IF VPaymentType = "C" THEN
                                    ASSIGN VBBSB = ""
                                           VBAccount = ""
                                           VChKNbr = string(TVendorTOT.TChKNbr, "9999999").
                                else 
                                    VChKNbr = "".
                                   
                                VFaxNumber = IF VRemitType = "F" THEN vd_mstr.vd__chr09 ELSE "".        /*DN02*/
        
                                /* get the Remarks */
                                FIND FIRST BufAp_Mstr 
                                     WHERE BufAp_Mstr.ap_domain = GLOBAL_domain
                                       AND BufAp_Mstr.ap_type = "VO"
                                       AND BufAp_Mstr.ap_ref = TVendorTOT.TVoRef NO-LOCK NO-ERROR.
                                VRemarks = IF AVAILABLE BufAp_Mstr 
                                                   THEN BufAp_Mstr.ap_rmk
                                               ELSE "".
                                /* VNarrative   = "LionNathan" + STRING(TVendorTOT.TCkref).  JB04 */

                                /* Set the Narrative  JB04 */                                                     
                                /* if this is for the ATO (ie: type REF) then send the voucher remarks */
                                IF vo_mstr.vo_type EQ "REF" AND
                                   AVAIL(BufAp_mstr) AND 
                                   BufAP_mstr.ap_rmk NE "" THEN
                                    vNarrative = BufAP_mstr.ap_rmk.

                                ELSE DO:  /* JB04 - otherwise get the Narritive Prefix from Standard Table */
                                    {gprun.i ""xxstdtabgt.p"" "( ""TRBANK"", ""Narrative"", OUTPUT vNarrative)"}.
                                    /* Default to LionNathan */
                                    IF vNarrative EQ "" THEN vNarrative = "LionNathan".
                                    vNarrative = vNarrative + STRING(TVendorTOT.TCkref).
                                END.  /* JB04 */
                                
                                VRemarks1    = ap_mstr.ap_vend.  
                                IF VtotVendPayments = 0 THEN VDomPaymentType = "R".
                                                        ELSE VDomPaymentType = VPaymentType.
        
                                /* JB13 - put invoice number at char 61- */                                   
                                IF TVendorTOT.TInvoice NE "" THEN
                                    ASSIGN
                                    vRemarks = IF vRemarks EQ "" THEN "." ELSE vRemarks
                                    SUBSTR(VRemarks,61) = SUBSTR(TVendorTOT.TInvoice,1,20).

                                vParameters = 
                                            VLineIdent    /* detail Line 02 */
                                            + "~n" + TVendorTOT.TCkref 
                                            /* + "~n" + ap_mstr.ap_vend */
                                            + "~n" + string(VtotVendPayments * 100, "9999999999999")
                                            + "~n" + bk_mstr.Bk_curr 
                                            + "~n" + ad_mstr.Ad_name
                                            + "~n" + Vaddr1
                                            + "~n" + Vaddr2
                                            + "~n" + Vaddr3
                                            + "~n" + VaddrCity /* City */
                                            + "~n" + VaddrState
                                            + "~n" + VaddrZip 
                                            + "~n" + VDomPaymentType
                                            + "~n" + VRemitType
                                            + "~n" + VDelType 
                                            + "~n" + "3"    /* Delivery Priority */ 
                                            + "~n" + VFaxNumber
                                            + "~n" + char_xml(VNarrative)  /* JB10 */
                                            + "~n" + char_xml(VRemarks1)   /* JB10 */
                                            /* + "~n" + string(TVendorTOT.TChKNbr, "9999999") */
                                            + "~n" + VChKNbr 
                                            + "~n" + VCountryCode 
                                            + "~n" + VBBSB      
                                            + "~n" + VBAccount
                        
                                            /* Remit here 03 */
                                            + "~n" + VRemitLine   /* static */
                                            + "~n" + TVendorTOT.TInvoice
                                            + "~n" + string(TVendorTOT.TDate,"99/99/99")
                                            + "~n" + string(abs(TVendorTOT.TTOTAL * 100), "9999999999999")
                                            + "~n" + (IF TVendorTOT.TTOTAL> 0 THEN "+" ELSE "-")
                                            + "~n" + string(abs(TVendorTOT.TTOTAL * 100), "9999999999999")
                                            + "~n" + (IF TVendorTOT.TTOTAL > 0 THEN "+" ELSE "-")
                                            + "~n" + char_xml(VRemarks)  .   /* JB10 */
        
                        
                                 FIND NEXT BufTVendorTOT 
                                     WHERE BufTVendorTOT.TBankCode = Bk_mstr.Bk_code  
                                       AND BufTVendorTOT.TVendor   = ap_mstr.ap_vend 
                                       AND BufTVendorTOT.TCkref    = TVendorTOT.TCkref 
                                       AND recid(BufTVendorTOT) <> recid(TVendorTOT) NO-ERROR.
                                 IF NOT AVAILABLE BufTVendorTOT 
                                     THEN  vParameters = vParameters + "~n<EndLoop>" . 
                        
                                 run NotifySbl.p (?,                                           
                                         vDocType,
                                         vTableName,               /* Table Name     */
                                         vKeyValue,                /* Key Value      */
                                         vaction,                  /* Action         */
                                         vParameters,              /* Parameter List */
                                         ?,              /* A copy of the Current record */ 
                                         OUTPUT vStatus).                          
                        
                                /* ACCUMULATE totals etc */
                                VTotPayments = VTotPayments + 1.
                                VTotRemit =  VTotRemit + 1.
                                VHashTot     = VHashTot +  VtotVendPayments.
                           
                                DO WHILE AVAILABLE  BufTVendorTOT:
        
                                     /* get the Remarks */
                                    FIND FIRST BufAp_Mstr WHERE BufAp_Mstr.ap_domain = GLOBAL_domain
                                                          AND BufAp_Mstr.ap_type = "VO"
                                                          AND BufAp_Mstr.ap_ref = BufTVendorTOT.TVoRef NO-LOCK NO-ERROR.

                                    VRemarks = IF AVAILABLE BufAp_Mstr 
                                                   THEN BufAp_Mstr.ap_rmk
                                               ELSE "".  

                                    /* JB13 - put invoice number at char 61- */
                                    IF BufTVendorTOT.TInvoice NE "" THEN
                                    ASSIGN
                                        vRemarks = IF vRemarks EQ "" THEN "." ELSE vRemarks
                                        SUBSTR(VRemarks,61) = SUBSTR(BufTVendorTOT.TInvoice,1,20).
        
                                    vParameters = 
                                             VRemitLine   /* static */
                                            + "~n" + BufTVendorTOT.TInvoice
                                            + "~n" + string(BufTVendorTOT.TDate,"99/99/99")
                                            + "~n" + string(abs(BufTVendorTOT.TTOTAL * 100), "9999999999999")
                                            + "~n" + (IF BufTVendorTOT.TTOTAL> 0 THEN "+" ELSE "-")
                                            + "~n" + string(abs(BufTVendorTOT.TTOTAL * 100), "9999999999999")
                                            + "~n" + (IF BufTVendorTOT.TTOTAL > 0 THEN "+" ELSE "-")
                                            + "~n" + char_xml(VRemarks).   /* JB10 */
                
                                     FIND NEXT BufTVendorTOT WHERE BufTVendorTOT.TBankCode = Bk_mstr.Bk_code  
                                                               AND BufTVendorTOT.TVendor   = ap_mstr.ap_vend 
                                                               AND BufTVendorTOT.TCkref    = TVendorTOT.TCkref 
                                                               AND recid(BufTVendorTOT) <> recid(TVendorTOT) NO-ERROR.
                                     IF NOT AVAILABLE BufTVendorTOT 
                                         THEN  vParameters = vParameters + "~n<EndLoop>" . 
                
                                     run NotifySbl.p (?,
                                         vDocType,
                                         vTableName,               /* Table Name     */
                                         vKeyValue,                /* Key Value      */
                                         vaction,                  /* Action         */
                                         vParameters,              /* Parameter List */
                                         ?,              /* A copy of the Current record */ 
                                         OUTPUT vStatus). 
                                    VTotRemit =  VTotRemit + 1.
                
                
                                END.  /*  DO WHILE AVAILABLE  TVendorTOT: */

                            end. /* IF LAST-OF(TVendorTOT.TCkref)  */

                        END. /* FOR EACH TVendorTOT WHERE TVendorTOT.TBankCode = Bk_mstr.Bk_code */
   
                    END.  /* IF LAST-OF(ap_mstr.ap_vend) THEN DO: */

                    /* Trailer */
                    IF LAST(Bk_mstr.Bk_code) AND
                       LAST(ck_mstr.ck_ref) 
                    THEN DO:
        
                        vParameters = "~n<EndLoop>". 
            
                        run NotifySbl.p (?,                                           
                             vDocType,
                             vTableName,               /* Table Name     */
                             vKeyValue,                /* Key Value      */
                             vaction,                  /* Action         */
                             vParameters,              /* Parameter List */
                             ?,              /* A copy of the Current record */ 
                             OUTPUT vStatus). 
                    
                        vParameters =
                               VTrailIdent
                               + "~n" + string(VTotPayments,"99999") 
                               + "~n" + string(VTotRemit,"99999")   
                               + "~n" + string(VHashTot * 100, "999999999999999").
            
                        run NotifySbl.p (?,                                           
                                vDocType,
                                vTableName,               /* Table Name     */
                                vKeyValue,                /* Key Value      */
                                vaction,                  /* Action         */
                                vParameters,              /* Parameter List */
                                ?,              /* A copy of the Current record */ 
                                OUTPUT vStatus). 
                    END.
        
                END. /* IF VBankType = "D"  /* this is Domestic XML */ */
    
                /* this is International XML */
                ELSE DO: /* IF VBankType = "I"   */
        
                    IF FIRST(BufTbank.TYPE) THEN DO:  /* Create Header record */
                        /* Time is HHMM */
                        vcreatetime = SUBstr(STRING(TIME,"HH:MM:SS"),1,2) + 
                                      SUBSTR(STRING(TIME,"HH:MM:SS"),4,2).

                        vCreateDate1 = STRING(TODAY) .
                        vCenturyDate = STRING(TODAY).
                        
                        VLineNo      = 1.
                        VTotLin      = 1.
        
                        {gprun.i ""xxstdtabgt.p"" "( ""TRBANK"", ""VIdentifier"", OUTPUT VIdentifier)"}.
                        {gprun.i ""xxstdtabgt.p"" "( ""TRBANK"", ""VRecipient"",  OUTPUT VRecipient)"}.
                        ASSIGN VIdentifier   = "ABC10310001" when VIdentifier = "" /* this is our code to HSBC */
                               VRecipient    = "HEXAGON-ABC" when VRecipient  = "" /* BA01 Added - */
                               VPriorityCode = "V" 
                               VControlRef   = TRIM(global_domain) + vCreateDate1 +
                                               TRIM(vcreatetime)
                               .

                        /* JB01 - get the next sequence */
                        DEFINE VARIABLE lHadError  AS LOGICAL     NO-UNDO.
                        DEFINE VARIABLE iErrorCode AS INTEGER     NO-UNDO.

                        RUN getnbr("TBCtrlRf",
                                   TODAY,
                                   OUTPUT VControlRef,
                                   OUTPUT lHadError,
                                   OUTPUT iErrorCode).
        
                        ASSIGN 
                           vParameters = global_domain
                                    + "~n" + vSSID            /* header */  
                                    + "~n" + VIdentifier      /* header */
                                    + "~n" + VRecipient       /* header */
                                    + "~n" + VCreateDate1     /* header */
                                    + "~n" + VCreateTime      /* header */
                                    + "~n" + VControlRef      /* header */
                                    + "~n" + VPriorityCode    /* header */   
                                    + "~n" + vCenturyDate .   /* header end */ 
               
                        run NotifySbl.p (?,                                           
                             vDocType,
                             vTableName,               /* Table Name     */
                             vKeyValue,                /* Key Value      */
                             vaction,                  /* Action         */
                             vParameters,              /* Parameter List */
                             ?,              /* A copy of the Current record */ 
                             OUTPUT vStatus).  
                    END.   /* Create Header record */

                    IF FIRST-OF(Bk_mstr.Bk_code) THEN DO:

                        FOR EACH TVendorList WHERE TVendorList.TBankCode = Bk_mstr.Bk_code:
                            FIND vd0_mstr WHERE vd0_mstr.vd0_Domain = global_domain
                                            AND vd0_mstr.vd0_addr   = TVendorList.TVendor NO-LOCK NO-ERROR.

                            FIND bk0_mstr WHERE bk0_domain = global_domain
                                            AND bk0_code   = Bk_mstr.Bk_code NO-LOCK.
                            RUN SETPriorityNumber (OUTPUT VPriorityNumber).
                             
                            ASSIGN TVendorList.TPriorityNumber = VPriorityNumber
                                   TVendorList.TSortby         = IF VPriorityNumber = "52" THEN "A" ELSE "B".  
                        END.

                        VAlreadyPrinted = FALSE. 

                        FOR EACH TVendorList WHERE TVendorList.TBankCode = Bk_mstr.Bk_code 
                                                BY TVendorList.TBankCode
                                                BY TVendorList.TSortby:

                            FIND vd0_mstr WHERE vd0_mstr.vd0_Domain = global_domain
                                            AND vd0_mstr.vd0_addr   = TVendorList.TVendor NO-LOCK NO-ERROR.

                            /* RUN SETPriorityNumber (OUTPUT VPriorityNumber). */
                            
/*                             IF ( CAN-DO(VIntCurrencyList,bk_curr) OR TVendorList.TPriorityNumber = "52" )  JBzz */

                            /* JB15 - we are splitting *ALL* payments since adding remittances */
                            IF TRUE THEN DO:
                                RUN Print2 (INPUT TVendorList.TPriorityNumber) . /* this is for Euros or high priority  */
                                VPrint  = FALSE.

                            END.
                            ELSE DO: 
                                RUN Print4 .  /* all other currencies */ 
                                VPrint = TRUE.
                                VAlreadyPrinted = TRUE. 
                            END.
                            ASSIGN TVendorList.TALreadyPrinted = TRUE.
                           
                        END.
                        
                    END. /* IF FIRST-OF(Bk_mstr.Bk_code)  */

                    /* accumulate the total payments for a particular Vendor */


                    IF LAST(Bk_mstr.Bk_code) THEN 
                        DO:
                        
                            vParameters = "~n<EndLoop>". 
            
                            run NotifySbl.p (?,                                           
                                 vDocType,
                                 vTableName,               /* Table Name     */
                                 vKeyValue,                /* Key Value      */
                                 vaction,                  /* Action         */
                                 vParameters,              /* Parameter List */
                                 ?,              /* A copy of the Current record */ 
                                 OUTPUT vStatus).  
                    END. /* IF LAST(Bk_mstr.Bk_code) THEN  */

                END. /*  ELSE DO:  */ /* IF VBankType = "I"  */
    
            END. /* else if Vpass*/
    
        END. /* FOR EACH BufTbank */
   END. /* Do pass = 1 to 2 */

END PROCEDURE.  /* BuildXML */

PROCEDURE pGetCIMErrors:

   DEF OUTPUT PARAM VErrorList1 AS CHAR NO-UNDO.
   DEF OUTPUT PARAM VErrorList2 AS CHAR NO-UNDO.

   INPUT STREAM scim FROM VALUE(vTempDir + ".out").

   ERRORLOOP:
   REPEAT:
      IMPORT STREAM scim UNFORMATTED pString.
      if pString MATCHES "*WARNING:*" OR 
         pString MATCHES "*ERROR:*" OR
        (pstring MATCHES "*. (*)" AND pString BEGINS "**") THEN
      DO:
         IF pString MATCHES "*WARNING:*" THEN
            ASSIGN pErrStatus = 2.
         ELSE
            ASSIGN pErrStatus = 3.

         IF pErrStatus = 3 THEN do:
             ASSIGN VErrorList1 = "ERROR: Cannot process checks - Review then following " 
                    VErrorList2 = "output file to see the Errors - " + "'" + STRING(vTempDir) + ".out" + "'".

             LEAVE ERRORLOOP.
         END.
      END.
   END.

END PROCEDURE.


PROCEDURE AccumTotalPerVendor:

    DEF INPUT PARAM IPBkCode LIKE Bk_mstr.Bk_code NO-UNDO.
    DEF INPUT PARAM IPVend   LIKE ap_mstr.ap_vend NO-UNDO.
    DEF INPUT PARAM IPAmount LIKE ckd_amt         NO-UNDO.
    DEF INPUT PARAM IPRowid  AS ROWID             NO-UNDO.
    DEF INPUT PARAM IPChkRef LIKE ck_mstr.ck_ref  NO-UNDO.
    DEF INPUT PARAM IPChkNbr LIKE ck_nbr          NO-UNDO.
    DEF INPUT PARAM IPVoRef  LIKE Vo_ref          NO-UNDO.
    DEF INPUT PARAM IPInvoice LIKE vo_invoice     NO-UNDO.
    DEF INPUT PARAM IPDate    AS DATE             NO-UNDO.
    DEF INPUT PARAM IPRemarks LIKE ap_rmk         NO-UNDO.
    DEF INPUT PARAM IPCkFrm   LIKE ap_ckfrm       NO-UNDO.
    DEF INPUT PARAM IPType    LIKE vo_type        NO-UNDO.
    DEF INPUT PARAM IPCurrency  AS CHAR           NO-UNDO.
    


    FIND FIRST TVendorTOT WHERE TVendorTOT.TBankCode = IPBkCode 
                            AND TVendorTOT.TVendor   = IPVend
                            AND TVendorTOT.TCkref    = IPChkRef
                            AND TVendorTOT.TRowid    = IPRowid NO-ERROR.

    IF NOT AVAILABLE TVendorTOT THEN
    DO:
        CREATE TVendorTOT.
        ASSIGN TVendorTOT.TBankCode = IPBkCode
               TVendorTOT.TVendor   = IPVend
               TVendorTOT.TCkref    = IPChkRef
               TVendorTOT.TTotal    = IPAmount
               TVendorTOT.TChKNbr   = IPChkNbr
               TVendorTOT.TVoRef    = IPVoRef
               TVendorTOT.TRowid    = IPRowid
               TVendorTOT.TInvoice  = IPInvoice
               TVendorTOT.TDate     = IPDate
               
               TVendorTOT.TCkFrm    = IPCkFrm
               TVendorTOT.TType     = IPType
               TVendorTOT.TCurrency = IPCurrency.
        TVendorTOT.TRemarks  = char_xml(IPRemarks) /* JB10 */.
               
    END.

    IF NOT CAN-FIND(FIRST TVendorList WHERE TVendorList.TBankCode = IPBkCode
                                        AND TVendorList.TVendor   = IPVend)
    THEN DO:
        CREATE TVendorList.
        ASSIGN TVendorList.TBankCode = IPBkCode
               TVendorList.TVendor   = IPVend.
    END.


END PROCEDURE.



PROCEDURE Print2:  /* euros or HVP 52 */

    DEF INPUT PARAM VPriorityNumber AS CHAR NO-UNDO.

    FOR EACH TVendorTOT 
        WHERE TVendorTOT.TBankCode = Bk_mstr.Bk_code
          AND TVendorTOT.TVendor   = TVendorList.TVendor
        BREAK BY TVendorTOT.TVendor :

        IF FIRST-OF(TVendorTOT.TVendor) THEN
            ASSIGN 
                VTotalDebits     = 0
                VtotVendPayments = 0.
        
        VTotalDebits     = VTotalDebits + TVendorTOT.TTOTAL.
        VtotVendPayments = VtotVendPayments + TVendorTOT.TTOTAL.

        IF LAST-OF(TVendorTOT.TVendor) 
        THEN DO:


            FIND bk0_mstr WHERE bk0_domain = global_domain
                            AND bk0_code   = Bk_mstr.Bk_code NO-LOCK.
        
            /* DEBIT DETAILS */

            /* JB01 added global_domain when changed above vControlRef */
            VDebitRef  = TRIM(Bk_mstr.Bk_code)  + " " + 
                         TRIM(CAPS(global_domain)) + 
                         VControlRef.
            
            /* Waiting for HSBC notice  
               VDebitRef  = trim(TVendorTOT.Tckref) + " " + TRIM(CAPS(global_domain)) + VControlRef. */
        
            run getCompanyAddress(global_domain, 
              output vcSort, output vcAddr1, output vcAddr2, 
              output vcAddr3, output vcState, output vcZip, output vcCtry).

            /* find the translation code for the country code iso 316 */
            VBeneLocation = getISO316(vcCtry).                 /* TLF  */            
            VPartyAcctLoc = getISO316(bk0_mstr.bk0_dacountry). /* JB02 */


            vParameters = TRIM(STRING(VLineNo)) 
                   /*  + "~n" + vCenturyDate  */
                    + "~n" + VDebitRef                            
                    + "~n" + bk_mstr.Bk_Bk_acct1
                    + "~n" + bk_mstr.Bk_Bk_acct2
                    + "~n" + trim(string(VTotalDebits,formatCurrency(bk_mstr.Bk_Curr)))  
                    + "~n" + bk_mstr.Bk_Curr
                    + "~n" + bk0_mstr.bk0_dbswift 
                    + "~n" + vcSort 
                    + "~n" + vcAddr1
                    + "~n" + vcAddr2
                    + "~n" + vcAddr3
                    + "~n" + vcCity
                    + "~n" + vcZip
                    + "~n" + VBeneLocation  
                    + "~n" + VPartyAcctLoc. 
        
        
            run NotifySbl.p (?,
                 vDocType,
                 vTableName,               /* Table Name     */
                 vKeyValue,                /* Key Value      */
                 vaction,                  /* Action         */
                 vParameters,              /* Parameter List */
                 ?,              /* A copy of the Current record */
                 OUTPUT vStatus).  
        
        
            assign
                VLineNo = VLineNo + 1
                VTotLin = VTotLin + 1
                VSeqNo = 1.
        
            /* End of debit line */
        
            /***************
        
            FIND vd_mstr WHERE vd_domain = global_domain
                            AND vd_addr   = ad_mstr.ad_addr NO-LOCK.
        
            FIND vd0_mstr WHERE vd0_mstr.vd0_Domain = vd_mstr.vd_Domain
                             AND vd0_mstr.vd0_addr   = vd_addr NO-LOCK NO-ERROR.
                             
            *******************/

            FIND vd_mstr WHERE vd_domain = global_domain
                            AND vd_addr   = TVendorTOT.TVendor NO-LOCK.
        
            FIND vd0_mstr WHERE vd0_mstr.vd0_Domain = vd_mstr.vd_Domain
                             AND vd0_mstr.vd0_addr   = vd_addr NO-LOCK NO-ERROR.

            FIND FIRST buf1ad_mstr where buf1ad_mstr.ad_domain = global_domain
                                and buf1ad_mstr.ad_addr = vd_addr NO-LOCK.

            
             /* find the translation code for the country code iso 316 */        
            VBeneLocation = getISO316(buf1ad_mstr.ad_ctry).    /* JB02 */        
            VPaymentRef = "LionNathan" + TVendorTOT.Tckref.
            VCreditRef  = TRIM (GLOBAL_DOMAIN) + TVendorTOT.Tckref.

            IF TRIM (buf1ad_mstr.ad_line1) = "" THEN Vaddr1 = ".".  /* MM */
                                                ELSE Vaddr1 =  buf1ad_mstr.ad_line1.
            IF AVAILABLE (vd0_mstr) THEN DO:
                ASSIGN
                VBeneAcccount  = Vd0_BeneAcccoun
                VBeneHolder    = Vd0_BeneHolder
                VCurrency      = caps(Vd0_Currency)   /* JB07 CAPS */
                VSwift         = Vd0_Swif
                VBeneRoute1    = Vd0_BeneRoute1
                VBeneRouteType = caps(Vd0_BeneRouteType) /* JB07 */
                VAcctLocation  = getISO316(vd0_mstr.vd0_AcctLoc).  /* JB02 */    .
            END.
            ELSE DO:
                ASSIGN
                VBeneAcccount  = "."
                VBeneHolder    = "."
                VCurrency      = "."
                VSwift         = "."
                VBeneRoute1    = "."
                VBeneRouteType = "."
                VAcctLocation  = ".".
            END.




            run getBankMapCodes(TVendorTOT.TBankCode, VPriorityNumber, output VPAI, output VPiUID).

            vParameters = TRIM(STRING(VSeqno))
                           + "~n" + trim(string(VtotVendPayments,formatCurrency(VCurrency)))
                                                                                     /* CreditAmount*/
                           + "~n" + 'CR'                                             /* CreditInd */
                           + "~n" + VCreditRef                                       /* CreditRef */
                           + "~n" + 'PQ'                                             /* PaymentInd*/
                           + "~n" + VPaymentRef                                      /* PaymentRef */
                           + "~n" + VPiUID                                           /* PiUID - new for CitiBank */
                           + "~n" + VPAI                                             /* PaymentType - existing PAI */
                           + "~n" + 'BF'                                             /* VBeneBank */  /* BF Line */
                           + "~n" + VBeneAcccount
                           + "~n" + VBeneHolder
                           + "~n" + caps(VCurrency)
                           + "~n" + VSwift
                           + "~n" + VBeneRoute1  /* this is the BSB of the Beneficiary account */
                           + "~n" + caps(VBeneRouteType) /* this is the type - works in relation to Vd0_BeneRoute1 */
                           + "~n" + VAcctLocation /* this is the ISO3166 country code */
                           + "~n" + 'BE' /* VBeneficiary */ /* BE Line */
                           + "~n" + vBeneHolder /* Holder JB11 - vBeneHolder */
                           + "~n" + Vaddr1
                           + "~n" + buf1ad_mstr.ad_line2
                           + "~n" + buf1ad_mstr.ad_line3
                           + "~n" + buf1ad_mstr.ad_city
                           + "~n" + SUBSTRING (TRIM(buf1ad_mstr.ad_zip), 1, 8)
                           + "~n" + VBeneLocation 
                           + "~n" + IF vd_mstr.vd__chr09 MATCHES "*@*"  /* JB12 International Email */
                                    THEN vd__chr09 ELSE ""    
                . 
            /* JB14 add remittances for international payments */
            RUN InternationalRemittances(TVendorTOT.tBankCode,
                                         TVendorTOT.tVendor,
                                         TVendorTOT.tCKRef).

            vParameters = vParameters + "~n<EndLoop>" .
    
            VSeqNo = VSeqNo + 1.
        
            run NotifySbl.p (?,                                           
                 vDocType,
                 vTableName,               /* Table Name     */
                 vKeyValue,                /* Key Value      */
                 vaction,                  /* Action         */
                 vParameters,              /* Parameter List */
                 ?,              /* A copy of the Current record */ 
                 OUTPUT vStatus).  
        END.
    END. /* FOR EACH TVendorTOT */


END PROCEDURE.   /* Print2 */

/* JB14 International Remittances */
PROCEDURE InternationalRemittances :
DEFINE INPUT  PARAMETER pBankCode AS CHARACTER   NO-UNDO.
DEFINE INPUT  PARAMETER pVend     AS CHARACTER   NO-UNDO.
DEFINE INPUT  PARAMETER pCkRef    AS CHARACTER   NO-UNDO.

DEF BUFFER tVentorTOT FOR tVendorTOT.
DEFINE VARIABLE vRemarks AS CHARACTER   NO-UNDO.
DEF BUFFER ap_mstr FOR ap_mstr.


FOR EACH tVendorTOT
   WHERE tBankCode EQ pBankCode
     AND tVendor   EQ pVend
     AND tCKref    EQ pCkRef :

    /* Send the last one */
    VSeqNo = VSeqNo + 1.

    run NotifySbl.p (?,                                           
         vDocType,
         vTableName,               /* Table Name     */
         vKeyValue,                /* Key Value      */
         vaction,                  /* Action         */
         vParameters,              /* Parameter List */
         ?,              /* A copy of the Current record */ 
         OUTPUT vStatus).  

    /* set up the Parms for the next one */
    FIND FIRST ap_mstr NO-LOCK
         WHERE ap_domain EQ global_domain
           AND ap_type   EQ "vo"
           AND ap_ref    EQ tVoRef NO-ERROR.
    IF AVAIL(ap_mstr) THEN
        vRemarks = ap_rmk.
    ELSE
        vRemarks = "".

    ASSIGN
        vParameters = TInvoice                 /* RemitInvNo */
             + "~n" + string(TDate,"99/99/99") /* RemitDate  */
             + "~n" + string(abs(TTOTAL * 100), "9999999999999") /* RemitAmount */
             + "~n" + string(abs(TTOTAL * 100), "9999999999999") /* RemitAmtPaid */
             + "~n" + vRemarks.                /* RemitDescr */

END.

END PROCEDURE.    /* InternationalRemittances */


PROCEDURE SETPriorityNumber:


    DEF OUTPUT PARAM VPriorityNumber AS CHAR NO-UNDO.

    IF bk_mstr.bk_curr = "EUR" THEN 
    DO:
        /* if bank is in the Euro region then 2 else 52 */
        IF AVAILABLE (vd0_mstr)                     AND
           CAN-DO(VEuroZone,bk0_mstr.bk0_dacountry) AND
           CAN-DO(VEuroZone,vd0_mstr.vd0_AcctLoc)      
            THEN VPriorityNumber = "2".
        ELSE VPriorityNumber = "52".
    END.
    ELSE IF bk_mstr.bk_curr = "USD" THEN 
    DO:
        IF AVAILABLE (vd0) THEN DO:
            VPriorityNumber =  IF vd0_mstr.vd0_beneRouteType = "A" THEN "CCD"
                                                                   ELSE "52".
        END.
        ELSE VPriorityNumber = "52".
        /* 
        IF vd0_mstr.vd0_AcctLoc = bk0_mstr.bk0_dacountry AND vd0_beneRouteType = "F" THEN
            VPriorityNumber = "52".
         ELSE VPriorityNumber = "CCD". */
    END.
    ELSE IF bk_mstr.bk_curr = "JPY" THEN
         VPriorityNumber = "52".
    ELSE IF bk_mstr.bk_curr = "GBP" THEN
         VPriorityNumber = "52".
    ELSE IF bk_mstr.bk_curr = "CAD" THEN 
    DO:
         IF AVAILABLE (vd0) THEN DO:
             VPriorityNumber = IF vd0_mstr.vd0_AcctLoc = bk0_mstr.bk0_dacountry THEN "CCD" 
                                                                                ELSE "52".
         END.
         ELSE VPriorityNumber = "52".
    END.
    ELSE DO:
        IF AVAILABLE (vd0) THEN DO:
            VPriorityNumber = IF vd0_mstr.vd0_AcctLoc = bk0_mstr.bk0_dacountry THEN "2" 
                                                                               ELSE "52".
        END.
        ELSE VPriorityNumber = "52".
    END.
        

END PROCEDURE.

PROCEDURE Print3:

    DEF INPUT PARAM VCurrentVendor AS CHAR NO-UNDO.
    DEF INPUT PARAM VPriorityNumber AS CHAR NO-UNDO.
    DEF INPUT PARAM VtotVendPayments  AS DEC NO-UNDO. 
    DEF INPUT PARAM VLastPage         AS LOGICAL NO-UNDO.

       FIND vd_mstr WHERE vd_domain = global_domain
                        AND vd_addr   = VCurrentVendor NO-LOCK.
    
        FIND vd0_mstr WHERE vd0_mstr.vd0_Domain = vd_mstr.vd_Domain
                         AND vd0_mstr.vd0_addr   = vd_addr NO-LOCK.
    
    
        FIND FIRST buf1ad_mstr where buf1ad_mstr.ad_domain = global_domain
                                    and buf1ad_mstr.ad_addr = vd_addr NO-LOCK.
    
    
         /* find the translation code for the country code iso 316 */
        VBeneLocation = getISO316(Buf1ad_mstr.ad_ctry).   /* JB02 */
        
        VPaymentRef = "LionNathan" + TVendorTOT.TCkref.
        VCreditref  = TRIM (GLOBAL_DOMAIN) + TVendorTOT.Tckref.

        IF TRIM (buf1ad_mstr.ad_line1) = "" THEN Vaddr1 = ".".  /* MM */
                                            ELSE Vaddr1 =  buf1ad_mstr.ad_line1.

        /* RUN SETPriorityNumber (OUTPUT VPriorityNumber). */

         IF AVAILABLE (vd0_mstr) THEN DO:
                 ASSIGN
                 VBeneAcccount  = Vd0_BeneAcccoun
                 VBeneHolder    = Vd0_BeneHolder
                 VCurrency      = CAPS(Vd0_Currency)       /* JB07 CAPS */
                 VSwift         = Vd0_Swif
                 VBeneRoute1    = Vd0_BeneRoute1
                 VBeneRouteType = CAPS(Vd0_BeneRouteType)  /* JB07 CAPS */
                 VAcctLocation  = getISO316(vd0_mstr.vd0_AcctLoc). 
             END.
             ELSE DO:
                 ASSIGN
                 VBeneAcccount  = "."
                 VBeneHolder    = "."
                 VCurrency      = "."
                 VSwift         = "."
                 VBeneRoute1    = "."
                 VBeneRouteType = "."
                 VAcctLocation  = ".".
             END.


        run getBankMapCodes(TVendorTOT.TBankCode, VPriorityNumber, output VPAI, output VPiUID).
    
        /* Credit Line */
        vParameters = TRIM(STRING(VSeqno))
                       + "~n" + trim(string(VtotVendPayments,formatCurrency(VCurrency)))
                       + "~n" + 'CR'
                       + "~n" + VCreditRef                /* CreditRef */
                       + "~n" + 'PQ'
                       + "~n" + VPaymentRef              /* PaymentRef */
                       + "~n" + VPiUID                   /* UiUID - New for CitiBank */
                       + "~n" + VPAI                     /* PaymentType - existing PAI */
                       + "~n" + 'BF'   /* VBeneBank */   /* BF Line */
                       + "~n" + VBeneAcccount  
                       + "~n" + VBeneHolder 
                       + "~n" + caps(VCurrency)      /* Currency */
                       + "~n" + VSwift        
                       + "~n" + VBeneRoute1     /* this is the BSB of the Beneficiary account */
                       + "~n" + caps(VBeneRouteType) /* this is the type - works in relation to Vd0_BeneRoute1 */
                       + "~n" + VAcctLocation /* this is the ISO3166 country code */
                       + "~n" + 'BE' /* VBeneficiary */ /* BE Line */
                       + "~n" + VBeneHolder    /* JB11 using vBeneHolder */
                       + "~n" + Vaddr1
                       + "~n" + Buf1ad_mstr.ad_line2
                       + "~n" + Buf1ad_mstr.ad_line3
                       + "~n" + Buf1ad_mstr.ad_city
                       + "~n" + SUBSTRING (TRIM(Buf1ad_mstr.ad_zip),1,8)
                       + "~n" + VBeneLocation 
                       + "~n" + IF vd_mstr.vd__chr09 MATCHES "*@*"  /* JB12 International Email */
                                    THEN vd__chr09 ELSE ""    
            . 
    
        /* JB14 add remittances for international payments */
        RUN InternationalRemittances(TVendorTOT.tBankCode,
                                     TVendorTOT.tVendor,
                                     TVendorTOT.tCKRef).

        IF VLastPage THEN
             vParameters = vParameters + "~n<EndLoop>" . 
       
        /***********************************************************
        IF LAST-OF(Bk_mstr.Bk_code) THEN 
            vParameters = vParameters + "~n<EndLoop>" . 
    
       *******************************************************/
    
        VSeqNo = VSeqNo + 1.
    
        run NotifySbl.p (?,                                           
             vDocType,
             vTableName,               /* Table Name     */
             vKeyValue,                /* Key Value      */
             vaction,                  /* Action         */
             vParameters,              /* Parameter List */
             ?,              /* A copy of the Current record */ 
             OUTPUT vStatus).  
    
        VtotVendPayments = 0.


END.  /* PROCEDURE Print3: */

PROCEDURE Print4: /* all other currencies except euros */


    IF VAlreadyPrinted  THEN RETURN.

    VTotalDebits = 0.
    FOR EACH BufTVendorList WHERE BufTVendorList.TBankCode = Bk_mstr.Bk_code
                              AND BufTVendorList.TPriorityNumber <> "52",  /* '2' or 'CCD' */
        EACH TVendorTOT WHERE TVendorTOT.TBankCode = BufTVendorList.TBankCode
                          AND TVendorTOT.TVendor   = BufTVendorList.TVendor:
         VTotalDebits     = VTotalDebits + TVendorTOT.TTOTAL.
    END.


    FIND bk0_mstr WHERE bk0_domain = global_domain
                    AND bk0_code   = Bk_mstr.Bk_code NO-LOCK.

    /* JB01 added global_domain when changed above vControlRef */
    VDebitRef  = TRIM(Bk_mstr.Bk_code) + " " + 
                 TRIM(CAPS(global_domain)) + 
                 VControlRef.

    run getCompanyAddress(global_domain, 
      output vcSort, output vcAddr1, output vcAddr2, 
      output vcAddr3, output vcState, output vcZip, output vcCtry).

    /* find the translation code for the country code iso 316 */
    VBeneLocation = getISO316(vcCtry).                 /* TLF  */            
    VPartyAcctLoc = getISO316(bk0_mstr.bk0_dacountry).  /* JB02 */

    vParameters = TRIM(STRING(VLineNo)) 
           /*  + "~n" + vCenturyDate  */
            + "~n" + VDebitRef
            + "~n" + bk_mstr.Bk_Bk_acct1
            + "~n" + bk_mstr.Bk_Bk_acct2
            + "~n" + trim(string(VTotalDebits,formatCurrency(bk_mstr.Bk_Curr)))  
            + "~n" + bk_mstr.Bk_Curr
            + "~n" + bk0_mstr.bk0_dbswift 
            + "~n" + vcSort 
            + "~n" + vcAddr1
            + "~n" + vcAddr2
            + "~n" + vcAddr3
            + "~n" + vcCity
            + "~n" + vcZip
            + "~n" + VBeneLocation 
            + "~n" + VPartyAcctLoc. 

    run NotifySbl.p (?,
         vDocType,
         vTableName,               /* Table Name     */
         vKeyValue,                /* Key Value      */
         vaction,                  /* Action         */
         vParameters,              /* Parameter List */
         ?,              /* A copy of the Current record */
         OUTPUT vStatus).  


    assign
        VLineNo = VLineNo + 1
        VTotLin = VTotLin + 1
        VSeqNo = 1.

    /* 
    RUN Print3 (INPUT VCurrentVendor,
                INPUT VPriorityNumber,
                INPUT VTotalDebits). */

    VTotalCredits = 0.
    FOR EACH BufTVendorList WHERE BufTVendorList.TBankCode = Bk_mstr.Bk_code
                              AND BufTVendorList.TPriorityNumber <> "52",  /* '2' or 'CCD' */
        EACH TVendorTOT WHERE TVendorTOT.TBankCode = BufTVendorList.TBankCode
                          AND TVendorTOT.TVendor   = BufTVendorList.TVendor
                        BREAK BY TVendorTOT.TVendor:

        IF FIRST-OF(TVendorTOT.TVendor) THEN
            ASSIGN VTotalCredits = 0.

        VTotalCredits    = VTotalCredits + TVendorTOT.TTOTAL.

        IF LAST-OF(TVendorTOT.TVendor) THEN
            RUN Print3 (INPUT TVendorTOT.TVendor,
                        INPUT BufTVendorList.TPriorityNumber,
                        INPUT VTotalCredits,
                        IF LAST(TVendorTOT.TVendor) THEN TRUE ELSE FALSE). 

    END.


 

END PROCEDURE.  /* PROCEDURE Print4:  */


PROCEDURE SENDXML:
    /* JB09 export the staging table */
    RUN ExportStagingTable.

    batchrun = YES. 
    output stream strxml to sendgroup.cim.
    
    /*BA01 - Send the message to Tibco or WebMethods */
    for first stdd_det where stdd_domain = global_domain and
        stdd_code = "WSDocs" and stdd_subcode = vDocType no-lock:
        for each sbt_det where sbt_domain = global_domain and
            sbt_doc_type = vDocType and sbt_error <> 0:
            sbt_error = 0.
        end.
    end.
    if available stdd_det then    
    do:
        export stream strxml entry(1,stdd_txtvalue).
        output stream strxml close.
        OUTPUT to sendgroup.out.
        input from sendgroup.cim.
        {gprun.i ""xxcallws.p""}  
    end.
    else
    do:
        export stream strxml "BankDocs".
        output stream strxml close.
        output to sendgroup.out.
        input from sendgroup.cim.
        {gprun.i ""xxsbl-mon.p""}  
    end.

    PAUSE 0.

    output close.
    input Close.
    batchrun = NO. 
END.

/* JB09 : export the staging table */
PROCEDURE ExportStagingTable :

DEFINE VARIABLE cExportDir        AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cExportNameBegins AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cExportDaysKeep   AS CHARACTER   NO-UNDO.
DEFINE VARIABLE iExportDaysKeep   AS INTEGER     NO-UNDO.
define variable vDocGroup         as character   no-undo.

/* get the directory, filename and number of days to keep */
{gprun.i ""xxstdtabgt.p"" "( ""TRBANK"", ""ExportDir"", OUTPUT cExportDir)"}.
IF cExportDir EQ "" THEN cExportDir = "./".

/* file name begins with this */
{gprun.i ""xxstdtabgt.p"" "( ""TRBANK"", ""ExportNameBegins"", OUTPUT cExportNameBegins)"}.
IF cExportNameBegins EQ "" THEN cExportNameBegins = "ExportTBPay".

/* Days to keep */
{gprun.i ""xxstdtabgt.p"" "( ""TRBANK"", ""ExportDaysKeep"", OUTPUT cExportDaysKeep)"}.

iExportDaysKeep = INT(cExportDaysKeep) NO-ERROR.
IF iExportDaysKeep EQ 0 THEN
    iExportDaysKeep = 2.

/* delete any old files */
DEFINE VARIABLE cBaseName       AS CHARACTER  NO-UNDO.
DEFINE VARIABLE cAbsolutePath   AS CHARACTER  NO-UNDO.
DEFINE VARIABLE cAttributes     AS CHARACTER  NO-UNDO.
DEFINE VARIABLE dDeleteOlder    AS DATE        NO-UNDO.

dDeleteOlder = (TODAY - iExportDaysKeep).

INPUT FROM OS-DIR(cExportDir).
file-loop:
REPEAT:
    IMPORT cBaseName cAbsolutePath cAttributes.
    IF cBaseName = '.' OR cBaseName = '..' THEN NEXT file-loop.

    IF cBaseName BEGINS cExportNameBegins AND
       index(cAttributes,"F") > 0 THEN DO :

        FILE-INFO:FILE-NAME = cAbsolutePath.
        IF FILE-INFO:FILE-MOD-DATE < dDeleteOlder THEN
            OS-DELETE VALUE(FILE-INFO:FULL-PATHNAME).
    END.  /* end begins SortName */
END.  /* file-loop */
/* end Delete old files */

/* dump out the current staging Table */
DEFINE VARIABLE cOutputFile AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cDateYYMMDD AS CHARACTER   NO-UNDO.

ASSIGN
    cDateYYMMDD = SUBSTR(STRING(YEAR(TODAY),"9999"),3) + 
                  STRING(MONTH(TODAY),"99") + 
                  STRING(DAY(TODAY),"99")
    cOutputFile = cExportDir + "/" + 
                  cExportNameBegins + "-" + 
                  caps(global_domain) + "-" +
                  cDateYYMMDD + ".d".

/* make sure there is not already a file with that name,
   if there is, we add -new to the name, and then -new-new  */
DO WHILE SEARCH(cOutputFile) NE ? :
    cOutputFile = REPLACE(cOutputFile,".d","-new.d").
END.
                  
OUTPUT TO value(cOutputFile).
    /*BA01 - Bakcup correct Document Group */
    vDocGroup = "BankDocs".
    for first stdd_det where stdd_domain = global_domain and
        stdd_code = "WSDocs" and stdd_subcode = vDocType no-lock:
        vDocGroup = entry(1,stdd_txtvalue) no-error.
        if error-status:error then
            vDocGroup = "BankDocs".
    end.

FOR EACH sbt_det NO-LOCK
   WHERE sbt_domain EQ global_domain
     /*
     AND sbt_doc_group EQ vDocGroup /*"bankdocs" BA01*/ 
     */
     and sbt_doc_type = vDocType

    /* JB15 sort in the output file, same as the XML is built */
    use-index sbt_doc_key
              by sbt_domain by sbt_doc_type by sbt_key_value by sbt_seq: 

     
    EXPORT sbt_det.
END.
OUTPUT CLOSE.


END PROCEDURE.  /* ExportStagingTable */

PROCEDURE getBankMapCodes:

  def input param ip_bank_id            as char no-undo.
  def input param ip_default_pai_code   as char no-undo.
  def output param op_pai_code          as char no-undo.
  def output param op_piuid_code        as char no-undo.

  op_pai_code = ip_default_pai_code. /* This value must be specifically overridden */
  
  find first stdd_det no-lock
     where stdd_domain = global_domain
       and stdd_code = "TRBANK"
       and stdd_subcode = "VBankMap_" + ip_bank_id no-error.
  if not available stdd_det then
    find first stdd_det no-lock
       where stdd_domain = global_domain
         and stdd_code = "TRBANK"
         and stdd_subcode = "VBankMap_*" no-error.
  if available stdd_det then
  do:
    if num-entries(stdd_txtvalue) > 0 then
      op_pai_code = entry(1, stdd_txtvalue).
    if num-entries(stdd_txtvalue) > 1 then
      op_piuid_code = entry(2, stdd_txtvalue).
  end. 

END PROCEDURE.

PROCEDURE getCompanyAddress:
  def input param ip_domain   as char no-undo.
  
  def output param op_sort    as char no-undo.
  def output param op_addr1   as char no-undo.
  def output param op_addr2   as char no-undo.
  def output param op_addr3   as char no-undo.
  def output param op_city    as char no-undo.
  def output param op_zip     as char no-undo.
  def output param op_ctry    as char no-undo.
  
  def var vl_addr             as char no-undo.
  
  vl_addr = if ip_domain = "LNAU" then "LNA" else ip_domain.
  
  find first ad_mstr no-lock
    where ad_domain = ip_domain  
      and ad_addr   = vl_addr no-error.
  if available ad_mstr then
    assign
      op_sort  = ad_sort
      op_addr1 = (if ad_line1 = "" then "." else ad_line1)
      op_addr2 = ad_line2
      op_addr3 = ad_line3
      op_city  = ad_city
      op_zip   = substring(trim(ad_zip),1,8)
      op_ctry  = ad_ctry
      .
  else
    assign
      op_sort  = ""
      op_addr1 = "Company address missing for domain: " + ip_domain + " Address: " + vl_addr
      op_addr2 = ""
      op_addr3 = ""
      op_city  = ""
      op_zip   = ""
      op_ctry  = ""
      .

END PROCEDURE.

