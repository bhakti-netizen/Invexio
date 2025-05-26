/**
* @File Name : CycleCountController.cls
* @Description :
* @Author : Ria Mittal
* @Last Modified By : Ria Mittal
* @Last Modified On : March 3, 2025
* @Modification Log :
* Latest Code Coverage from CycleCountControllerTest = 79%
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 17, 2025 |   | Initial Version
**/

public class CycleCountController {

    //Cycle count scanning logic
    @AuraEnabled
    public static String combinedCycleCount(List<String> barcodes, String locationId){
        
        System.debug('@@barcodes = '+barcodes);
        List<String> barcodesSeparated = new List<String>();
        Map<String, String> actualBarcodeMapping = new Map<String, String>();
        //Separating barcodes from quantities
        for(String s : barcodes){
            barcodesSeparated.add(s.split('#\\$#')[0]);
            // actualBarcodeMapping.put(s.split('#\\$#')[0], s);
            actualBarcodeMapping.put(s.split('#\\$#')[0]+ '##' + locationId.substring(0,15), s);
        }
        System.debug('@@barcodesSeparated = '+barcodesSeparated);

        String msg = '',msg1 = '', msg2 = '';
        // Id locationId1, locationId2;
        //SerialNumber vs Serialized Product
        Map<String, SerializedProduct> serProdMap = new Map<String, SerializedProduct>();
        for(SerializedProduct sp : [Select Id, SerialNumber, Product2Id, ProductItemId, Product_Name__c, ProductItem.LocationId From SerializedProduct]){
            serProdMap.put(sp.SerialNumber, sp);
            
        }

        // Map to store ProductItem records based on barcode
        Map<String, ProductItem> productItemMap = new Map<String, ProductItem>();
        for(ProductItem nsp : [SELECT Id, SerialNumber, Product2Id,ProductItemNumber, ProductName, LocationId, Name__c FROM ProductItem WHERE IsProduct2Serialized = false]){
            // productItemMap.put(nsp.ProductItemNumber, nsp); //Commented to use Product SKU in cycle counting for Non serialized products
            productItemMap.put(nsp.Name__c + '##' + (String.valueOf(nsp.LocationId).substring(0,15)) , nsp);
            
        }


        Set<String> barcodesForSP  = new Set<String>();
        List<String> barcodesForNSP = new List<String>();

        for(String s : barcodesSeparated){
            if(serProdMap.containsKey(s)){
                barcodesForSP.add(s);
                // locationId1 = serProdMap.get(s).ProductItem.LocationId;
            }
            else if(productItemMap.containsKey(s+ '##' +locationId.substring(0,15))){
                barcodesForNSP.add(s);
                // locationId2 = productItemMap.get(s).LocationId;
            }
        }

        System.debug('@@barcodesForSP = '+barcodesForSP);
        System.debug('@@serProdMap = '+serProdMap);
        // System.debug('@@locationId1 = '+locationId1);
        System.debug('@@actualBarcodeMapping = '+actualBarcodeMapping);

        System.debug('@@barcodesForNSP = '+barcodesForNSP);
        System.debug('@@productItemMap = '+productItemMap);
        // System.debug('@@locationId2 = '+locationId2);
        System.debug('@@actualBarcodeMapping = '+actualBarcodeMapping);
        
        if(barcodesForSP.size() > 0){
            msg1 = updateCycleCountsForSP(barcodesForSP, serProdMap, locationId, actualBarcodeMapping);
        }
        if(barcodesForNSP.size() > 0){
            msg2 = updateCycleCountsForNSP(barcodesForNSP, productItemMap, locationId, actualBarcodeMapping);
        }
        msg = msg1 + ' ' + msg2;
        return msg;
    }

