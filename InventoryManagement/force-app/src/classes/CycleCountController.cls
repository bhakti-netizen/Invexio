public class CycleCountController {

    @AuraEnabled
    public static String combinedCycleCount(List<String> barcodes, String locationId){
        
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
        for(SerializedProduct sp : [Select Id, SerialNumber, Product2Id, ProductItemId, Product_Name__c, ProductItem.LocationId From SerializedProduct]){
            serProdMap.put(sp.SerialNumber, sp);
            
        }

        // Map to store ProductItem records based on barcode
        Map<String, ProductItem> productItemMap = new Map<String, ProductItem>();
        for(ProductItem nsp : [SELECT Id, SerialNumber, Product2Id,ProductItemNumber, ProductName, LocationId, EnergyAid_Product_SKU__c, Name__c FROM ProductItem WHERE IsProduct2Serialized = false]){
            // productItemMap.put(nsp.ProductItemNumber, nsp); //Commented to use Product SKU in cycle counting for Non serialized products
            productItemMap.put(nsp.Name__c + '##' + nsp.LocationId , nsp);
            
        }


        Set<String> barcodesForSP  = new Set<String>();
        List<String> barcodesForNSP = new List<String>();

        for(String s : barcodesSeparated){
            if(serProdMap.containsKey(s)){
                barcodesForSP.add(s);
                // locationId1 = serProdMap.get(s).ProductItem.LocationId;
            }
            else if(productItemMap.containsKey(s+ '##' +locationId)){
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
            msg1 = createCycleCountRecordForSP(barcodesForSP, serProdMap, locationId, actualBarcodeMapping);
        }
        if(barcodesForNSP.size() > 0){
            msg2 = createCycleCountRecordForNSP(barcodesForNSP, productItemMap, locationId, actualBarcodeMapping);
        }
        msg = msg1 + ' ' + msg2;
        return msg;
    }

    
    public static string createCycleCountRecordForSP(Set<String> barcodes, Map<String, SerializedProduct> serProdMap, Id locationId1, Map<String, String> actualBarcodeMapping){
        String msg = '';
        System.debug('@@barcodeList = '+barcodes);
        try{

            system.debug('@@SerProdMap = '+serProdMap);

            //Name vs CCD
            Map<String, Cycle_Count_Date__c> ccdMap = new Map<String, Cycle_Count_Date__c>();
            for(Cycle_Count_Date__c ccd : [Select Id, Name, Location__c, Cycle_Count_Date__c From Cycle_Count_Date__c]){
                ccdMap.put(ccd.Name, ccd);
            }

            //Name vs CCV
            Map<String, Cycle_Count_Version__c> ccvMap = new Map<String, Cycle_Count_Version__c>();
            for(Cycle_Count_Version__c ccv : [Select Id, Active__c, Name, Location__c, Product__c From Cycle_Count_Version__c]){
                ccvMap.put(ccv.Name, ccv);
            }
            system.debug('@@ccvMap = '+ccvMap);

            //Serialized Product vs Cycle Count for Today
            Map<String, Cycle_Count__c> ccMap = new Map<String, Cycle_Count__c>();
            for(Cycle_Count__c cc : [Select Id, Serialized_Product__c, Cycle_Count_Version__c, Active_Count__c,Actual_Quantity__c  From Cycle_Count__c Where CreatedDate = TODAY]){
                ccMap.put(cc.Serialized_Product__c, cc);
            }

            Id locationId = locationId1;
            // List<ServiceResource> sr = [Select id, LocationId, RelatedRecordId from ServiceResource where RelatedRecordId =: UserInfo.getUserId() Limit 1];
            // if(sr.size() > 0){
            //     locationId = sr[0].LocationId;
            // }
            // else{
            //    locationId =  locationId1;
            // }
            String todaysDate = String.valueOf(Date.Today());
            system.debug('@@locationId = '+locationId);
            system.debug('@@todaysDate = '+todaysDate);

            String locationName = [Select Id, Name From Location Where Id = :locationId LIMIT 1].Name;

            Cycle_Count_Date__c ccd;
            if(!ccdMap.containsKey(todaysDate + ' - ' + locationName)){
                
                ccd = new Cycle_Count_Date__c();
                ccd.Name = todaysDate + ' - ' + locationName;
                ccd.Location__c = locationId;
                ccd.Cycle_Count_Date__c = Date.Today();
                insert ccd;
                
            }
            else{
                ccd = ccdMap.get(todaysDate + ' - ' + locationName);
            }


            List<Cycle_Count__c> ccToInsert = new List<Cycle_Count__c>();
            List<Cycle_Count__c> ccToUpdate = new List<Cycle_Count__c>();
            List<SerializedProduct> spToUpdate = new List<SerializedProduct>();
            for(String s : barcodes){
                system.debug('@@in for');
                if(serProdMap.containsKey(s)){
                    SerializedProduct sp = serProdMap.get(s);

                    Integer totalQuantity = Integer.valueOf(actualBarcodeMapping.get(s+ '##' +locationId).split('#\\$#')[1]);
                    Integer actualQuantity = Integer.valueOf(actualBarcodeMapping.get(s+ '##' +locationId).split('#\\$#')[2]);

                    if(!ccvMap.containsKey(sp.Product_Name__c + ' - ' + todaysDate + ' - ' + locationName)){
                        Cycle_Count_Version__c ccv = new Cycle_Count_Version__c();
                        ccv.Name = sp.Product_Name__c + ' - ' + todaysDate + ' - ' + locationName;
                        ccv.Location__c = locationId;
                        ccv.Product__c = sp.Product2Id;
                        ccv.Cycle_Count_Date__c = ccd.Id;
                        insert ccv;
                        ccvMap.put(ccv.Name, ccv);
                        system.debug('@@inserted ccv'+ccv);

                        Cycle_Count__c cc = new Cycle_Count__c();
                        cc.Serialized_Product__c = sp.Id;
                        cc.Cycle_Count_Version__c = ccv.Id;
                        cc.Product_Item__c = sp.ProductItemId;
                        cc.Active_Count__c = true;
                        cc.Total_Listed_Quantity__c = totalQuantity;
                        cc.Actual_Quantity__c = actualQuantity;
                        ccToInsert.add(cc);
                        system.debug('@@added cc'+cc);

                    }
                    else{
                        if(!ccMap.containsKey(sp.Id)){
                            
                            Cycle_Count__c cc = new Cycle_Count__c();
                            cc.Serialized_Product__c = sp.Id;
                            cc.Cycle_Count_Version__c = ccvMap.get(sp.Product_Name__c + ' - ' + todaysDate + ' - ' + locationName).Id;
                            cc.Product_Item__c = sp.ProductItemId;
                            cc.Active_Count__c = true;
                            cc.Total_Listed_Quantity__c = totalQuantity;
                            cc.Actual_Quantity__c = actualQuantity;
                            ccToInsert.add(cc);
                            system.debug('@@added cc in else');
                        }
                        else{
                            Cycle_Count__c cc = ccMap.get(sp.Id);
                            cc.Actual_Quantity__c += actualQuantity;
                            ccToUpdate.add(cc);
                        }
                    }

                    // //Update Quantity on Serialized Product
                    // if(actualBarcodeMapping.containsKey(s)){
                    //     Integer totalQuantity = Integer.valueOf(actualBarcodeMapping.get(s).split('#\\$#')[1]);
                    //     Integer usedQuantity = Integer.valueOf(actualBarcodeMapping.get(s).split('#\\$#')[2]);
                    //     // sp.Total_Quantity__c = totalQuantity;
                    //     sp.Used_Quantity__c = usedQuantity;
                    //     spToUpdate.add(sp);
                    // }
                }


            }

            // if(spToUpdate.size() > 0){
            //     System.debug('@@Updating SPs');
            //     update spToUpdate;
            //     msg = 'Updated Quantities on Serialized Products. ';
            // }
            if(ccToInsert.size() > 0){
                system.debug('@@size > 0');
                insert ccToInsert;
                msg += 'Total ' + ccToInsert.size() + ' Cycle Count records have been updated/created successfully for Serialized Products.';
            }
            if(ccToUpdate.size() > 0){
                update ccToUpdate;
                msg += 'Total ' + ccToUpdate.size() + ' Cycle Count records have been updated successfully for Serialized Products.';
            }
            if(ccToInsert.size() == 0 && ccToUpdate.size() == 0) {
                msg = 'No Cycle Count records were created/updated. Ensure that the provided barcodes are valid and meet the necessary criteria.';
            }


        }catch(QueryException e){
            msg = 'Invalid QR Code.';
        }catch(Exception e) {
            msg = e.getMessage();    
        }
        return msg;

    }

     
    public static string createCycleCountRecordForNSP(List<String> barcodes, Map<String, ProductItem> productItemMap, Id locationId2, Map<String, String> actualBarcodeMapping) {
            String msg = '';
            try {

                System.debug('ProductItem Map: ' + productItemMap);

                if(productItemMap.isEmpty()) {
                    return 'No ProductItem records found for the provided barcodes.';
                }

                // Map to store Cycle Count Date records
                Map<String, Cycle_Count_Date__c> ccdMap = new Map<String, Cycle_Count_Date__c>();
                for(Cycle_Count_Date__c ccd : [SELECT Id, Name, Location__c, Cycle_Count_Date__c FROM Cycle_Count_Date__c]){
                    ccdMap.put(ccd.Name, ccd);
                }

                // Map to store Cycle Count Version records
                Map<String, Cycle_Count_Version__c> ccvMap = new Map<String, Cycle_Count_Version__c>();
                for(Cycle_Count_Version__c ccv : [SELECT Id, Active__c, Name, Location__c, Product__c FROM Cycle_Count_Version__c]){
                    ccvMap.put(ccv.Name, ccv);
                }

                // Map to store existing Cycle Count records for today
                Map<String, Cycle_Count__c> ccMap = new Map<String, Cycle_Count__c>();
                for(Cycle_Count__c cc : [SELECT Id, Product_Item__c, Cycle_Count_Version__c, Active_Count__c, Actual_Quantity__c FROM Cycle_Count__c WHERE CreatedDate = TODAY]){
                    ccMap.put(cc.Product_Item__c, cc);
                }

                Id locationId = locationId2;
                // Get locationId
                // Id locationId = [SELECT Id, LocationId FROM ServiceResource WHERE RelatedRecordId = :UserInfo.getUserId()].LocationId;
                // List<ServiceResource> sr = [Select id, LocationId, RelatedRecordId from ServiceResource where RelatedRecordId =: UserInfo.getUserId() Limit 1];
                // if(sr.size() > 0){
                //     locationId = sr[0].LocationId;
                // }
                // else{
                //     locationId =  locationId2;
                // }
                String todaysDate = String.valueOf(Date.Today());

                String locationName = [Select Id, Name From Location Where Id = :locationId LIMIT 1].Name;

                Cycle_Count_Date__c ccd;
                if(!ccdMap.containsKey(todaysDate + ' - ' + locationName)){
                    ccd = new Cycle_Count_Date__c(
                        Name = todaysDate + ' - ' + locationName,
                        Location__c = locationId,
                        Cycle_Count_Date__c = Date.Today()
                    );
                    insert ccd;
                } else {
                    ccd = ccdMap.get(todaysDate + ' - ' + locationName);
                }

                List<Cycle_Count__c> ccToInsert = new List<Cycle_Count__c>();
                List<Cycle_Count__c> ccToUpdate = new List<Cycle_Count__c>();
                List<ProductItem> piToUpdate = new List<ProductItem>();
                for(String barcode : barcodes){
                    if(productItemMap.containsKey(barcode+ '##' +locationId)){
                        
                        ProductItem nsp = productItemMap.get(barcode+ '##' +locationId);

                        Integer totalQuantity = Integer.valueOf(actualBarcodeMapping.get(barcode+ '##' +locationId).split('#\\$#')[1]);
                        Integer actualQuantity = Integer.valueOf(actualBarcodeMapping.get(barcode+ '##' +locationId).split('#\\$#')[2]);

                        if(!ccvMap.containsKey(nsp.ProductName + ' - ' + todaysDate + ' - ' + locationName)){
                            Cycle_Count_Version__c ccv = new Cycle_Count_Version__c(
                                Name = nsp.ProductName + ' - ' + todaysDate + ' - ' + locationName,
                                Location__c = locationId,
                                Product__c = nsp.Product2Id,
                                Cycle_Count_Date__c = ccd.Id
                            );
                            insert ccv;
                            ccvMap.put(ccv.Name, ccv);

                            Cycle_Count__c cc = new Cycle_Count__c(
                                Product_Item__c = nsp.Id,
                                Cycle_Count_Version__c = ccv.Id,
                                Active_Count__c = true,
                                Total_Listed_Quantity__c = totalQuantity,
                                Actual_Quantity__c = actualQuantity
                            );
                            ccToInsert.add(cc);
                            
                        } else {
                            if(!ccMap.containsKey(nsp.Id)){                 //insert case
                                Cycle_Count__c cc = new Cycle_Count__c(
                                    Product_Item__c = nsp.Id,
                                    Cycle_Count_Version__c = ccvMap.get(nsp.ProductName + ' - ' + todaysDate + ' - ' + locationName).Id,
                                    Active_Count__c = true,
                                    Total_Listed_Quantity__c = totalQuantity,
                                    Actual_Quantity__c = actualQuantity
                                );
                                ccToInsert.add(cc);
                            }
                            else{                                           //update case
                                Cycle_Count__c cc = ccMap.get(nsp.Id);
                                cc.Actual_Quantity__c += actualQuantity;
                                ccToUpdate.add(cc);
                            }
                        }

                        // //Update Quantity on Serialized Product
                        // if(actualBarcodeMapping.containsKey(barcode)){
                        //     Integer totalQuantity = Integer.valueOf(actualBarcodeMapping.get(barcode).split('#\\$#')[1]);
                        //     Integer usedQuantity = Integer.valueOf(actualBarcodeMapping.get(barcode).split('#\\$#')[2]);
                        //     nsp.Overall_Quantity__c = totalQuantity;
                        //     nsp.Allocated_Inventory__c = usedQuantity;
                        //     piToUpdate.add(nsp);
                        // }
                    }
                }

                // if(piToUpdate.size() > 0){
                //     System.debug('@@updating PI');
                //     update piToUpdate;
                //     msg = 'Updated Quantities on Product Items. ';
                // }
                if(ccToInsert.size() > 0){
                    insert ccToInsert;
                    msg += 'Total ' + ccToInsert.size() + ' Cycle Count records have been created successfully for Non-Serialized Products.';
                } 
                if(ccToUpdate.size() > 0){
                    update ccToUpdate;
                    msg += 'Total ' + ccToUpdate.size() + ' Cycle Count records have been updated successfully for Non-Serialized Products.';
                }
                if(ccToInsert.size() == 0 && ccToUpdate.size() == 0) {
                    msg = 'No Cycle Count records were created/updated. Ensure that the provided barcodes are valid and meet the necessary criteria.';
                }
            } catch(Exception e) {
                msg = 'An error occurred: ' + e.getMessage();    
            }
            return msg;
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

        List<SerializedProduct> spList = [Select Id,Product_Name__c, EnergyAid_Product_SKU__c, Total_Quantity__c, Product2.QuantityUnitOfMeasure From SerializedProduct Where SerialNumber = :code];
        if(spList.size() > 0){
            ProductWrapper wrapper = new ProductWrapper();
            wrapper.ProductName = spList[0].Product_Name__c;
            wrapper.ProductSKU = spList[0].EnergyAid_Product_SKU__c;
            wrapper.TotalQuantity = spList[0].Total_Quantity__c;
            wrapper.QOM = spList[0].Product2.QuantityUnitOfMeasure;
            return wrapper;
            // return spList[0].Product_Name__c + '##' + spList[0].EnergyAid_Product_SKU__c;
        }
        else{
            // List<ProductItem> piList = [Select Id,Product2.Name, EnergyAid_Product_SKU__c, QuantityOnHand From ProductItem Where ProductItemNumber =: code];
            List<ProductItem> piList = [Select Id,Product2.Name, EnergyAid_Product_SKU__c, QuantityOnHand, Name__c, QuantityUnitOfMeasure From ProductItem Where Name__c =: code];
            if(piList.size() > 0){
                ProductWrapper wrapper = new ProductWrapper();
                wrapper.ProductName = piList[0].Product2.Name;
                wrapper.ProductSKU = piList[0].EnergyAid_Product_SKU__c;
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
        AND Product_Item__r.LocationId =: locationId AND 
        Createddate = TODAY];
        System.debug('ccList = '+ccList);
        if(ccList.size() > 0){
            return ccList[0].Actual_Quantity__c;
        }
        else{
                return 0;
            }
        
    }

    @AuraEnabled
    public static Boolean fetchLocation(String locationId){
        try{
            String locationName = [Select Id, Name From Location Where Id = :locationId LIMIT 1].Name;
            if(locationName != null){
                return true;
            }
            return false;
        }
        catch(Exception e){
            return false;
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
            for(ProductItem nsp : [SELECT Id, SerialNumber, Product2Id,ProductItemNumber, ProductName, LocationId, EnergyAid_Product_SKU__c, Name__c FROM ProductItem WHERE IsProduct2Serialized = false]){
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

                    // if(mapOfSPvsTransfers.containsKey(serProdMap.get(barcode).Id)){
                    //     for(ProductTransfer tempPT : mapOfSPvsTransfers.get(serProdMap.get(barcode).Id)){
                    //         if(tempPT.SourceLocationId == serProdMap.get(barcode).ProductItem.LocationId
                    //         && tempPT.DestinationLocationId == locationId1
                    //         && tempPT.QuantitySent == 1){
                    //             return 'Warning! A similar type of product transfer exists!!';
                    //         }
                    //     }
                    // }
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
                        // if(prodVsQuantLocations.containsKey(productId)){
                        //     for(ProductTransfer tempPT : prodVsQuantLocations.get(productId)){
                        //         if(tempPT.SourceLocationId == sourceLocation 
                        //         && tempPT.DestinationLocationId == locationId2 
                        //         && tempPT.QuantitySent == quantity){
                        //             return 'Warning!';
                        //         }
                        //         else{
                        //             createTransfers= true;

                        //         }
                        //     }
                        // }
                        // else{
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
                        // }
                        
                        // if(createTransfers == true){
                        //     ProductTransfer pt = new ProductTransfer();
                        //     pt.Product2Id = productId;
                        //     pt.SourceLocationId = sourceLocation;
                        //     pt.DestinationLocationId = locationId2;
                        //     pt.QuantitySent = quantity;
                        //     transfers.add(pt);
                        // }
                    }
                }
                
            }

            // for(Product2 prod : [Select Id, EnergyAid_Product_SKU__c From Product2 Where EnergyAid_Product_SKU__c In :barcodes]){
            //     mapOfSKUvsProduct.put(prod.EnergyAid_Product_SKU__c, prod);
            // }

            // for(String barcode : barcodes){
            //     if(mapOfSKUvsProduct.containsKey(barcode)){
            //         ProductTransfer pt = new ProductTransfer();
            //         pt.Product2Id = mapOfSKUvsProduct.get(barcode).Id;
            //         pt.SourceLocationId = locationId2;
            //         pt.DestinationLocationId = locationId2;
            //         pt.QuantitySent = Integer.valueOf(actualBarcodeMapping.get(barcode+ '##' +locationId2).split('#\\$#')[1]);
            //         transfers.add(pt);
            //     }
            // }
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
}