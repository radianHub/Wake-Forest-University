import { LightningElement, api } from 'lwc';

export default class UnivAppFile extends LightningElement {
	@api field;

	file;

	// # HANDLERS

	// *
	handleChangeFile(event) {
		const file = event.target.files[0];
		this.file = file;

		const fileSelectedEvent = new CustomEvent('fileselected', {
			detail: {
				fieldApiName: this.field.api,
				fieldLabel: this.field.label,
				file: file,
			},
		});
		this.dispatchEvent(fileSelectedEvent);
	}

	// *
	handleClickRemove() {
		this.file = undefined;

		const fileRemovedEvent = new CustomEvent('fileremoved', {
			detail: {
				fieldApiName: this.field.api,
			},
		});
		this.dispatchEvent(fileRemovedEvent);
	}

	// # GETTERS

	// *
	get hasFile() {
		if (this.file !== undefined) {
			return true;
		}
		return false;
	}

	// *
	get fileName() {
		if (this.file !== undefined) {
			return this.field.label + ' - ' + this.file.name;
		}
		return null;
	}
}