    public static String updateCycleCountsForSP(Set<String> barcodes, Map<String, SerializedProduct> serProdMap, Id locationId1, Map<String, String> actualBarcodeMapping) {
        System.debug('@@@barcodes = '+barcodes);
        System.debug('@@@serProdMap = '+serProdMap);
        System.debug('@@@locationId1 = '+locationId1);
        System.debug('@@@actualBarcodeMapping = '+actualBarcodeMapping);
        String locationId = String.valueOf(locationId1).substring(0,15);

        Set<Id> ccdIds = new Set<Id>();
        Set<Id> ccvIds = new Set<Id>();
        for(Cycle_Count_Date__c ccd : [Select Id, (Select Id From Cycle_Count_Versions__r Where Completed__c = False) From Cycle_Count_Date__c Where Active__c = True]) {
            ccdIds.add(ccd.Id);
            for(Cycle_Count_Version__c ccv : ccd.Cycle_Count_Versions__r) {
                ccvIds.add(ccv.Id);
            }
        }
        System.debug('@@@ccdIds = '+ccdIds);
        System.debug('@@@ccvIds = '+ccvIds);
        
        Set<Id> spIds = new Set<Id>();
        for(SerializedProduct sp : serProdMap.values()) {
            spIds.add(sp.Id);
        }
        System.debug('@@@spIds = '+spIds);
        Map<String, Cycle_Count__c> mapSerialNumberVsCC = new Map<String, Cycle_Count__c>();
        for(Cycle_Count__c cc : [Select ID, Serialized_Product__r.SerialNumber, Actual_Quantity__c From Cycle_Count__c Where Serialized_Product__c In :spIds And Product_Item__r.LocationId = :locationId1 AND Cycle_Count_Version__c in :ccvIds]) {
            mapSerialNumberVsCC.put(cc.Serialized_Product__r.SerialNumber, cc);
        }

        List<Cycle_Count__c> ccListToUpdate = new List<Cycle_Count__c>();
        for(String code : barcodes) {
            if(serProdMap.containsKey(code) && mapSerialNumberVsCC.containsKey(code)) {
                System.debug('@@actualBarcodeMapping');
                Integer actualQuantity = Integer.valueOf(actualBarcodeMapping.get(code+ '##' +locationId).split('#\\$#')[2]);
                Cycle_Count__c cc = mapSerialNumberVsCC.get(code);
                if(cc.Actual_Quantity__c == null){
                    cc.Actual_Quantity__c = actualQuantity;
                }
                else{
                    cc.Actual_Quantity__c = cc.Actual_Quantity__c  + actualQuantity;
                }
                cc.Technician_Inventory_Person__c = UserInfo.getUserId();
                ccListToUpdate.add(cc);
            }
            else {
                return 'Error: End Date for this Cycle Count has already passed, or you have already marked this Completed';
            }
        }
        if(ccListToUpdate.size() > 0){
            System.debug('@@ccListToUpdate' +ccListToUpdate);
            update ccListToUpdate;
            return 'Updated cycle count records correctly.';
        }

        return 'true';

    }

    public static String updateCycleCountsForNSP(List<String> barcodes, Map<String, ProductItem> productItemMap, Id locationId2, Map<String, String> actualBarcodeMapping) {
        System.debug('@@@barcodes = '+barcodes);
        System.debug('@@@productItemMap = '+productItemMap);
        System.debug('@@@locationId2 = '+locationId2);
        System.debug('@@@actualBarcodeMapping = '+actualBarcodeMapping);
        String locationId = String.valueOf(locationId2).substring(0,15);

        Set<Id> ccdIds = new Set<Id>();
        Set<Id> ccvIds = new Set<Id>();
        for(Cycle_Count_Date__c ccd : [Select Id, (Select Id From Cycle_Count_Versions__r Where Completed__c = False) From Cycle_Count_Date__c Where Active__c = True]) {
            ccdIds.add(ccd.Id);
            for(Cycle_Count_Version__c ccv : ccd.Cycle_Count_Versions__r) {
                ccvIds.add(ccv.Id);
            }
        }
        System.debug('@@@ccdIds = '+ccdIds);
        System.debug('@@@ccvIds = '+ccvIds);
        
        Set<Id> piIds = new Set<Id>();
        for(ProductItem sp : productItemMap.values()) {
            piIds.add(sp.Id);
        }
        System.debug('@@@spIds = '+piIds);
        List<Cycle_Count__c> ccListToUpdate = new List<Cycle_Count__c>();
        Map<String, Cycle_Count__c> piCodeVsCCMap = new Map<String, Cycle_Count__c>();
        
        for(Cycle_Count__c cc : [Select Id, Product_Item__r.Name__c, Product_Item__r.LocationId, Actual_Quantity__c From Cycle_Count__c Where Product_Item__c In :piIds And Product_Item__r.LocationId = :locationId2  AND Cycle_Count_Version__c in :ccvIds]) { 
            piCodeVsCCMap.put(cc.Product_Item__r.Name__c + '##' +(String.valueOf(cc.Product_Item__r.LocationId).substring(0,15)) ,cc);
        }
        System.debug('@@@piCodeVsCCMap = '+piCodeVsCCMap);
        for(String code : barcodes) {
            
            if(piCodeVsCCMap.containsKey(code + '##' + locationId) && productItemMap.containsKey(code + '##' + locationId)) {
                Cycle_Count__c cc = piCodeVsCCMap.get(code + '##' + locationId);
                Integer actualQuantity = Integer.valueOf(actualBarcodeMapping.get(code+ '##' +locationId).split('#\\$#')[2]);
                if(cc.Actual_Quantity__c == null){
                    cc.Actual_Quantity__c = actualQuantity;
                }
                else{
                    cc.Actual_Quantity__c = cc.Actual_Quantity__c  + actualQuantity;
                }
                cc.Technician_Inventory_Person__c = UserInfo.getUserId();
                ccListToUpdate.add(cc);
            }
            else {
                return 'Error: End Date for this Cycle Count has already passed, or you have already marked this Completed';
            }
        }

        if(ccListToUpdate.size() > 0){
            update ccListToUpdate;
            return 'Updated cycle count records correctly.';
        }

        return 'true';

    }

