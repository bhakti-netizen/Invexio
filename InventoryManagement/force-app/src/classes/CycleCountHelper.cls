/**
* @File Name : CycleCountHelper.cls
* @Description :
* @Author : Ria Mittal
* @Last Modified By : Ria Mittal
* @Last Modified On : February 17, 2025
* @Modification Log :
* Latest Code Coverage from CycleCountHelperTest = 93%
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 17, 2025 |   | Initial Version
**/

public class CycleCountHelper {
	
	public static void createBulkCycleCountVersionRecords(List<Cycle_Count_Date__c> newList){

		List<Cycle_Count_Version__c> cycle_count_versions = new List<Cycle_Count_Version__c>();
		for(Cycle_Count_Date__c ccd : newList){

			List<String> locations = ccd.Locations__c.split(';');
            List<String> technicians = ccd.Technicians__c.split(';');
			List<String> products = ccd.Products__c.split(';');
            Map<String, String> locationMap = new Map<String, String>();
            Map<String, String> productMap = new Map<String, String>();
            
            for(Product2 p : [Select Id, Name From Product2 Where Id In :products]){
                productMap.put(p.Id, P.Name);
            }
            for(ServiceResource sr : [Select Id, Name, LocationId From ServiceResource Where IsActive = true And Id In :technicians]){
                locations.add(sr.LocationId);
            }
            for(Schema.Location loc : [Select Id, Name From Location Where Id In :locations]){
                locationMap.put(loc.Id, loc.Name);
            }


            
			for(String loc : locations){
				for(String prod : products){
                    String name = locationMap.get(loc) + ' - ' + productMap.get(prod);
                    if(name.length() > 79) { 
                        name = name.substring(0,79);
                    }
					Cycle_Count_Version__c ccv = new Cycle_Count_Version__c();
					ccv.Cycle_Count_Date__c = ccd.Id;
					ccv.Location__c = loc;
					ccv.Product__c = prod;
					ccv.Active__c = true;
                    // ccv.Name = name;
					cycle_count_versions.add(ccv);
				}
			}
		}
		if(cycle_count_versions.size() > 0){
			insert cycle_count_versions;
		}
	}
    
    public static void createBulkCycleCountRecords(List<Cycle_Count_Version__c> newList){ 
    	System.debug('@@cycle count creation ');
        Map<String, ProductItem> mapOfLocationAndProducts = new Map<String, ProductItem>();
        Map<String, Boolean> mapOfSerializedPIOrNot = new Map<String, Boolean>();
        for(ProductItem pi : [Select Id, LocationId, Product2Id, IsProduct2Serialized, QuantityOnHand, (Select Id, Total_Quantity__c From SerializedProducts) From ProductItem]){
            mapOfLocationAndProducts.put(pi.LocationId + '##' + pi.Product2Id, pi);
            mapOfSerializedPIOrNot.put(pi.Id, pi.IsProduct2Serialized);
        }
        
        List<Cycle_Count__c> cycleCountList = new List<Cycle_Count__c>();
        List<ProductItem> piToInsert = new List<ProductItem>();
        Map<String, Cycle_Count_Version__c> mapOfCCV = new Map<String, Cycle_Count_Version__c>();
        for(Cycle_Count_Version__c ccv : newList){
            if(ccv.Location__c != null && ccv.Product__c != null) {
                String key = ccv.Location__c + '##' + ccv.Product__c;
                mapOfCCV.put(key, ccv);
                if(mapOfLocationAndProducts.containsKey(key)) {
                    if(mapOfSerializedPIOrNot.get(mapOfLocationAndProducts.get(key).Id) == true) {
                        for(SerializedProduct sp : mapOfLocationAndProducts.get(key).SerializedProducts){
                            Cycle_Count__c cc = new Cycle_Count__c();
                            cc.Product_Item__c = mapOfLocationAndProducts.get(key).Id;
                            cc.Cycle_Count_Version__c = ccv.Id;
                            cc.Active_Count__c = true;
                            cc.Serialized_Product__c = sp.Id;
                            cc.Total_Listed_Quantity__c = sp.Total_Quantity__c;
                            cycleCountList.add(cc);
                        }
                    }
                    else {
                        Cycle_Count__c cc = new Cycle_Count__c();
                        cc.Product_Item__c = mapOfLocationAndProducts.get(key).Id;
                        cc.Cycle_Count_Version__c = ccv.Id;
                        cc.Active_Count__c = true;
                        cc.Total_Listed_Quantity__c = mapOfLocationAndProducts.get(key).QuantityOnHand;
                        cycleCountList.add(cc);
                    }
                }
                else {
                    ProductItem pi = new ProductItem();
                    pi.LocationId = ccv.Location__c;
                    pi.Product2Id = ccv.Product__c;
                    pi.QuantityOnHand = 0;
                    piToInsert.add(pi);
                    
                }
            }
            
        }
        if(piToInsert.size() > 0){
            insert piToInsert;
            for(ProductItem pi : piToInsert) {
                
                if(mapOfCCV.containsKey(pi.LocationId + '##' + pi.Product2Id)) {
                    Cycle_Count__c cc = new Cycle_Count__c();
                    cc.Product_Item__c = pi.Id;
                    cc.Cycle_Count_Version__c = mapOfCCV.get(pi.LocationId + '##' + pi.Product2Id).Id;
                    cc.Active_Count__c = true;
                    cc.Total_Listed_Quantity__c = 0;
                    cycleCountList.add(cc);
                }
            }
        }
        if(cycleCountList.size() > 0){
            System.debug('@@inserting cycle counts');
            insert cycleCountList;
        }
    } 
    
