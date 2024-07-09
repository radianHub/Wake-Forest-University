import { LightningElement, api, track, wire } from 'lwc';
import deleteFiles from '@salesforce/apex/UniversalApp.deleteFiles';
import UnivAppFileLimit from '@salesforce/label/c.UnivAppFileLimit';

export default class UnivAppFile extends LightningElement {
	@api field;

	file;

	@track files = [];
	@track versionIds = [];

	parameterObject;
	// recordsToDelete;
	// @track recordIdsToDelete;

	labels = {
		UnivAppFileLimit
	};

	// # HANDLERS

	handleUploadFinished(event) {
		// Get the list of uploaded files
		const uploadedFiles = event.detail.files;
		console.log('No. of files uploaded : ' + uploadedFiles.length);
		uploadedFiles.forEach((file) => {
			console.log(JSON.stringify(file));
			console.log(file.contentVersionId);
			this.versionIds.push(file.contentVersionId);
		});
		// console.log(this.versionIds);
		this.files = uploadedFiles;

		const filesUploadedEvent = new CustomEvent('filesuploaded', {
			detail: {
				fieldApiName: this.field.api,
				fieldLabel: this.field.label,
				versionIds: this.versionIds
			}
		});
		this.dispatchEvent(filesUploadedEvent);
	}

	handleClickDelete() {
		deleteFiles({ contentVersionIds: this.versionIds })
			.then((result) => {
				console.log(result);
			})
			.catch((error) => {
				console.error(error);
			});
		console.log('Deleted');

		const fileRemovedEvent = new CustomEvent('fileremoved', {
			detail: {
				fieldApiName: this.field.api
			}
		});

		this.dispatchEvent(fileRemovedEvent);
		this.versionIds = [];
		this.files = [];
	}

	// # GETTERS

	// *
	get hasFiles() {
		if (this.files.length > 0) {
			return true;
		}
		return false;
	}

	get label() {
		return this.field.altLabel ?? this.field.label;
	}
}