    @AuraEnabled
    public static Decimal fetchTotalQuantityForScannedProduct(String code){

        List<SerializedProduct> spList = [Select Id,Total_Quantity__c From SerializedProduct Where SerialNumber = :code];
        if(spList.size() > 0){
            return spList[0].Total_Quantity__c;
        }
        else{
            List<ProductItem> piList = [Select Id,QuantityOnHand, Name__c From ProductItem Where Name__c =: code];
            if(piList.size() > 0){
                return piList[0].QuantityOnHand;
            }
            else{
                return 0;
            }
        }
    }

    @AuraEnabled
    public static ProductWrapper fetchProductNameForScannedProduct(String code, String locationId){

        List<SerializedProduct> spList = [Select Id,Product_Name__c,  Total_Quantity__c, Product2.QuantityUnitOfMeasure From SerializedProduct Where SerialNumber = :code];
        if(spList.size() > 0){
            ProductWrapper wrapper = new ProductWrapper();
            wrapper.ProductName = spList[0].Product_Name__c;
            // wrapper.ProductSKU = spList[0].EnergyAid_Product_SKU__c;
            wrapper.TotalQuantity = spList[0].Total_Quantity__c;
            wrapper.QOM = spList[0].Product2.QuantityUnitOfMeasure;
            return wrapper;
            // return spList[0].Product_Name__c + '##' + spList[0].EnergyAid_Product_SKU__c;
        }
        else{
            // List<ProductItem> piList = [Select Id,Product2.Name,  QuantityOnHand From ProductItem Where ProductItemNumber =: code];
            List<ProductItem> piList = [Select Id,Product2.Name,  QuantityOnHand, Name__c, QuantityUnitOfMeasure From ProductItem Where Name__c =: code];
            if(piList.size() > 0){
                ProductWrapper wrapper = new ProductWrapper();
                wrapper.ProductName = piList[0].Product2.Name;
                // wrapper.ProductSKU = piList[0].EnergyAid_Product_SKU__c;
                wrapper.TotalQuantity = piList[0].QuantityOnHand;
                wrapper.QOM = piList[0].QuantityUnitOfMeasure;
                return wrapper;
                // return piList[0].Product2.Name + '##' + piList[0].EnergyAid_Product_SKU__c;
            }
            else{
                return new ProductWrapper();
            }
        }
    }
     @AuraEnabled
    public static Decimal fetchActualQuantityForScannedProduct(String code, String locationId){

        System.debug('Code = '+code);
        
        List<Cycle_Count__c> ccList = [Select Id,Actual_Quantity__c,Product_Item__c From Cycle_Count__c 
        where 
        (Product_Item__r.Name__c = :code OR Serialized_Product__r.SerialNumber = :code)
        AND Product_Item__r.LocationId =: locationId ORDER by LastModifiedDate DESC];
        System.debug('##ccList = '+ccList);
        if(ccList.size() > 0){
            return ccList[0].Actual_Quantity__c;
        }
        else{
            return 0;
        }
        
    }

    @AuraEnabled
    public static String fetchLocation(String locationId){
        try{
            String locationName = [Select Id, Name From Location Where Id = :locationId LIMIT 1].Name;
            if(locationName != null){
                return locationName;
            }
            return 'false';
        }
        catch(Exception e){
            return 'false';
        }

    }


    public class ProductWrapper{
        @AuraEnabled
        public String ProductName;
        @AuraEnabled
        public String ProductSKU;
        @AuraEnabled
        public Decimal TotalQuantity;
        @AuraEnabled
        public String QOM;
        @AuraEnabled 
        public String Family;
        @AuraEnabled 
        public String ProductType;
        @AuraEnabled 
        public String ProductTypeSub;
        @AuraEnabled
        public String ID;
    }




