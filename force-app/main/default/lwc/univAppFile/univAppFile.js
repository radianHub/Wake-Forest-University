import { LightningElement, api } from 'lwc';

export default class UnivAppFile extends LightningElement {
	@api field;

	file;
	fileName;

	handleChangeFile(event) {
		const file = event.target.files[0];
		this.fileName = this.field.label + ' - ' + file.name;

		const fileSelectedEvent = new CustomEvent('fileselected', {
			detail: {
				fieldApiName: this.field.api,
				fieldLabel: this.field.label,
				file: file,
			},
		});
		this.dispatchEvent(fileSelectedEvent);
	}
}