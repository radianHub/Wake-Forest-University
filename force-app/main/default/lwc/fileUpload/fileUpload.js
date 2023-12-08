/* eslint-disable eqeqeq */
/* eslint-disable no-useless-concat */
/* eslint-disable vars-on-top */
/* eslint-disable @lwc/lwc/no-api-reassignments */
/* eslint-disable no-unused-vars */
import { LightningElement, api } from "lwc";
import saveTheChunkFile from "@salesforce/apex/FileUploadService.saveTheChunkFile";
import requiredFiles from "@salesforce/apex/FileUploadService.getRequiredFilesForUpload";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
const MAX_FILE_SIZE = 4500000;
const CHUNK_SIZE = 750000;

export default class FileUpload extends LightningElement {
	@api recordId;
	@api fileTypes = [];
	@api items = [];
	fileName = "";
	filesUploaded = [];
	isLoading = false;
	fileSize;
	alert;
	alertType;
	fileUploadedSuccess = false;
	descriptionValue;
	fileTypeValue;
	FLOW_SUCCESS = "Your files have uploaded successfully.";

	get options() {
		return [
			{ label: "I9 Verification", value: "i9" },
			{ label: "Pay Stub", value: "payStub" },
			{ label: "Social Security Card", value: "ssCard" }
		];
	}
	get alertClass() {
		return "rh_alert-div slds-scoped-notification slds-media slds-media_center slds-var-m-bottom_small slds-theme_" + this.alertType;
	}
	get alertSpan() {
		return "slds-icon_container slds-icon-utility-" + this.alertType;
	}
	get alertIcon() {
		return "utility:" + this.alertType;
	}
	connectedCallback() {
		console.log("this.fileTypes " + this.fileTypes);
		for (let i = 0; i < this.fileTypes.length; i++) {
			this.items = [...this.items, { value: this.fileTypes[i], label: this.fileTypes[i] }];
		}
		console.log("this.items " + JSON.stringify(this.items));
	}

	saveFile() {
		console.log("saveFile");
		// TODO: Extend to save multiple files
		console.log("files being uploaded: " + this.filesUploaded);
		// TODO: Create new method for the below code. loop through files and pass them in
		var fileCon = this.filesUploaded[0];
		this.fileSize = this.formatBytes(fileCon.size, 2);
		if (fileCon.size > MAX_FILE_SIZE) {
			let message = "File size cannot exceed " + MAX_FILE_SIZE + " bytes.\n" + "Selected file size: " + fileCon.size;
			this.dispatchEvent(
				new ShowToastEvent({
					title: "Error",
					message: message,
					variant: "error"
				})
			);
			return;
		}
		var reader = new FileReader();
		var self = this;
		reader.onload = function () {
			var fileContents = reader.result;
			var base64Mark = "base64,";
			console.log("base64.length: " + base64Mark.length);
			var dataStart = fileContents.indexOf(base64Mark) + base64Mark.length;
			console.log("fileContents.indexOf(base64Mark): " + fileContents.indexOf(base64Mark));
			console.log("dataStart: " + dataStart);
			fileContents = fileContents.substring(dataStart);
			console.log("fileCon: " + fileCon);
			console.log("fileContents: " + fileContents);
			self.upload(fileCon, fileContents);
		};
		reader.readAsDataURL(fileCon);
	}

	upload(file, fileContents) {
		console.log("upload");
		var fromPos = 0;
		var toPos = Math.min(fileContents.length, fromPos + CHUNK_SIZE);
		console.log("passing to UploadChunk");
		this.uploadChunk(file, fileContents, fromPos, toPos, "");
	}

	uploadChunk(file, fileContents, fromPos, toPos, attachId) {
		console.log("uploadChunk");
		console.log("file: " + file);
		console.log("fileContents: " + fileContents);
		console.log("fromPos: " + fromPos);
		console.log("toPos: " + toPos);
		console.log("attachId: " + attachId);
		console.log("saving chunk file");
		this.isLoading = true;
		var chunk = fileContents.substring(fromPos, toPos);

		saveTheChunkFile({
			parentId: this.recordId,
			fileName: file.name,
			base64Data: encodeURIComponent(chunk),
			contentType: file.type,
			fileId: attachId,
			fileType: this.fileTypeValue,
			description: this.descriptionValue
		})
			.then((result) => {
				attachId = result;
				fromPos = toPos;
				toPos = Math.min(fileContents.length, fromPos + CHUNK_SIZE);
				if (fromPos < toPos) {
					this.uploadChunk(file, fileContents, fromPos, toPos, attachId);
				} else {
					console.log("success toast");
					/*
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success!',
                        message: 'File Upload Success',
                        variant: 'success'
                    }));

                     */
					this.buttonVariant();
					/*
                    this.alert = this.FLOW_SUCCESS;
                    this.alertType = 'success';
                     */
					this.isLoading = false;
				}
			})
			.catch((error) => {
				console.error("Error: ", error);
			})
			.finally(() => {});
	}
	buttonVariant() {
		//this.template.querySelector('lightning-button').variant='neutral';
		this.template.querySelector("lightning-button").label = "Success!";
		this.template.querySelector("lightning-button").disabled = true;
	}

	formatBytes(bytes, decimals) {
		console.log("formatBytes");
		if (bytes == 0) return "0 Bytes";
		var k = 1024,
			dm = decimals || 2,
			sizes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"],
			i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
	}
	handleFilesChange(event) {
		console.log("handleFilesChange");
		this.alert = "";
		this.alertType = "";
		if (event.target.files.length > 0) {
			this.filesUploaded = event.target.files;
			console.log(this.filesUploaded);
			this.fileName = event.target.files[0].name;
		}
	}
	handleInputChange(event) {
		this.descriptionValue = event.detail.value;
	}
	handleChange(event) {
		this.fileTypeValue = event.detail.value;
	}
}