@isTest
public class CycleCountControllerTest {
	 @testSetup
    static void setupData() {
       
        Schema.Location loc1 = new Schema.Location(Name = 'Test Location 1', LocationType='Warehouse',IsInventoryLocation=true,IsMobile=true);
        insert loc1;

        Schema.Location loc2 = new Schema.Location(Name = 'Test Location 2', LocationType='Warehouse',IsInventoryLocation=true,IsMobile=true);
        insert loc2;

        Product2 prod1 = new Product2(Name = 'Test Product 1', ProductCode = 'TP1',IsSerialized=true,IsActive=true,Family='Inventory');
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
        Product2 prod2 = new Product2(Name = 'Test Product 2', ProductCode = 'TP2',IsSerialized=false,IsActive=true,Family='Inventory');
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

    @isTest
    static void testCombinedCycleCount() {
        Test.startTest();

        List<ProductItem> pi = [Select Id, ProductItemNumber From ProductItem Where IsProduct2Serialized = false];
        List<String> barcodes = new List<String>{
            'SP001#$#100#$#30',
            'SP002#$#100#$#30',
            pi[0].ProductItemNumber + '#$#10#$#7',
            pi[1].ProductItemNumber + '#$#10#$#7'
        };
        
        String result = CycleCountController.combinedCycleCount(barcodes);
        System.assert(result.contains('Cycle Count records have been updated/created successfully'), 'Expected success message in result');

        Decimal actualQuantity = CycleCountController.fetchActualQuantityForScannedProduct([Select Id, ProductItemNumber From ProductItem Where IsProduct2Serialized = true LIMIT 1].ProductItemNumber);
        System.assertEquals(30, actualQuantity, 'Expected actual quantity for Product Item');
		
        Test.stopTest();
    }

    @isTest
    static void testFetchTotalQuantityForScannedProduct() {
        Test.startTest();

        Decimal totalQuantity = CycleCountController.fetchTotalQuantityForScannedProduct('SP001');
        Decimal totalQuantity1 = CycleCountController.fetchTotalQuantityForScannedProduct([Select Id, ProductItemNumber From ProductItem Where IsProduct2Serialized = true LIMIT 1].ProductItemNumber);
        System.assertEquals(100, totalQuantity, 'Expected total quantity for Serialized Product');
        
        String productName = CycleCountController.fetchProductNameForScannedProduct('SP001');
        String productName1 = CycleCountController.fetchProductNameForScannedProduct([Select Id, ProductItemNumber From ProductItem Where IsProduct2Serialized = true LIMIT 1].ProductItemNumber);
        

        Test.stopTest();
    }

}