    //Pull Material Logic
    @AuraEnabled
    public static String combinedPullMaterials(List<String> barcodes, String locationId, Boolean showWarning, String technicianId){
        
        // if(showWarning == false){
            System.debug('@@barcodes = '+barcodes);
            List<String> barcodesSeparated = new List<String>();
            Map<String, String> actualBarcodeMapping = new Map<String, String>();
            //Separating barcodes from quantities
            for(String s : barcodes){
                barcodesSeparated.add(s.split('#\\$#')[0]);
                // actualBarcodeMapping.put(s.split('#\\$#')[0], s);
                actualBarcodeMapping.put(s.split('#\\$#')[0]+ '##' + locationId, s);
            }
            System.debug('@@barcodesSeparated = '+barcodesSeparated);

            String msg = '',msg1 = '', msg2 = '';
            // Id locationId1, locationId2;
            //SerialNumber vs Serialized Product
            Map<String, SerializedProduct> serProdMap = new Map<String, SerializedProduct>();
            for(SerializedProduct sp : [Select Id, SerialNumber, Product2Id, ProductItemId, Product_Name__c, ProductItem.LocationId, Product_Request__c From SerializedProduct]){
                serProdMap.put(sp.SerialNumber, sp);
                
            }

            // Map to store ProductItem records based on barcode
            Map<String, ProductItem> productItemMap = new Map<String, ProductItem>();
            for(ProductItem nsp : [SELECT Id, SerialNumber, Product2Id,ProductItemNumber, ProductName, LocationId,  Name__c FROM ProductItem WHERE IsProduct2Serialized = false]){
                // productItemMap.put(nsp.ProductItemNumber, nsp); //Commented to use Product SKU in cycle counting for Non serialized products
                productItemMap.put(nsp.Name__c+'##'+nsp.LocationId , nsp);
                
            }

            ServiceResource sr;
            if(technicianId != null){
                sr = [Select Id, Name, LocationId From ServiceResource Where Id = :technicianId LIMIT 1];
            }

            Set<String> barcodesForSP  = new Set<String>();
            List<String> barcodesForNSP = new List<String>();

            for(String s : barcodesSeparated){
                if(serProdMap.containsKey(s)){
                    barcodesForSP.add(s);
                    // locationId1 = serProdMap.get(s).ProductItem.LocationId;
                }
                else if(productItemMap.containsKey(s+'##'+sr.LocationId)){
                    barcodesForNSP.add(s);
                    // locationId2 = productItemMap.get(s).LocationId;
                }
            }

            System.debug('@@barcodesForSP = '+barcodesForSP);
            System.debug('@@serProdMap = '+serProdMap);
            // System.debug('@@locationId1 = '+locationId1);
            System.debug('@@actualBarcodeMapping = '+actualBarcodeMapping);

            System.debug('@@barcodesForNSP = '+barcodesForNSP);
            System.debug('@@productItemMap = '+productItemMap);
            // System.debug('@@locationId2 = '+locationId2);
            System.debug('@@actualBarcodeMapping = '+actualBarcodeMapping);
            String templocation = (String)locationId;
            locationId = Id.valueOf(templocation.substring(0,15));
            
            
            if(barcodesForSP.size() > 0){
                msg1 = pullMaterialsForSP(barcodesForSP, serProdMap, locationId, actualBarcodeMapping);
            }
            if(barcodesForNSP.size() > 0){
                msg2 = pullMaterialsForNSP(barcodesForNSP, productItemMap, locationId, actualBarcodeMapping, sr);
            }
            msg = msg1 + ' ' + msg2;
            return msg;
        // }
        // return 'Warning!';
        
    }

