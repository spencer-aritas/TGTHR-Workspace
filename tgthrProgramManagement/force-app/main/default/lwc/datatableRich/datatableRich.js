import LightningDatatable from 'lightning/datatable';
import richPreview from './richPreview.html';
import { api, track } from 'lwc';

export default class DatatableRich extends LightningDatatable {
  @track _data = [];
  @track _columns = [];
  _dataSetTime = 0; // Track when data was last set for performance monitoring

  @api
  set data(v) {
    // Capture timestamp for performance monitoring
    this._dataSetTime = Date.now();
    
    if (Array.isArray(v)) {
      console.log('DatatableRich received data array of length:', v.length);
      // Create a new array reference to trigger reactivity
      this._data = [...v];
    } else {
      console.warn('DatatableRich received non-array data:', typeof v);
      this._data = [];
    }
  }
  get data() { return this._data; }

  @api
  set columns(v) {
    if (Array.isArray(v)) {
      console.log('DatatableRich received columns array of length:', v.length);
      // Create a new array reference to trigger reactivity
      this._columns = [...v];
    } else {
      console.warn('DatatableRich received non-array columns:', typeof v);
      this._columns = [];
    }
  }
  get columns() { return this._columns; }

  connectedCallback() {
    console.log('DatatableRich connected, data length:', this._data ? this._data.length : 0);
    super.connectedCallback();
  }

  renderedCallback() {
    if (this._dataSetTime > 0) {
      // Log render performance metrics
      const renderTime = Date.now() - this._dataSetTime;
      console.log(`DatatableRich rendered in ${renderTime}ms, data length: ${this._data ? this._data.length : 0}`);
      // Reset the timer to avoid duplicate logs on re-renders
      this._dataSetTime = 0;
    }
  }

  // Define custom rich text hover cell type
  static customTypes = {
    richHover: {
      template: richPreview,
      typeAttributes: ['value'], // full HTML
      standardCellLayout: true // Use standard layout for better performance
    }
  };
}