    public static void updateRelatedCCV(List<Cycle_Count__c> newList, Map<Id,Cycle_Count__c> oldMap ) {
        List<Cycle_Count_Version__c> versionsToUpdate = new List<Cycle_Count_Version__c>();
        for(Cycle_Count__c cc : newList) { 
            if(cc.Total_Listed_Quantity__c == cc.Actual_Quantity__c){
                Cycle_Count_Version__c ccv = new Cycle_Count_Version__c();
                ccv.Id = cc.Cycle_Count_Version__c;
                ccv.Completed__c = True;
                versionsToUpdate.add(ccv);
                
            }
            else if(cc.Recount_Needed__c == true && oldMap.get(cc.Id).Recount_Needed__c == false){
                Cycle_Count_Version__c ccv = new Cycle_Count_Version__c();
                ccv.Id = cc.Cycle_Count_Version__c;
                ccv.Completed__c = false;
                versionsToUpdate.add(ccv);
            }
        }
        if(versionsToUpdate.size() > 0) {
            update versionsToUpdate;
        }
    }

    public static void afterApprovalAutomations(List<Cycle_Count__c> newList, Map<Id,Cycle_Count__c> oldMap) {

        Set<Id> ccIds = new Set<Id>();
        Set<Id> spIds = new Set<Id>();
       
        for(Cycle_Count__c cc : newList){
            if(cc.Approved__c != oldMap.get(cc.Id).Approved__c) { 
                ccIds.add(cc.Id);
                if(cc.Serialized_Product__c != null && cc.Completed__c == True && 
                    (cc.Technician_Inventory_Person__c == NULL || cc.Technician_Inventory_Person__c == '')) {
                    spIds.add(cc.Serialized_Product__c);
                }

            }
        }

        //Mark un-scanned items as LOST
        List<SerializedProduct> spList = new List<SerializedProduct>();
        for(SerializedProduct sp : [Select ID, Status  From SerializedProduct Where Id In :spIds]) {
            sp.Status = 'Lost';
            spList.add(sp);
        }
        if(spList.size() > 0){
            update spList;
        }

    }

    public static void beforeUpdateAutomations(List<Cycle_Count__c> newList, Map<Id,Cycle_Count__c> oldMap) {
        
        Set<Id> variedSPs = new Set<Id>();
        Map<Id, Cycle_Count__c> spVsCompletionTime = new Map<Id, Cycle_Count__c>();
        for(Cycle_Count__c cc : newList){

            if(cc.Total_Listed_Quantity__c == cc.Actual_Quantity__c) {
                 cc.Approved__c = true;
            }
            if(cc.Approved__c != oldMap.get(cc.Id).Approved__c) { 
            
                //Check for transactions in between approval and completion
                // if(cc.Serialized_Product__c != null && cc.Variance__c > 0 && cc.Completion_DateTime__c < System.now()){
                //     variedSPs.add(cc.Serialized_Product__c);
                //     spVsCompletionTime.put(cc.Serialized_Product__c, cc);
                // }
            }
        }

        List<Cycle_Count__c> ccToUpdate = new List<Cycle_Count__c>();
        Set<Id> transferedSP = new Set<Id>();
        //Check for transactions in between approval and completion
        System.debug('@@variedSPs' + variedSPs);
        // List<ProductTransfer> pt = [Select Id,Serialized_Product_Id__c from ProductTransfer Where Serialized_Product_Id__c In :spVsCompletionTime.keySet()];
        // for(ProductTransfer p : pt) {
        //     if(p.CreatedDate > spVsCompletionTime.get(p.Serialized_Product_Id__c).Completion_DateTime__c) { 
        //         transferedSP.add(p.Serialized_Product_Id__c);
        //     }
        // }

        // for(SerializedProduct sp : [Select Id, Overall_Quantity__c From SerializedProduct Where Id in :transferedSP]) {
            // Cycle_Count__c cc = spVsCompletionTime.get(sp.Id);
            // cc.Actual_Quantity__c = sp.Overall_Quantity__c;
            // ccToUpdate.add(cc);
        // }

        // if(ccToUpdate.size() > 0){
        //     update ccToUpdate;
        // }

    }
}