    public static string pullMaterialsForSP(Set<String> barcodes, Map<String, SerializedProduct> serProdMap, Id locationId1, Map<String, String> actualBarcodeMapping){
        
        System.debug('@@barcodes = '+barcodes);
        System.debug('@@serProdMap = '+serProdMap);

        try{
            List<ProductTransfer> transfers = new List<ProductTransfer>();
            Map<String, String> mapOfRequestVsLineItem = new Map<String, String>();
            Set<String> setOfRequests = new Set<String>();
            Set<Id> spIds = new Set<Id>();
            for(SerializedProduct sp : serProdMap.values()){
                if(sp.Product_Request__c != null){
                    setOfRequests.add(sp.Product_Request__c);
                    spIds.add(sp.Id);
                }
            }

            //Create data structure to maintain existing transfers to show warning if there are similar transfers
            Map<Id, List<ProductTransfer>> mapOfSPvsTransfers = new Map<Id, List<ProductTransfer>>(); 
            for(ProductTransfer pt : [Select Id, Serialized_Product_Id__c, SourceLocationId, DestinationLocationId, QuantitySent From ProductTransfer Where Serialized_Product_Id__c In :spIds]){
                if(mapOfSPvsTransfers.containsKey(pt.Serialized_Product_Id__c)){
                    List<ProductTransfer> tempTransfers = mapOfSPvsTransfers.get(pt.Serialized_Product_Id__c);
                    tempTransfers.add(pt);
                    mapOfSPvsTransfers.put(pt.Serialized_Product_Id__c, tempTransfers);
                }
                else{
                    mapOfSPvsTransfers.put(pt.Serialized_Product_Id__c, new List<ProductTransfer>{pt});
                }
            }
            for(ProductRequestLineItem prli : [Select Id, ParentId, Product_Name__c from ProductRequestLineItem Where ParentId in :setOfRequests]){
                mapOfRequestVsLineItem.put(prli.ParentId + '###' + prli.Product_Name__c, prli.Id);
            }

            for(String barcode : barcodes){
                

                if(serProdMap.containsKey(barcode)){

                    ProductTransfer pt = new ProductTransfer();
                    pt.Product2Id = serProdMap.get(barcode).Product2Id;
                    pt.SourceLocationId = serProdMap.get(barcode).ProductItem.LocationId;
                    pt.DestinationLocationId = locationId1;
                    pt.QuantitySent = 1;
                    if(serProdMap.get(barcode).Product_Request__c != null){
                        if(mapOfRequestVsLineItem.containsKey(serProdMap.get(barcode).Product_Request__c + '###' + serProdMap.get(barcode).Product_Name__c)){
                            pt.ProductRequestLineItemId = mapOfRequestVsLineItem.get(serProdMap.get(barcode).Product_Request__c + '###' + serProdMap.get(barcode).Product_Name__c);
                        }
                    }
                    pt.Serialized_Product_Id__c  = serProdMap.get(barcode).Id;
                    transfers.add(pt);
                }
            }
            if(transfers.size() > 0){
                insert transfers;
            }

            //Create Product Transfer states for sending
            List<ProductTransferState> transferStates = new List<ProductTransferState>();
            List<ProductTransfer> updatedTransfers = new List<ProductTransfer>();
            for(ProductTransfer pt : transfers){
                ProductTransferState pts = new ProductTransferState();
                pts.SerializedProductId = pt.Serialized_Product_Id__c;
                pts.TransferState = 'Sent';
                pts.Action = 'Send';
                pts.ProductTransferId = pt.Id;
                transferStates.add(pts);
                pt.IsSent = True;
                updatedTransfers.add(pt);
            }
            if(transferStates.size() > 0){
                insert transferStates;
            }

            //Update Transfers to be sent
            update updatedTransfers;

            //Create Product Transfer states for receiving 
            List<ProductTransferState> transferStatesReceive = new List<ProductTransferState>();
            List<ProductTransfer> updatedTransfersReceive = new List<ProductTransfer>();
            for(ProductTransfer pt : transfers){
                ProductTransferState pts = new ProductTransferState();
                pts.SerializedProductId = pt.Serialized_Product_Id__c;
                pts.TransferState = 'Available';
                pts.Action = 'Receive';
                pts.ProductTransferId = pt.Id;
                transferStatesReceive.add(pts);

                pt.IsReceived = True;
                pt.QuantityReceived = pt.QuantitySent;
                updatedTransfersReceive.add(pt);
            }
            if(transferStatesReceive.size() > 0){
                insert transferStatesReceive;
            }

            //update received transfers
            update updatedTransfersReceive;

            return 'Transfers created successfully for Serialized Products.';
        }
        catch(Exception e){
            return e.getMessage();
        }
    }
    
