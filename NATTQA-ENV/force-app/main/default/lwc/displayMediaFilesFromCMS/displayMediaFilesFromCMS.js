import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import retrieveMediaFromCMS from '@salesforce/apex/CMSConnectHelper.retrieveMediaFromCMS';
import Photo_gallery_Associated_site_Channel_Name from '@salesforce/label/c.Photo_gallery_Associated_site_Channel_Name';
import { loadScript } from 'lightning/platformResourceLoader';
import JSZIP from '@salesforce/resourceUrl/jszip';

const IMAGES_PER_PAGE = 30;

export default class DisplayMediaFilesFromCMS extends LightningElement {
    channelName = Photo_gallery_Associated_site_Channel_Name;
    @track results = [];
    @track filteredResults = [];
    @track currentPage = 1;
    @track searchTerm = '';
    @track searchtermtrue = true;
    @track isFilteredResults = false;
    @track previousnext = true;
    @track selectAllChecked = false;
    selectedImageUrls = new Map(); // Store selected image URLs with their titles
    pageSelectionMap = new Map(); // Track selection state for each page

    jszipInitialized = false;

    @wire(retrieveMediaFromCMS, { channelName: '$channelName' })
    wiredData({ error, data }) {
        if (data) {
            let objStr = JSON.parse(data);
            this.results = objStr.map((element, index) => ({
                id: index,
                title: element.title,
                url: element.url,
                titleWithoutDashes: element.title.replace(/-/g, '')
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.results = [];
        }
        console.log('results', this.results);
    }

    async connectedCallback() {
        if (!this.jszipInitialized) {
            try {
                await loadScript(this, JSZIP);
                this.jszipInitialized = true;
                console.log('JSZip loaded successfully.');
            } catch (error) {
                console.error('Failed to load JSZip:', error);
            }
        }
        this.selectedImageUrls = new Map(); // Ensure it's properly initialized
    }

    handleSearchTermChange(event) {
        console.log('fired search');
        this.searchTerm = event.target.value.toLowerCase();
        console.log('fired search', this.searchTerm);

        this.searchtermtrue = false;
        this.isFilteredResults = true;
        this.previousnext = this.searchTerm.trim() === '';
        if (this.searchTerm.trim() !== '') {
            this.filterResults();
            console.log('called');
        } else {
            this.resetFilteredResults();
        }
    }

    filterResults() {
        this.filteredResults = this.results.filter(result =>
            (result.titleWithoutDashes.toLowerCase().startsWith(this.searchTerm) ||
                result.title.toLowerCase().startsWith(this.searchTerm))
        );
        console.log('filtered results search', this.filteredResults);

        if (this.filteredResults.length === 0) {
            this.dispatchToast('No Products found', 'warning');
        }
    }

    dispatchToast(message, variant) {
        const event = new ShowToastEvent({
            title: 'Alert',
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    resetFilteredResults() {
        this.filteredResults = [];
        this.isFilteredResults = false;
        this.searchtermtrue = true;
        this.previousnext = true;
    }
     handleChange(event) {
        this.selectAllChecked = event.target.checked;

        if (this.searchTerm.trim() === '') {
            // If there's no search term, select/deselect all images across all pages
            if (this.selectAllChecked) {
                this.results.forEach(image => {
                    this.selectedImageUrls.set(image.url, image.title);
                });
            } else {
                this.results.forEach(image => {
                    this.selectedImageUrls.delete(image.url);
                });
            }
        } else {
            // If there is a search term, select/deselect only the images on the current page
            if (this.selectAllChecked) {
                this.filteredResults.forEach(image => {
                    this.selectedImageUrls.set(image.url, image.title);
                });
            } else {
                this.filteredResults.forEach(image => {
                    this.selectedImageUrls.delete(image.url);
                });
            }
    }

    // Update the checkboxes on the current page to reflect the "Select All" status
    this.pageSelectionMap.set(this.currentPage, this.selectAllChecked);
    this.updateSelectAllCheckboxState();

    console.log('selectedImageUrls after handleChange:', this.selectedImageUrls);
    }
  
    handleCheckboxChange(event) {
    console.log('Checkbox change event triggered'); // Check if function is called
    const imageUrl = event.target.name;
    const imageTitle = event.target.dataset.title;
    console.log('Checkbox data:', imageUrl, imageTitle); // Log data attributes

    // If the checkbox is checked, add the image to the selected list
    if (event.target.checked) {
        this.selectedImageUrls.set(imageUrl, imageTitle);
    } else {
        // If unchecked, remove the image from the selected list
        this.selectedImageUrls.delete(imageUrl);
    }

    // Determine whether to use filteredResults or paginatedResults based on the search term
    const listToUse = this.isFilteredResults ? this.filteredResults : this.paginatedResults;

    // Check if all items in the current list are selected, and update the "Select All" checkbox accordingly
    this.selectAllChecked = listToUse.every(image => this.selectedImageUrls.has(image.url));

    // Update the "Select All" state for the current page or filtered results
    this.pageSelectionMap.set(this.currentPage, this.selectAllChecked);

    // Update the checkbox state for "Select All"
    const selectAllCheckbox = this.template.querySelector('lightning-input[type="checkbox"][label="Select All"]');
    if (selectAllCheckbox) {
        selectAllCheckbox.checked = this.selectAllChecked;
    }

    console.log('selectedImageUrls after handleCheckboxChange:', this.selectedImageUrls);
}


    async downloadSelectedImages() {
        if (this.selectedImageUrls.size === 0) {
            alert('Please select at least one image to download.');
            return;
        }

        if (!this.jszipInitialized) {
            console.error('JSZip not initialized.');
            return;
        }

        console.log('Starting to download images...');
        const zip = new JSZip();
        const imagePromises = Array.from(this.selectedImageUrls.entries()).map(async ([imageUrl, imageTitle], index) => {
            try {
                const response = await fetch(imageUrl);
                if (!response.ok) {
                    console.error('Failed to fetch image:', imageUrl, response.statusText);
                    return;
                }
                const blob = await response.blob();
                const sanitizedTitle = imageTitle; // Sanitize the title
                //const sanitizedTitle = imageTitle.replace(/[^a-z0-9]/gi, '-').toLowerCase(); // Sanitize the title
                const fileName = `${sanitizedTitle}.jpg`; // Generate a filename for each image
                zip.file(fileName, blob);
                console.log(`Added ${fileName} to ZIP.`);
            } catch (error) {
                console.error('Error fetching image:', imageUrl, error);
            }
        });

        try {
            await Promise.all(imagePromises);
            const zipBlob = await zip.generateAsync({ type: 'blob' });
            const link = document.createElement('a');
            link.href = URL.createObjectURL(zipBlob);
            link.download = 'Photo_Gallery_.zip';
            link.target = '_self';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            console.log('ZIP file created and download triggered.');
        } catch (error) {
            console.error('Error creating ZIP file:', error);
        }
    }

    get paginatedResults() {
        const start = (this.currentPage - 1) * IMAGES_PER_PAGE;
        const end = start + IMAGES_PER_PAGE;
        return this.results.slice(start, end);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateSelectAllCheckboxState();
        }
    }

    handleNext() {
        const totalPages = Math.ceil(this.results.length / IMAGES_PER_PAGE);
        if (this.currentPage < totalPages) {
            this.currentPage++;
            this.updateSelectAllCheckboxState();
        }
    }
    updateSelectAllCheckboxState() {
    let listToUse = this.isFilteredResults ? this.filteredResults : this.paginatedResults;

    // Check if all images (either filtered or paginated results) are selected
    this.selectAllChecked = listToUse.every(image => this.selectedImageUrls.has(image.url));

    // Update the "Select All" checkbox state
    const selectAllCheckbox = this.template.querySelector('lightning-input[type="checkbox"][label="Select All"]');
    if (selectAllCheckbox) {
        selectAllCheckbox.checked = this.selectAllChecked;
    }
}

   
    get totalPages() {
        return Math.ceil(this.results.length / IMAGES_PER_PAGE);
    }

    get showPrevious() {
        return this.currentPage > 1;
    }

    get showNext() {
        return this.currentPage < this.totalPages;
    }

    renderedCallback() {
        const checkboxes = this.template.querySelectorAll('[data-id="checkbox"]');
        checkboxes.forEach(checkbox => {
            checkbox.checked = this.selectedImageUrls.has(checkbox.name);
        });
    }
}