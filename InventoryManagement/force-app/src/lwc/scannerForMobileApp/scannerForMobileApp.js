// barcodeScannerExample.js
import { LightningElement, track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getBarcodeScanner } from 'lightning/mobileCapabilities';
import combinedCycleCount from "@salesforce/apex/CycleCountController.combinedCycleCount";
import fetchLocation from "@salesforce/apex/CycleCountController.fetchLocation";
import fetchActualQuantity from "@salesforce/apex/CycleCountController.fetchActualQuantityForScannedProduct";
import fetchProductName from "@salesforce/apex/CycleCountController.fetchProductNameForScannedProduct";

export default class BarcodeScannerExample extends LightningElement {
    myScanner;
    scanButtonDisabled = false;
    locationScanned = true;
    @track locationName = '';
    @track scannedBarcodeList = [];
    @track scannedcodeList = [];
    @track scannedCodesWithQuantity = [];
    showErrorAlert = false;
    @api errorTitle;
    @api errorMessage;
    @track showPopup = false;
    @track totalQuantity = 0;
    @track actualQuantity = 0;
    @track usedQuantity = 0;
    @track productSKU;
    @track resValAfterScan;
    @track scanVal;
    @track productName;
    @track locationId;
    @track quantityUnitOfMeasure;

    connectedCallback() {
        this.myScanner = getBarcodeScanner();
        if (this.myScanner == null || !this.myScanner.isAvailable()) {
            this.scanButtonDisabled = true;
        }

    }

    handleTotalChange(event) {
        this.totalQuantity = event.target.value;
    }

    handleActualChange(event){
        this.actualQuantity=event.target.value;
    }

    handleUsedChange(event) {
        this.usedQuantity = event.target.value;
    }

    handleBeginScanClick() {
        this.startScan(); // Start scanning
    }

    handleLocationScanner() {
        this.startLocationScan();
    }

    startLocationScan() {
        if (this.myScanner != null && this.myScanner.isAvailable()) {
            const scanningOptions = {
                barcodeTypes: [this.myScanner.barcodeTypes.QR],
                instructionText: 'Scan a QR Code',
                successText: 'Scanning complete.'
            };

            this.myScanner
                .beginCapture(scanningOptions)
                .then((result) => {
                   this.handleScanResultForLocation(result);
                })
                .catch((error) => {
                    this.handleError(error);
                })
                .finally(() => {
                    this.myScanner.endCapture();
                });
        } else {
            this.showErrorMessage('Barcode Scanner is not available.');
        }
    }

    startScan() {
        if (this.myScanner != null && this.myScanner.isAvailable()) {
            const scanningOptions = {
                barcodeTypes: [this.myScanner.barcodeTypes.QR],
                instructionText: 'Scan a QR Code',
                successText: 'Scanning complete.'
            };

            this.myScanner
                .beginCapture(scanningOptions)
                .then((result) => {
                    this.handleScanResult(result);
                })
                .catch((error) => {
                    this.handleError(error);
                })
                .finally(() => {
                    this.myScanner.endCapture();
                });
        } else {
            this.showErrorMessage('Barcode Scanner is not available.');
        }
    }

    handleScanResultForLocation(result) {
        
        
        fetchLocation({ locationId : result.value})
            .then((result1) => {
                if(result1 == 'false'){
                    this.showErrorMessage('Scanned Location does not exist. Please scan the correct location QR code');
                }
                else{
                    this.locationId = result.value;
                    this.locationScanned = false;
                    this.locationName = result1;
                    this.showSuccessMessage('Location found and saved');
                }
            })
    } 

    handleScanResult(result) {
        this.scanVal=result.value;
        //Check if barcode is already scanned or not
        if(this.scannedcodeList.includes(result.value) == false){
            this.scannedcodeList.push(result.value);
            
            // Fetch total Quantity for scanned barcode
            fetchProductName({ code: result.value, locationId: this.locationId })
                .then((result11) => {

                    if(result11.ProductName == null){
                        this.showErrorMessage('Product Not Found. Please scan the correct product.');
                    }
                    else{
                        this.totalQuantity = result11.TotalQuantity;
                        this.productName = result11.ProductName;
                        this.productSKU = result11.ProductSKU;
                        this.quantityUnitOfMeasure = result11.QOM;
                        
                        fetchActualQuantity({code: result.value, locationId: this.locationId })
                        .then((result1) => {
                            this.actualQuantity = result1;
                        })
                        .catch((error1) => {
                            console.log('Error fetching actual quantity');
                        });
                        this.showPopup=true;
                    }
                })
                .catch((error) => {
                    console.log('Error fetching details');
                });
            
        }
        else{
           this.showErrorMessage('QR already scanned');
        }
       
    }
    handleSave() {
            if(this.totalQuantity == null || this.totalQuantity == undefined){
                this.totalQuantity = 0;
            }
            if(this.usedQuantity == null || this.usedQuantity == undefined){
                this.usedQuantity = 0;
            }
            if(this.actualQuantity == null || this.actualQuantity == undefined){
                this.actualQuantity = 0;
            }
            this.resValAfterScan =this.scanVal+'#$#'+this.totalQuantity+'#$#'+this.usedQuantity; 
            if(this.scannedBarcodeList.includes(this.resValAfterScan) == false){
                this.scannedBarcodeList.push(this.resValAfterScan);
                let valsWithQuantity = this.scanVal+', Total Quantity = '+this.totalQuantity+', Actual Quantity = '+this.usedQuantity; 
                this.scannedCodesWithQuantity.push(valsWithQuantity);
                this.showSuccessMessage('Barcode scanned successfully.');
                this.showPopup=false;
                this.totalQuantity = 0;
                this.usedQuantity = 0;
                this.actualQuantity = 0;
            }
    }

    handleError(error) {
        console.error('Scan error:', error);
        if (error.code === 'userDismissedScanner') {
            this.showErrorMessage('Scanning cancelled.');
        } else {
            this.showErrorMessage('Error scanning barcode: ' + error.message);
        }
    }

    handleFinishClick() {
        
        if (this.scannedBarcodeList.length === 0) {
            this.showErrorMessage('No barcodes scanned.');
            return;
        }

        // Process scanned barcodes
        combinedCycleCount({ barcodes: this.scannedBarcodeList, locationId : this.locationId })
            .then((result) => {
                if (result.startsWith('Error')) {
                    this.errorTitle = 'Error';
                    this.errorMessage = result;
                    this.showErrorAlert = true;
                } else {
                    this.showSuccessMessage(result);
                    // Clear the scanned barcode list after processing
                    this.scannedBarcodeList = [];
                }
            })
            .catch((error) => {
                this.showErrorMessage('Error updating Cycle Count records: ' + error.body.message);
            });
    }
    

    showSuccessMessage(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        );
    }

    showErrorMessage(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }
}