    //change logic for productItem here after QR change
    public static string pullMaterialsForNSP(List<String> barcodes, Map<String, ProductItem> productItemMap, Id locationId2, Map<String, String> actualBarcodeMapping, ServiceResource resource) {
        
        try{
            String templocation = (String)locationId2;
            String templocation1 = templocation.substring(0,15);
            locationId2 = Id.valueOf(templocation1);
            // List<Product2> productList = [Select Id, EnergyAid_Product_SKU__c From Product2 Where EnergyAid_Product_SKU__c In :barcodes];
            // Map<String, Product2> mapOfSKUvsProduct = new Map<String, Product2>();
            List<ProductTransfer> transfers = new List<ProductTransfer>();

            // map of ProductId vs ListOfTransfers related to it
            Map<String, List<ProductTransfer>> prodVsQuantLocations = new Map<String, List<ProductTransfer>>();
            for(ProductTransfer pts : [Select Id, SourceLocationId, DestinationLocationId, QuantitySent, Product2Id From ProductTransfer]){
                if(prodVsQuantLocations.containsKey(pts.Product2Id)){
                    List<ProductTransfer> tempList = prodVsQuantLocations.get(pts.Product2Id);
                    tempList.add(pts);
                    prodVsQuantLocations.put(pts.Product2Id, tempList);
                }
                else{
                    prodVsQuantLocations.put(pts.Product2Id, new List<ProductTransfer>{pts});
                }
            }
            for(String barcode : barcodes){
                if(resource!=null){
                    if(productItemMap.containsKey(barcode+'##'+resource.LocationId)){
                        String sourceLocation = productItemMap.get(barcode+'##'+resource.LocationId).locationId;
                        String productId = productItemMap.get(barcode+'##'+resource.LocationId).Product2Id;
                        Integer quantity = 0;
                        //Error occurs here !!!
                        System.debug('@@actualBarcodeMapping = '+actualBarcodeMapping);
                        System.debug('@@actualBarcodeMapping key = '+actualBarcodeMapping.keySet());
                        System.debug('@@barcode locationId2 = '+(barcode+ '##' +locationId2));
                        if(actualBarcodeMapping.containsKey(barcode+ '##' +templocation1)){
                            quantity = Integer.valueOf(actualBarcodeMapping.get(barcode+ '##' +templocation1).split('#\\$#')[1]);
                        }
                        
                        Boolean createTransfers = false;
                        
                            ProductTransfer pt = new ProductTransfer();
                            pt.Product2Id = productId;
                            if(resource != null){
                                pt.SourceLocationId = resource.LocationId;
                            }
                            pt.DestinationLocationId = locationId2;
                            pt.QuantitySent = quantity;
                            pt.QuantityReceived = quantity;
                            pt.IsReceived = true;
                            transfers.add(pt);
                            createTransfers = false;
                        
                    }
                }
                
            }

            if(transfers.size() > 0){
                insert transfers;
            }

            return 'Transfers created successfully for Non-serialized products.';
        }
        catch(Exception e){
            return e.getMessage();
        }
    }

    @AuraEnabled
    public static String checkForDuplicates(String barcode, String locationId, Integer quantity){
        System.debug('@@duplicate check called');
        List<ProductItem> pi = [Select Id, LocationId From ProductItem Where Name__c = :barcode];
        if(pi.size() > 0){

            List<ProductTransfer> pt = [Select Id From ProductTransfer Where SourceLocationId = :pi[0].LocationId AND
                                                                             DestinationLocationId = :locationId AND
                                                                             QuantitySent = :quantity];
            if(pt.size() > 0){
                return 'Warning!';
            }
        }
        return 'No Duplicates!';
    }

    @AuraEnabled
    public static Boolean fetchTechnicianDetails(String scannedId){

        List<ServiceResource> sr = [Select Id, Name From ServiceResource Where Id = :scannedId];
        if(sr.size() > 0){
            return true;
        }
        return false;
    }


