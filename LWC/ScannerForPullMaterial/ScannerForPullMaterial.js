// barcodeScannerExample.js
import { LightningElement, track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getBarcodeScanner } from 'lightning/mobileCapabilities';
import fetchLocation from "@salesforce/apex/CycleCountController.fetchLocation";
import fetchProductName from "@salesforce/apex/CycleCountController.fetchProductNameForScannedProduct";
import combinedPullMaterials from "@salesforce/apex/CycleCountController.combinedPullMaterials";
import fetchTechnicianDetails from "@salesforce/apex/CycleCountController.fetchTechnicianDetails";
// import checkForDuplicates from "@salesforce/apex/CycleCountController.checkForDuplicates";

export default class ScannerForPullMaterial extends LightningElement {
    myScanner;
    scanButtonDisabled = true;
    locationScanned = true;
    @track scannedBarcodeList = [];
    @track scannedcodeList = [];
    @track scannedCodesWithQuantity = [];
    showErrorAlert = false;
    @api errorTitle;
    @api errorMessage;
    @track showWarning = false;
    @track showPopup = false;
    @track totalQuantity = 0;
    @track actualQuantity = 0;
    @track usedQuantity = 0;
    @track productSKU;
    @track quantityUnitOfMeasure;
    @track resValAfterScan;
    @track scanVal;
    @track productName;
    @track locationId;
    @track quantity = 0;
    @track disableFinish = true;
    @track technicianId;
    @track scanButtonTechnicianDisabled = false;
    @track showPopupForTechnician = false;
    @track popupTechnicianId;

    connectedCallback() {
        this.myScanner = getBarcodeScanner();
        if (this.myScanner == null || !this.myScanner.isAvailable()) {
            this.scanButtonDisabled = true;
        }

    }

    handleQuantityChange(event) {
        this.quantity = event.target.value;
    }

    
    handleBeginScanClick() {
        // alert('Check alert!!');
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

    handleTechnicianScanner(){
        if (this.myScanner != null && this.myScanner.isAvailable()) {
            const scanningOptions = {
                barcodeTypes: [this.myScanner.barcodeTypes.QR],
                instructionText: 'Scan a QR Code',
                successText: 'Scanning complete.'
            };

            this.myScanner
                .beginCapture(scanningOptions)
                .then((result) => {
                   this.handleScanResultForTechnician(result.value);
                //    this.scanButtonDisabled = false;
                   
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
                if(result1 == false){
                    
                    this.showErrorMessage('Scanned Location does not exist. Please scan the correct location QR code');
                }
                else{
                    this.locationId = result.value;
                    this.locationScanned = false;
                    this.showSuccessMessage('Location found and saved');
                }
            })
    } 

    handleScanResultForTechnician(result) {

        fetchTechnicianDetails({ scannedId : result})
            .then((result1) => {
                if(result1 == false){
                    this.scanButtonDisabled = true;
                    this.showPopupForTechnician = true;
                    this.showErrorMessage('Scanned Technician does not exist. Please scan the correct Technician QR code');
                }
                else{
                    this.technicianId = result;
                    this.scanButtonDisabled = false;
                    this.showPopupForTechnician = false;
                }
            })
    }

    popupTechnicianOnchange(event){
        // this.popupTechnicianId = event.target.value;
        this.popupTechnicianId = event.detail.recordId;
    }

    handlepopupTechnician(){
        this.handleScanResultForTechnician(this.popupTechnicianId);
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

    proceed(){
        this.showWarning = false;
        this.resValAfterScan =this.scanVal+'#$#'+this.quantity; 
        if(this.scannedBarcodeList.includes(this.resValAfterScan) == false){
            this.scannedBarcodeList.push(this.resValAfterScan);
            let valsWithQuantity = this.scanVal+', Quantity = '+this.quantity; 
            this.scannedCodesWithQuantity.push(valsWithQuantity);
            this.showSuccessMessage('Barcode scanned successfully.');
            this.showPopup=false;
            this.quantity = 0;
        }
        this.disableFinish = false;
        if (this.scannedBarcodeList.length === 0) {
            this.showErrorMessage('No barcodes scanned.');
            return;
        }

    }
    doNotProceed(){
        this.showWarning = false;
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

            // checkForDuplicates({ barcode: this.scanVal, locationId : this.locationId, quantity : this.quantity })
            // .then((result) => {
            //     if (result.startsWith('Warning!')) {
            //         this.showWarning = true;
            //         this.showPopup = false;
            //     } else {
            //         this.showWarning = false;
                    this.showPopup=false;
                    this.resValAfterScan =this.scanVal+'#$#'+this.quantity; 
                    if(this.scannedBarcodeList.includes(this.resValAfterScan) == false){
                        this.scannedBarcodeList.push(this.resValAfterScan);
                        let valsWithQuantity = this.scanVal+', Quantity = '+this.quantity; 
                        this.scannedCodesWithQuantity.push(valsWithQuantity);
                        this.showSuccessMessage('Barcode scanned successfully.');
                        this.disableFinish = false;
                        this.quantity = 0;
                    }
            //     }
            // })
            // .catch((error) => {
            //     this.showErrorMessage('Error updating Pulling Materials: ' + error.body.message);
            //     this.disableFinish = false;
            // });

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
        
        this.disableFinish = true;
        if (this.scannedBarcodeList.length === 0) {
            this.showErrorMessage('No barcodes scanned.');
            return;
        }

        // Process scanned barcodes
        combinedPullMaterials({ barcodes: this.scannedBarcodeList, locationId : this.locationId, showWarning : this.showWarning, technicianId: this.technicianId })
            .then((result) => {
                if (result.startsWith('Warning!')) {
                    this.errorTitle = 'Error';
                    this.errorMessage = 'Transaction Stopped by Inventory Manager as duplicate exists.';
                    this.showErrorAlert = true;
                    this.disableFinish = false;
                    this.showWarning = true;
                } else {
                    this.showWarning = false;
                    this.showSuccessMessage(result);
                    // Clear the scanned barcode list after processing
                    this.scannedBarcodeList = [];
                    this.disableFinish = false;
                }
            })
            .catch((error) => {
                this.showErrorMessage('Error updating Pulling Materials: ' + error.body.message);
                this.disableFinish = false;
            });
    }
    

    showSuccessMessage(message) {
        // alert('Check Toast message!! ');
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
