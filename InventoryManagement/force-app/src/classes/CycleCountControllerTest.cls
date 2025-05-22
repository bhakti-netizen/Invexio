@isTest
public class CycleCountControllerTest {
	 @testSetup
    static void setupData() {
       
        Schema.Location loc1 = new Schema.Location(Name = 'Test Location 1', LocationType='Warehouse',IsInventoryLocation=true,IsMobile=true);
        insert loc1;

        Schema.Location loc2 = new Schema.Location(Name = 'Test Location 2', LocationType='Warehouse',IsInventoryLocation=true,IsMobile=true);
        insert loc2;

        Product2 prod1 = new Product2(Name = 'Test Product 1', 
                                      ProductCode = 'TP1',
                                      IsSerialized=true,
                                      IsActive=true,
                                      Family='Inventory',
                                      Product_Type__c = 'Module',
                                      Product_Type_Sub__c = 'Module'
                                     );
        insert prod1;

         ProductItem pi1 = new ProductItem(
            Product2Id = prod1.Id,
            LocationId = loc1.Id,
            QuantityOnHand = 0
        );
        insert pi1;
        
        SerializedProduct sp1 = new SerializedProduct(
            SerialNumber = 'SP001',
            Product2Id = prod1.Id,
            ProductItemId = pi1.Id,
            Total_Quantity__c=100
        );
        insert sp1;

        SerializedProduct sp2 = new SerializedProduct(
            SerialNumber = 'SP002',
            Product2Id = prod1.Id,
            ProductItemId = pi1.Id,
            Total_Quantity__c=100
        );
        insert sp2;

        /* Data for NONSP*/
        Product2 prod2 = new Product2(Name = 'Test Product 2', 
                                      ProductCode = 'TP2',
                                      IsSerialized=false,
                                      IsActive=true,
                                      Family='Inventory',
                                      Product_Type__c = 'Module',
                                      Product_Type_Sub__c = 'Module');
        insert prod2;

         ProductItem pi2 = new ProductItem(
            Product2Id = prod2.Id,
            LocationId = loc1.Id,
            QuantityOnHand = 10
        );
        insert pi2;

        ProductItem pi3 = new ProductItem(
            Product2Id = prod2.Id,
            LocationId = loc2.Id,
            QuantityOnHand = 10
        );
        insert pi3;

        ServiceResource sr1 = new ServiceResource(
            Name='TestSR',
            LocationId = loc1.Id,
            RelatedRecordId = UserInfo.getUserId()
        );
        insert sr1;
    }

    /*@isTest
    static void testCombinedCycleCount() {
        Test.startTest();

        List<ProductItem> pi = [Select Id, ProductItemNumber From ProductItem Where IsProduct2Serialized = false];
        List<String> barcodes = new List<String>{
            'SP001#$#100#$#30',
            'SP002#$#100#$#30',
            pi[0].ProductItemNumber + '#$#10#$#7',
            pi[1].ProductItemNumber + '#$#10#$#7'
        };
   
        Schema.Location loc = [Select Id From Location Where Name = 'Test Location 1' LIMIT 1];
        CycleCountController.combinedCycleCount(barcodes, loc.Id);
		
        Test.stopTest();
    }*/

    @isTest
    static void testFetchTotalQuantityForScannedProduct() {
        Test.startTest();
		
        Schema.Location loc = [Select Id From Location LIMIT 1];
        ServiceResource sr = [Select Id From ServiceResource LIMIT 1];
        
        Decimal totalQuantity = CycleCountController.fetchTotalQuantityForScannedProduct('SP001');
        Decimal totalQuantity1 = CycleCountController.fetchTotalQuantityForScannedProduct([Select Id, ProductItemNumber, Name__c From ProductItem Where IsProduct2Serialized = true LIMIT 1].Name__c);
        System.assertEquals(100, totalQuantity, 'Expected total quantity for Serialized Product');
        
        CycleCountController.fetchProductNameForScannedProduct('SP001', loc.Id);
		CycleCountController.fetchProductNameForScannedProduct([Select Id, ProductItemNumber, Name__c From ProductItem Where IsProduct2Serialized = true LIMIT 1].Name__c, loc.Id);
        
        CycleCountController.fetchActualQuantityForScannedProduct('SP001', loc.Id);
        CycleCountController.fetchActualQuantityForScannedProduct([Select Id, ProductItemNumber, Name__c From ProductItem Where IsProduct2Serialized = true LIMIT 1].Name__c, loc.Id);
        
        CycleCountController.fetchLocation(loc.Id);
        CycleCountController.fetchTechnicianDetails(sr.Id);
        
        CycleCountController.getAllProductFamily();
        CycleCountController.getAllProductTypesMain();
        CycleCountController.getAllProductTypesSub();
        CycleCountController.getAllLocations();
        CycleCountController.markComplete();
        CycleCountController.getAllProductDetails('Inventory', 'Module', 'Module');
        
        Test.stopTest();
    }
    
    @isTest
    public static void testCCD(){
        Schema.Location loc = [Select Id From Location LIMIT 1];
        ServiceResource sr = [Select Id From ServiceResource LIMIT 1];
        
        CycleCountController.CycleCountDateWrapper ccdWrapper = new CycleCountController.CycleCountDateWrapper();
        ccdWrapper.StartDate = '2025-03-03T11:45:00.000Z'; //DateTime.now().format();
        ccdWrapper.EndDate = '2025-03-10T10:45:00.000Z';//(DateTime.now()+1).format();
        ccdWrapper.Locations = (String)loc.Id;
        ccdWrapper.Products = (String)([Select Id From product2 LIMIT 1].Id);
        ccdWrapper.ProductFamily = 'Inventory';
        ccdWrapper.ProductTypeMain = 'Module';
        ccdWrapper.ProductTypeSub = 'Module';
         ccdWrapper.Technicians = sr.Id;
        ccdWrapper.TimeFrame = 'Weekly';
        String ccdJson = JSON.serialize(ccdWrapper);
        CycleCountController.saveCycleCountDates(ccdJson);
        
        List<ProductItem> pi = [Select Id, ProductItemNumber, Name__c From ProductItem Where IsProduct2Serialized = false];
        List<String> barcodes = new List<String>{
            'SP001#$#100#$#30',
            'SP002#$#100#$#30',
            pi[0].Name__c + '#$#10#$#7',
            pi[1].Name__c + '#$#10#$#7'
        };
            
        Schema.Location loc1 = [Select Id From Location Where Name = 'Test Location 1' LIMIT 1];
        CycleCountController.combinedCycleCount(barcodes, loc1.Id);
        CycleCountController.combinedPullMaterials(barcodes, loc1.Id, True, sr.Id);
        
        Cycle_Count__c cc = [ Select Id, Recount_Needed__c, Cycle_Count_Version__r.Cycle_Count_Date__c From Cycle_Count__c LIMIT 1];
        cc.Recount_Needed__c = True;
        update cc;
        
		CycleCountController.sentRecountNotification(cc.Cycle_Count_Version__r.Cycle_Count_Date__c, new String[]{});
        
        CycleCountController.checkForDuplicates('SP001', loc1.Id, 10);
        
    }

 

}