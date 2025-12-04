import { LightningElement, track, wire } from 'lwc';
import getAllProductFamily from "@salesforce/apex/CycleCountController.getAllProductFamily";
import getAllProductTypesMain from "@salesforce/apex/CycleCountController.getAllProductTypesMain";
import getAllProductTypesSub from "@salesforce/apex/CycleCountController.getAllProductTypesSub";
import getAllProductDetails from "@salesforce/apex/CycleCountController.getAllProductDetails";
import getAllLocations from "@salesforce/apex/CycleCountController.getAllLocations";
import saveRecord from "@salesforce/apex/CycleCountController.saveCycleCountDates";
import getAllTechnicians from "@salesforce/apex/CycleCountController.getAllTechnicians";

// Import NavigationMixin to allow navigation from the component
import { NavigationMixin } from 'lightning/navigation';

export default class CreateCycleCountDates extends NavigationMixin(LightningElement) {

    @track isShowModal = true;
    @track locations;
    @track techs;
    @track productFamilies;
    @track productTypeMains;
    @track productTypeSubs;
    @track startDate;
    @track endDate;
    @track products;
    @track locationOptions = [];
    @track technicianOptions = [];
    @track familyOptions = [];
    @track productTypeMainOptions = [];
    @track productTypeSubOptions = [];
    @track productOptions = [];
    @track showProductSelection = false;
    @track timeframeValue = 'Daily';
    selectedLocations = null;
    selectedTechs = null;
    selectedFamily = null;
    selectedMains = null;
    selectedSubs = null;
    selectedProducts = null;
    error;
    predefaultTechs = [];
    predefaultLocations = [];
    predefaultProducts = [];

    get options() {
        return [
            { label: 'Daily', value: 'Daily' },
            { label: 'Weekly', value: 'Weekly' },
            { label: 'Biweekly', value: 'Biweekly' },
            { label: 'Monthly', value: 'Monthly' },
            { label: 'Quarterly', value: 'Quarterly' },
            { label: 'Half Yearly', value: 'Half Yearly' },
            { label: 'Yearly', value: 'Yearly' },
            { label: 'Custom', value: 'Custom' },
        ];
    }

    handleTimeframeChange(event) {
        this.timeframeValue = event.detail.value;
    }

    @wire(getAllLocations)
    wiredLocations({ error, data }) {
        if (data) {
            this.locations = data;
            this.error = undefined;
            const items = [];
            const items2 = [];
            let locationids = '';
            for(let i=0; i<this.locations.length; i++){
                items.push({label: this.locations[i].Name , value: this.locations[i].Id});
                items2.push(this.locations[i].Id);
                locationids += this.locations[i].Id + ',';
            }
            this.selectedLocations = locationids.substring(0,locationids.length-1);
            this.locationOptions.push(...items);
            this.predefaultLocations.push(...items2);
            console.log('Got all product Data = '+JSON.stringify(this.locationOptions));
        } else if (error) {
            this.error = error;
            this.locations = undefined;
            console.log('Error fetching Products' + JSON.stringify(this.error));
        }
    }

    @wire(getAllTechnicians)
    wiredTechnicians({ error, data }) {
        if (data) {
            this.techs = data;
            this.error = undefined;
            const items = [];
            const items2 = [];
            let technicianIds = '';
            for(let i=0; i< this.techs.length; i++){
                items.push({label: this.techs[i].Name , value: this.techs[i].Id});
                items2.push(this.techs[i].Id);
                technicianIds += this.techs[i].Id + ',';
            }

            this.selectedTechs = technicianIds.substring(0,technicianIds.length-1);
            this.technicianOptions.push(...items);
            this.predefaultTechs.push(...items2);
            console.log('Got all technician Data = '+JSON.stringify(this.technicianOptions));
        } else if (error) {
            this.error = error;
            this.technicianOptions = undefined;
            console.log('Error fetching Products' + JSON.stringify(this.error));
        }
    }



    @wire(getAllProductFamily)
    wiredProductFamilies({ error, data }) {
        if (data) {
            this.productFamilies = data;
            this.error = undefined;
            const items = [];
            for(let i=0; i<this.productFamilies.length; i++){
                items.push({label: this.productFamilies[i] , value: this.productFamilies[i]});
            }
            this.familyOptions.push(...items);
            console.log('Got all product Data = '+JSON.stringify(this.familyOptions));
        } else if (error) {
            this.error = error;
            this.productFamilies = undefined;
            console.log('Error fetching Products' + JSON.stringify(this.error));
        }
    }

