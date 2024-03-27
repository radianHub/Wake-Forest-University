import { LightningElement, api, track } from 'lwc';
import UnivAppFileLimit from '@salesforce/label/c.UnivAppFileLimit';

export default class UnivAppFile extends LightningElement {
	@api field;

	file;

	@track files = [];

	labels = {
		UnivAppFileLimit,
	};

	// # HANDLERS

	// *
	handleChangeFile(event) {
		console.log('files', event.target.files);
		this.files = event.target.files;

		const fileSelectedEvent = new CustomEvent('fileselected', {
			detail: {
				fieldApiName: this.field.api,
				fieldLabel: this.field.label,
				files: event.target.files,
			},
		});
		this.dispatchEvent(fileSelectedEvent);
	}

	// *
	handleClickRemove() {
		this.files = [];

		const fileRemovedEvent = new CustomEvent('fileremoved', {
			detail: {
				fieldApiName: this.field.api,
			},
		});
		this.dispatchEvent(fileRemovedEvent);
	}

	// # GETTERS

	// *
	get hasFiles() {
		if (this.files.length > 0) {
			return true;
		}
		return false;
	}
}