    // Code for controller on Create Cycle Counts components
    @AuraEnabled
    public static List<ProductWrapper> getAllProductDetails(String family, String mains, String subs){

        family = family.replace('"','');
        family = family.replace('[','');
        family = family.replace(']', '');
        mains = mains.replace('"','');
        mains = mains.replace('[','');
        mains = mains.replace(']', '');
        subs = subs.replace('"','');
        subs = subs.replace('[','');
        subs = subs.replace(']', '');

        System.debug('@@family= '+family);
        System.debug('@@mains= '+mains);
        System.debug('@@subs= '+subs);

        List<String> familyList = family.split(',');
        List<String> mainList = mains.split(',');
        List<String> subList = subs.split(',');
        System.debug('@@familyList= '+familyList);
        System.debug('@@mainList= '+mainList);
        System.debug('@@subList= '+subList);
        List<ProductWrapper> productList = new List<ProductWrapper>();
        for(Product2 product : [Select Id, Name, Product_Type_Sub__c, Product_Type__c, Family 
                                            From Product2 Where 
                                            (Product_Type_Sub__c in :subList OR
                                            Product_Type__c in :mainList OR
                                            Family in :familyList) AND
                                            IsActive = true]){
            ProductWrapper pw = new ProductWrapper();
            pw.ProductName = product.Name;
            pw.Family = product.Family;
            pw.ProductType = product.Product_Type__c;
            pw.ProductTypeSub = product.Product_Type_Sub__c;
            pw.ID = product.Id;
            productList.add(pw);
        }
        System.debug('@@productList = '+productList);
        return productList;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAllProductFamily(){

        Set<String> families = new Set<String>();
        for(Product2 product : [Select Family From Product2]){
            families.add(product.Family);
        }
        List<String> familyList = new List<String>();
        familyList.addAll(families);
        return familyList;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAllProductTypesMain(){

        Set<String> productType = new Set<String>();
        for(Product2 product : [Select Product_Type__c From Product2]){
            productType.add(product.Product_Type__c);
        }
        List<String> productTypeList = new List<String>();
        productTypeList.addAll(productType);
        return productTypeList;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAllProductTypesSub(){

       Set<String> productType = new Set<String>();
        for(Product2 product : [Select Product_Type_Sub__c From Product2]){
            productType.add(product.Product_Type_Sub__c);
        }
        List<String> productTypeList = new List<String>();
        productTypeList.addAll(productType);
        return productTypeList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Schema.Location> getAllLocations(){

        return [Select Id, Name, LocationType From Location Where LocationType = 'Warehouse'];
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceResource> getAllTechnicians(){
        return [Select Id, Name, LocationId From ServiceResource Where IsActive = true];
    }

    @AuraEnabled
    public static boolean saveCycleCountDates(String cycleCountJSON){
        System.debug('@@cycleCountJSON = '+cycleCountJSON);
        CycleCountDateWrapper ccdw = (CycleCountDateWrapper)JSON.deserialize(cycleCountJSON, CycleCountDateWrapper.class);
        System.debug('@@ccdw = '+ccdw);
        
        String locations = ccdw.Locations;
        locations = locations.replace('"','');
        locations = locations.replace('[','');
        locations = locations.replace(']','');
        locations = locations.replace(',',';');

        String technicians = ccdw.Technicians;
        technicians = technicians.replace('"','');
        technicians = technicians.replace('[','');
        technicians = technicians.replace(']','');
        technicians = technicians.replace(',',';');
        
        String products = ccdw.Products;
        products = products.replace('"','');
        products = products.replace('[','');
        products = products.replace(']','');
        products = products.replace(',',';');

        String productFamily = ccdw.ProductFamily;
        productFamily = productFamily.replace('"','');
        productFamily = productFamily.replace('[','');
        productFamily = productFamily.replace(']','');
        productFamily = productFamily.replace(',',';');

        String productTypeMain = ccdw.ProductTypeMain;
        productTypeMain = productTypeMain.replace('"','');
        productTypeMain = productTypeMain.replace('[','');
        productTypeMain = productTypeMain.replace(']','');
        productTypeMain = productTypeMain.replace(',',';');
        
        String productTypeSub = ccdw.ProductTypeSub;
        productTypeSub = productTypeSub.replace('"','');
        productTypeSub = productTypeSub.replace('[','');
        productTypeSub = productTypeSub.replace(']','');
        productTypeSub = productTypeSub.replace(',',';');

        try { 
            Cycle_Count_Date__c ccd = new Cycle_Count_Date__c();
            ccd.Start_Date_Time__c = (DateTime)Json.deserialize('"'+ccdw.StartDate+'"', DateTime.class);
            ccd.End_Date_Time__c = (DateTime)Json.deserialize('"'+ccdw.EndDate+'"', DateTime.class);
            ccd.Locations__c = locations;
            ccd.Product_Family__c = productFamily;
            ccd.Product_Type_Main__c = productTypeMain;
            ccd.Product_Type_Sub__c = productTypeSub;
            ccd.Products__c = products;
            ccd.Technicians__c = technicians;
            ccd.Timeframe__c = ccdw.TimeFrame;

            List<String> dateString = ccdw.StartDate.split('T');
            ccd.Name = ccdw.TimeFrame + ' - ' + dateString[0];
            insert ccd;
            
            Cycle_Count_Date__c ccdNew = [Select Id,CCD_Number__c, Name From Cycle_Count_Date__c Where Id = :ccd.Id];
            ccdNew.name = ccdNew.CCD_Number__c + ' - ' + ccdNew.Name;
            update ccdNew;
        }
        catch(Exception e){
            System.debug('@@Exception while inserting ccd ' + e.getMessage());
            return false;
        }
        return true;
    }

    public class CycleCountDateWrapper{
        public String StartDate;
        public String EndDate;
        public String Locations;
        public String Products;
        public String ProductFamily;
        public String ProductTypeMain;
        public String ProductTypeSub;
        public String Technicians;
        public String TimeFrame;
    }

    public static void sentRecountNotification(Id ccdID, String[] ccemailAddresses){

        System.debug('@@Got the CCD ID = '+ccdID);

        Map<Id, List<Cycle_Count__c>> techVsCCMap = new Map<Id, List<Cycle_Count__c>>();
        for(Cycle_Count__c cc : [ Select Id, Technician_Inventory_Person__c, Actual_Quantity__c, Total_Listed_Quantity__c, Product_Name__c, Variance__c, Quantity_before_Recount__c, 
                                   Product_Item__r.Product_Type_Sub__c, Product_Item__r.ProductName, Product_Item__r.QuantityUnitOfMeasure
                                    From Cycle_Count__c Where Recount_Needed__c = true 
                                    AND Cycle_Count_Version__r.Cycle_Count_Date__c = :ccdID]) {

            if(cc.Technician_Inventory_Person__c != null) {
                if(!techVsCCMap.containsKey(cc.Technician_Inventory_Person__c)) {
                    techVsCCMap.put(cc.Technician_Inventory_Person__c, new List<Cycle_Count__c>{cc});
                }
                else{
                    List<Cycle_Count__c> ccList = techVsCCMap.get(cc.Technician_Inventory_Person__c);
                    ccList.add(cc);
                    techVsCCMap.put(cc.Technician_Inventory_Person__c, ccList);
                }
            }
            else { 
                System.debug('Inventory Person not filled in');
            }
        }
        System.debug('@@techVsCCMap = '+techVsCCMap);

        Map<Id, String> userVsEmailMap = new Map<Id, String>();
        for(User u : [Select Id, Email From User Where Id In :techVsCCMap.keySet()]) {
            userVsEmailMap.put(u.Id, u.Email);
        }
        System.debug('@@userVsEmailMap = '+userVsEmailMap);

        List<Messaging.SingleEmailMessage> messageListToSend = new List<Messaging.SingleEmailMessage>();
        for(Id userId : techVsCCMap.keySet()) {
            
            //Set ToAddresses
            String[] emailAddresses = new String[]{};
            emailAddresses.add(userVsEmailMap.get(userId));
            String emailBody = '<h3>Please review the following recounts assigned to you:</h3><br><br>';

            emailBody += '<table border="1">'; 
            emailBody +=    '<tr>';
            emailBody +=        '<th>EnergyAid Product SKU</th>';
            emailBody +=        '<th>Product Type (Sub)</th>';
            emailBody +=        '<th>Product Name: Product Name</th>';
            emailBody +=        '<th>Quantity Unit Of Measure</th>';
            emailBody +=        '<th>Quantity On Hand</th>';
            emailBody +=        '<th>Original Count</th>';
            emailBody +=        '<th>Recount 1</th>';
            emailBody +=    '</tr>';
            
            Integer i = 1;
            for(Cycle_Count__c cc : techVsCCMap.get(userId)) {
                emailBody += '<tr>';
                // emailBody += '<td>' + cc.Product_Item__r.EnergyAid_Product_SKU__c + '</td>';
                emailBody += '<td>' + cc.Product_Item__r.Product_Type_Sub__c + '</td>';
                emailBody += '<td>' + cc.Product_Item__r.ProductName + '</td>';
                emailBody += '<td>' + cc.Product_Item__r.QuantityUnitOfMeasure + '</td>';
                emailBody += '<td>' + cc.Total_Listed_Quantity__c + '</td>';
                emailBody += '<td>' + cc.Actual_Quantity__c + '</td>';
                emailBody += '<td>' + cc.Quantity_before_Recount__c + '</td>';
                emailBody += '</tr>';
                i++;
            }
            emailBody += '</table>';

            emailBody +=  '<br><br>All recounts must be completed by 4:00 PM today.';
            emailBody +=  '<br><br>Thank you for your cooperation.';
            
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.toAddresses = emailAddresses;

            if(ccemailAddresses.size() > 0){
                System.debug('cc addresses = '+ccemailAddresses);
                message.setCcAddresses(ccemailAddresses);
            }
            message.subject = 'Recount Needed for Cycle Counts';
            message.setHtmlBody(emailBody);
            messageListToSend.add(message);

            Messaging.SendEmailResult[] results = Messaging.sendEmail(messageListToSend);
            if (results[0].success) {
                System.debug('The email was sent successfully.');
            } else {
                System.debug('The email failed to send: '
                    + results[0].errors[0].message);
            }
        }
    }

    @AuraEnabled
    public static String markComplete() {
        
        Set<Id> ccvIds = new Set<Id>();
        List<Cycle_Count_Version__c> ccvList = new List<Cycle_Count_Version__c>();
        List<Cycle_Count__c> ccList = new List<Cycle_Count__c>();

        for(Cycle_Count__c cc : [Select Id, Cycle_Count_Version__c From Cycle_Count__c Where Completed__c = False AND Technician_Inventory_Person__c = :UserInfo.getUserId()]) {
            ccvIds.add(cc.Cycle_Count_Version__c);
            cc.Completion_DateTime__c = System.now();
            ccList.add(cc);
        }

        for(Cycle_Count_Version__c ccv : [Select Id, Completed__c From Cycle_Count_Version__c Where Id In :ccvIds]){
            ccv.Completed__c = True;
            ccvList.add(ccv);
        }
        if(ccList.size() > 0){
            update ccList;
        }
        if(ccvList.size() > 0){
            update ccvList;
            return 'Updated';
        }
        return 'ERROR';
    }
}