    @wire(getAllProductTypesMain)
    allProductTypesMain({ error, data }) {
        if (data) {
            this.productTypeMains = data;
            this.error = undefined;
            const items = [];
            for(let i=0; i<this.productTypeMains.length; i++){
                items.push({label: this.productTypeMains[i] , value: this.productTypeMains[i]});
            }
            this.productTypeMainOptions.push(...items);
            console.log('Got all product Data = '+JSON.stringify(this.productTypeMainOptions));
        } else if (error) {
            this.error = error;
            this.productTypeMains = undefined;
            console.log('Error fetching Products' + JSON.stringify(this.error));
        }
    }

    @wire(getAllProductTypesSub)
    allProductTypesSub({ error, data }) {
        if (data) {
            this.productTypeSubs = data;
            this.error = undefined;
            const items = [];
            for(let i=0; i<this.productTypeSubs.length; i++){
                items.push({label: this.productTypeSubs[i] , value: this.productTypeSubs[i]});
            }
            this.productTypeSubOptions.push(...items);
            console.log('Got all product Data = '+JSON.stringify(this.productTypeSubOptions));
        } else if (error) {
            this.error = error;
            this.productTypeSubs = undefined;
            console.log('Error fetching Products' + JSON.stringify(this.error));
        }
    }


    startDateChange(event){
        this.startDate = event.detail.value;
    }

    endDateChange(event){
        this.endDate = event.detail.value;
    }

    handleLocationChange(event){
        this.selectedLocations = event.detail.value;
    }

    handleTechnicianChange(event){
        this.selectedTechs = event.detail.value;
        console.log('Selected techs = '+this.selectedTechs);
    }

    handleFamilyChange(event){
        this.selectedFamily = event.detail.value;
        this.fetchProducts();
    }
    handleProductTypeMainChange(event){
        this.selectedMains = event.detail.value;
        this.fetchProducts();
    }
    handleProductTypeSubChange(event){
        this.selectedSubs = event.detail.value;
        this.fetchProducts();
    }

    handleProductChange(event){
        this.selectedProducts = event.detail.value;
    }

    fetchProducts(){
        if(this.selectedFamily != null || this.selectedMains != null || this.selectedSubs != null){
            getAllProductDetails( {family : JSON.stringify(this.selectedFamily), mains : JSON.stringify(this.selectedMains), subs : JSON.stringify(this.selectedSubs)})
            .then(result => {
                console.log('Apex method called = '+JSON.stringify(result));
                const options = [];
                const selectedOptions = [];
                let productIds = '';
                result.forEach(element => {
                    options.push({ label: element.ProductName, value: element.ID });
                    selectedOptions.push(element.ID)
                    productIds += element.ID + ',';

                });
                this.selectedProducts = productIds.substring(0,productIds.length-1);
                this.productOptions.push(...options);
                this.predefaultProducts.push(...selectedOptions);
            })

            .catch(error => {
                console.log(error.body.message + JSON.stringify(error) );
            });
            this.showProductSelection = true;
        }
        else{
            this.showProductSelection = false;
        }
    }
    hideModalBox() {  
        this.isShowModal = false;
        this[NavigationMixin.Navigate]({
            "type": "standard__objectPage",
            "attributes": {
                "objectApiName": "Cycle_Count_Date__c",
                "actionName": "home"
            }
        });

    }

    handleSave(){
        console.log('called save');
        console.log('Start Date = '+this.startDate);
        console.log('End Date = '+this.endDate);
        console.log('Selected Family = '+this.selectedFamily);
        console.log('Selected Main = '+this.selectedMains);
        console.log('Selected sub = '+this.selectedSubs);
        console.log('Selected Products = '+this.selectedProducts);
        console.log('Selected locations = '+this.selectedLocations);
        console.log('Selected Technicians = '+this.selectedTechs);
        var cycleCountJson = {
            StartDate : this.startDate,
            EndDate : this.endDate,
            Locations : JSON.stringify(this.selectedLocations),
            Products : JSON.stringify(this.selectedProducts),
            ProductFamily : JSON.stringify(this.selectedFamily),
            ProductTypeMain : JSON.stringify(this.selectedMains),
            ProductTypeSub : JSON.stringify(this.selectedSubs),
            Technicians : JSON.stringify(this.selectedTechs),
            TimeFrame : this.timeframeValue
        }
        saveRecord({cycleCountJSON : JSON.stringify(cycleCountJson)})
            .then(result => {
                console.log('Apex method called for Save = '+result);
                if(result === true){
                    console.log('Navigating to object page');
                    this[NavigationMixin.Navigate]({
                        "type": "standard__objectPage",
                        "attributes": {
                            "objectApiName": "Cycle_Count_Date__c",
                            "actionName": "home"
                        }
                    });
                }
                
            })

            .catch(error => {
                console.log('Error while saving record' + error.body.message + JSON.stringify(error) );
            });
    }
}
