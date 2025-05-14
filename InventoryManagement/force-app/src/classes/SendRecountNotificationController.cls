public class SendRecountNotificationController {
 	//Apex properties or variables

    public Id Id { get; set; }
    public Cycle_Count_Date__c ccd { get; set; }
    public String ccAddresses { get; set; }

    //constructor to get the Case record
   //  public SendRecountNotificationController(ApexPages.StandardController controller) {
   //  ccd =  (Cycle_Count_Date__c) controller.getRecord();
   //  Id = ccd.Id;
   //  System.debug('The ccd record: ' + ccd);
   //  }

    public SendRecountNotificationController() {

      ccd = [Select Id From Cycle_Count_Date__c Where Id = :ApexPages.currentPage().getParameters().get('id')];

    }

    //Method that can is called from the Visual Force page action attribute
    public PageReference sendNotification() {
       System.debug('CCD id = '+ccd.Id);
       System.debug('CC address = '+ccAddresses);
       String[] ccemailAddresses = new String[]{};

       if(ccAddresses != null && ccAddresses != '') {
         for(String cc : ccAddresses.split(',')){
            System.debug('cc = '+cc);
            String strippedMail = cc.replace(' ', '');
            strippedMail = strippedMail.replace('(', '');
            strippedMail = strippedMail.replace(')', '');
            System.debug('strippedMail = '+strippedMail);
            if(strippedMail != null && strippedMail != ''){
               ccemailAddresses.add(strippedMail);
            }
         }
       }
       
       System.debug('ccAddrss size'+ccemailAddresses.size());
       CycleCountController.sentRecountNotification(ccd.Id, ccemailAddresses);
       PageReference pg = new PageReference('/'+ccd.Id);
       pg.setRedirect(true);
       return pg;  
    }
}