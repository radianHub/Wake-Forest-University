import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import getApp from '@salesforce/apex/UniversalApp.retrieveApp';
import submitSObj from '@salesforce/apex/UniversalApp.submitApp';
import getBoolFieldValue from '@salesforce/apex/UniversalApp.queryForBoolean';

export default class UnivApp extends NavigationMixin(LightningElement) {
	// # PUBLIC PROPERTIES
	@api recordId;
	@api appDevName;
	@api canShowRestart;

	// # APP DATA
	appData;
	sections = {};
	fieldsetmap = {};
	page;
	sObj = {}; // sObject {attributes:{type:'API_Name__c'}}, Field_1__c: 'value'}
	originalData;
	pageUrl;
	boolResult;
	truePage;
	falsePage;
	boolObject;
	boolField;
	finished; // After submission - set fields to read-only
	_cssLoaded;

	// # PAGE DATA
	pageIndex = [];
	pageCurrent = 1;
	// * Field and Value Population per Page
	_pageFields; // [AccountId, Custom__c]
	_hasValueIndex = 0;
	_pageHasValue; // [false, true, ...] looks at sObj.hasOwnProperty('Custom__c')
	_valueIndex = 0;
	_pageValues; // [001abc..., value1, ...]

	// # ERROR/SUCCESS MESSAGING
	alert;
	alertType;
	// Alert Messages
	REQUIRED_FIELDS = 'Required fields are missing.';
	POST_FIELDS_JSON_PARSE = 'Please contact your Salesforce Administrator. The JSON ';
	FLOW_SUCCESS = 'Successfully completed the flow.';

	loadingData = true;
	savingData = false;

	// # LIFECYCLE HOOKS

	// * ESTABLISH UNIVERSAL APP DATA
	connectedCallback() {
		this.getApp();
	}

	// * SET PAGE STYLING
	renderedCallback() {
		if (this.appData && !this._cssLoaded && this.appData.CSS__c) {
			this._cssLoaded = true;
			let styleElem = document.createElement('style');
			// eslint-disable-next-line @lwc/lwc/no-inner-html
			styleElem.innerHTML = this.appData.CSS__c;
			this.template.querySelector('.rh_style').appendChild(styleElem);
		}
	}

	// # APEX

	// * GET RECORD ID IF PASSED IN A PARAMETER
	@wire(CurrentPageReference)
	getStateParameters(currentPageReference) {
		const urlValue = currentPageReference.state.c__recordId;
		if (urlValue) {
			// eslint-disable-next-line @lwc/lwc/no-api-reassignments
			this.recordId = urlValue;
		} else {
			// eslint-disable-next-line @lwc/lwc/no-api-reassignments
			this.recordId = null;
		}
	}

	getApp() {
		getApp({ appDevName: this.appDevName, recordId: this.recordId })
			.then((result) => {
				if (result.error) {
					this.alert = result.error;
					this.alertType = 'error';
				} else if (result.data) {
					console.log('data', result.data);
					this.originalData = result.data;
					let cloneData = JSON.parse(JSON.stringify(result.data));
					cloneData.sections.forEach((e) => {
						// eslint-disable-next-line no-prototype-builtins
						if (this.sections.hasOwnProperty(e.Page__c)) {
							this.sections[e.Page__c].push(e);
							this.sections[e.Page__c].sort((a, b) => a.Order__c - b.Order__c);
						} else {
							this.sections[e.Page__c] = [e];
						}
						this.pageIndex.push(e.Page__c);
					});
					this.pageIndex = [...new Set(this.pageIndex.sort())];
					this.pageIndex.sort(function (a, b) {
						return a - b;
					});
					this.appData = cloneData.application;
					this.boolObject = this.appData.Object_with_Boolean__c;
					this.boolField = this.appData.Boolean_Field__c;
					this.truePage = this.appData.Page_Redirect_if_True__c;
					this.falsePage = this.appData.Page_Redirect_if_False__c;
					this.page = this.sections[this.pageIndex[0]];
					this.fieldsetmap = cloneData.fieldsetmap;
				}
				this.loadingData = false;
			})
			.catch((error) => {
				console.log('error', error);

				this.alert = JSON.stringify(error);
				this.alertType = 'error';
				this.loadingData = false;
			});
	}

	// * SUBMITS THE RECORD AND CALLS A PAGE REDIRECT BASED ON A RETURNED BOOLEAN VALUE
	submitSObj() {
		this.savingData = true;

		let urlRecordId;

		for (const fieldApiName of Object.keys(this.files)) {
			this.sObj[fieldApiName] = true;
		}

		submitSObj({
			sObj: this.sObj,
			application: this.appDevName,
			filesString: JSON.stringify(Object.values(this.files)),
		})
			.then((result) => {
				if (result.data) {
					this.alert = this.FLOW_SUCCESS;
					this.alertType = 'success';
					this.finished = true;
					urlRecordId = result.data;
					if (this.boolField != null && this.boolObject != null) {
						getBoolFieldValue({
							fieldName: this.boolField,
							objName: this.boolObject,
							recordId: urlRecordId,
						})
							// eslint-disable-next-line no-shadow
							.then((result) => {
								this.boolResult = result[this.boolField];
								if (this.boolResult && this.truePage != null) {
									this.lwcRedirect(this.truePage);
								} else if (!this.boolResult && this.falsePage != null) {
									this.lwcRedirect(this.falsePage);
								}
							})
							.catch((error) => {
								this.alert = JSON.stringify(error);
								this.alertType = 'error';
							});
					} else if (this.appData?.Page_Redirect__c) {
						this.lwcPageRedirect();
					}
					this.savingData = false;
				} else if (result.error) {
					console.log('error', result.error);
					this.alert = result.error;
					this.alertType = 'error';
					this.savingData = false;
				}
			})
			.catch((error) => {
				console.log('error', error);
				this.alert = error.body.message;
				this.alertType = 'error';
			});
	}

	// # PRIVATE METHODS

	// * REDIRECTS TO DIFFERENT APP/VF_PAGE
	lwcRedirect(/*recordId, */ vfPage) {
		this.pageUrl = window.location.origin + '/apex/' + vfPage /*+ '?id=' + recordId*/;
		window.location.assign(this.pageUrl);
	}

	lwcPageRedirect() {
		console.log('redirecting');
		console.log(this.appData.Page_Redirect__c);
		this[NavigationMixin.Navigate]({
			type: 'comm__namedPage',
			attributes: {
				name: this.appData.Page_Redirect__c,
			},
		});
	}

	// * PREPARES PROPERTIES FOR UPCOMING VALUES
	clearPagePopulation() {
		this._pageFields = null;
		this._hasValueIndex = 0;
		this._pageHasValue = null;
		this._valueIndex = 0;
		this._pageValues = null;
	}

	// * PREPARES THE UPCOMING PAGE
	setPage() {
		this.clearPagePopulation();
		this.page = this.sections[this.pageIndex[this.pageCurrent - 1]];
	}

	// * POPULATES THE PAGE PROPERTIES
	populateProperties() {
		this._pageFields = this.currentPage.reduce((prev, cur) => {
			prev.push(
				...cur.rows.reduce((p, c) => {
					p.push(...c.fields.map((f) => f.api));
					return p;
				}, [])
			);
			return prev;
		}, []);
	}

	// * POPULATES THE PAGE VALUES
	populateValues() {
		this._valueIndex = 0;
		if (!this._pageFields) {
			this.populateFieldNames();
		}
		// eslint-disable-next-line no-prototype-builtins
		this._pageValues = this._pageFields.filter((f) => this.sObj.hasOwnProperty(f)).map((e) => this.sObj[e]);
	}

	// * CHECKS FIELD VALIDATION AND SETS THE SOBJ PROPERTY FOR INSERT
	setObjectFields(alert, alertType) {
		let isValid = [...this.template.querySelectorAll('lightning-input-field')].reduce((validSoFar, inp) => {
			this.sObj[inp.fieldName] = inp.value;
			let valid = inp.reportValidity();

			return validSoFar && valid;
		}, true);

		if (!isValid && alert) {
			this.alert = alert;
			this.alertType = alertType;
		}

		return isValid;
	}

	// * DYNAMICALLY RENDERS A FIELD BASED ON ANOTHER FIELDS VALUE
	dynamicRequire(event) {
		this.setPage();

		const cField = event.target.fieldName;
		const cValue = event.target.value.toString();

		let oIndex;
		let cRequire = {};
		let fieldToRequire = [];
		let fieldToUnrequire = [];
		let fieldIndex = null;
		let fieldSetMap = this.fieldsetmap;
		let keys = Object.keys(fieldSetMap);
		let fieldData;
		let requireFieldMap = new Map();
		let unrequireFieldMap = new Map();

		this.page.forEach((e) => {
			if ('conditionalRequire__c' in e) {
				oIndex = e.Order__c - 1;
				let cJson = JSON.parse(e.conditionalRequire__c);
				cRequire[oIndex] = cJson;
			}
		});

		for (let key in cRequire) {
			if (Object.prototype.hasOwnProperty.call(cRequire, key)) {
				// eslint-disable-next-line no-loop-func
				keys.forEach((fieldSet) => {
					if (fieldSet === this.page[key].Section_Field_Set__c) {
						cRequire[key].Fields.forEach((e) => {
							if (
								cField == e.controllingField &&
								e.controllingValues.includes(cValue) &&
								!e.controllingValues.includes('require')
							) {
								fieldToRequire.push(e.api);
							} else if (
								cField == e.controllingField &&
								e.controllingValues.includes('require') &&
								cValue != ''
							) {
								fieldToRequire.push(e.api);
							}
							if (
								cField == e.controllingField &&
								!e.controllingValues.includes(cValue) &&
								!e.controllingValues.includes('require')
							) {
								fieldToUnrequire.push(e.api);
							} else if (
								cField == e.controllingField &&
								e.controllingValues.includes('require') &&
								cValue == ''
							) {
								fieldToUnrequire.push(e.api);
							}
						});
						fieldSetMap[fieldSet].forEach((section) => {
							if (fieldToRequire.length > 0) {
								fieldToRequire.forEach((actionField) => {
									if (actionField === section.api) {
										fieldIndex = fieldSetMap[fieldSet].indexOf(section);
										fieldData = fieldSetMap[fieldSet][fieldIndex];
										requireFieldMap.set(actionField, fieldData);
									}
								});
							}
							if (fieldToUnrequire.length > 0) {
								fieldToUnrequire.forEach((actionField) => {
									if (actionField === section.api) {
										fieldIndex = fieldSetMap[fieldSet].indexOf(section);
										fieldData = fieldSetMap[fieldSet][fieldIndex];
										unrequireFieldMap.set(actionField, fieldData);
									}
								});
							}
						});
					}
				});
			}
		}

		if (fieldToRequire.length > 0) {
			requireFieldMap.forEach((e) => {
				e.req = true;
			});
		}

		if (fieldToUnrequire.length > 0) {
			unrequireFieldMap.forEach((e) => {
				e.req = false;
			});
		}
	}

	// * DYNAMICALLY RENDERS AN APP SECTION BASED ON A FIELDS VALUE
	dynamicRender(event) {
		this.setPage();
		const field = event.target.fieldName;
		const value = event.target.value;

		let cRender = [];
		let cField;
		let cValue;
		let sectionRender = [];
		let sectionUnrender = [];

		this.page.forEach((e) => {
			if ('conditionalRender__c' in e) {
				let cJson = JSON.parse(e.conditionalRender__c);
				cRender.push(cJson);
			}
		});

		cRender.forEach((e) => {
			e.Fields.forEach((cf) => {
				if (field === cf.controllingField && value === cf.controllingValue) {
					cf.actionSections.forEach((aS) => {
						cField = cf.controllingField;
						cValue = cf.controllingValue;
						sectionRender.push(aS);
					});
				}
				if (field === cf.controllingField && value !== cf.controllingValue) {
					cf.actionSections.forEach((aS) => {
						sectionUnrender.push(aS);
					});
				}
			});
		});

		if (sectionRender.length > 0) {
			sectionRender.forEach((s) => {
				const sectionToRender = this.template.querySelectorAll('.' + s);
				sectionToRender.forEach((a) => {
					// a.style = 'display:block';
					// a.style = true;
				});
				this.page.forEach((p) => {
					if (p.DeveloperName === s) {
						p.DisplayByDefault__c = true;
					}
				});
			});
		}
		if (sectionUnrender.length > 0) {
			sectionUnrender.forEach((s) => {
				const sectionToUnrender = this.template.querySelectorAll('.' + s);
				sectionToUnrender.forEach((a) => {
					// a.style = 'display:none';
					// a.style = false;
				});
				this.page.forEach((p) => {
					if (p.DeveloperName === s) {
						p.DisplayByDefault__c = false;
					}
				});
			});
		}
	}

	// # HANDLERS

	@track files = {};

	handleSelectFile(event) {
		const apiName = event.detail.fieldApiName;
		const fieldLabel = event.detail.fieldLabel;
		const file = event.detail.file;

		let reader = new FileReader();
		let base64;
		let filename = fieldLabel + ' - ' + file.name;

		reader.onload = () => {
			base64 = reader.result.split(',')[1];
			let obj = { ...this.files };
			obj[apiName] = { filename: filename, base64: base64 };
			this.files = obj;
		};
		reader.readAsDataURL(file);
	}

	handleRemoveFile(event) {
		console.log('onfileremoved event');
		const apiName = event.detail.fieldApiName;
		console.log('apiName', apiName);

		console.log('files', Object.keys(this.files));
		// console.log('file', this.files[apiName]);
		delete this.files[apiName];

		console.log('files', Object.keys(this.files));
	}

	// * HANDLES THE DYNAMIC RENDERING AND REQUIRE OF FIELDS
	onChangeHandler(event) {
		this.setPage();
		this.dynamicRender(event);
		this.dynamicRequire(event);
	}

	// * RESETS THE APP
	restart() {
		this.pageCurrent = 1;
		this.setPage();
		this.alert = '';
		this.finished = false;
	}

	// * GOES TO THE PREVIOUS PAGE
	previous() {
		if (!this.finished) {
			this.alert = '';
		}
		this.setObjectFields();
		this.pageCurrent--;
		this.setPage();
	}

	// * GOES TO THE NEXT PAGE
	next() {
		if (!this.finished) {
			this.alert = '';
		}
		if (this.setObjectFields(this.REQUIRED_FIELDS, 'error')) {
			this.pageCurrent++;
			this.setPage();
		}
	}

	// * SETS THE RECORD ID IF AVAILABLE AND HANDLES THE SUBMISSION OF THE RECORD
	finish() {
		this.alert = '';
		if (this.setObjectFields(this.REQUIRED_FIELDS, 'error')) {
			if (this.appData.Post_Submit_Fields__c) {
				let fieldsJSON;
				try {
					fieldsJSON = JSON.parse(this.appData.Post_Submit_Fields__c);
					Object.keys(fieldsJSON).forEach((field) => (this.sObj[field] = fieldsJSON[field]));
				} catch (error) {
					this.alert = error.toString();
					this.alertType = 'error';
				}
			}
			if (!this.alert) {
				this.sObj.sobjectType = this.appData.Object__c;
				if (this.recordId) {
					this.sObj.Id = this.recordId;
				}
				this.submitSObj();
			}
		}
	}

	// *
	handleClickLink(e) {
		console.log('click link');
		const config = {
			type: 'standard__webPage',
			attributes: {
				// url: 'https://www.google.com',
				url: e.currentTarget.dataset.url,
			},
		};
		console.log('config', config);
		this[NavigationMixin.Navigate](config);
	}

	// # GETTERS/SETTERS

	// * DETERMINES WETHER OR NOT TO SHOW RESTART IF APPLICABLE
	get showRestart() {
		return this.canShowRestart && this.finished;
	}

	// * DETERMINES WETHER OR NOT TO SHOW THE PREVIOUS BUTTON
	get showPrevious() {
		return this.pageCurrent > 1;
	}

	// * DETERMINES WETHER OR NOT TO SHOW THE NEXT BUTTON
	get showNext() {
		return this.pageCurrent < this.pageTotal;
	}

	// * DETERMINES WETHER OR NOT TO SHOW THE FINISH BUTTON
	get showFinish() {
		return this.pageCurrent == this.pageTotal;
	}

	// * SETS THE ALERT BANNER COLOR
	get alertClass() {
		return (
			'rh_alert-div slds-scoped-notification slds-media slds-media_center slds-m-bottom_small slds-theme_' +
			this.alertType
		);
	}

	// * SETS THE ALERT CONTAINER
	get alertSpan() {
		return 'slds-icon_container slds-icon-utility-' + this.alertType;
	}

	// * SETS THE ALERT ICON
	get alertIcon() {
		return 'utility:' + this.alertType;
	}

	// * RETURNS THE TOTAL NUMBER OF PAGES
	get pageTotal() {
		return this.pageIndex.length;
	}

	// * DETERMINES IF THE APP IS MORE THAN 1 PAGE
	get multiplePages() {
		return this.pageIndex.length > 1;
	}

	// * RETURNS A FIELDS VALUE
	get value() {
		if (!this._pageValues) {
			this.populateValues();
		}
		return this._pageValues[this._valueIndex++];
	}

	// * DETERMINES IF A FIELD HAS A VALUES
	get hasValue() {
		if (!this._pageFields) {
			this.populateProperties();
		}
		// eslint-disable-next-line no-prototype-builtins
		return this.sObj.hasOwnProperty(this._pageFields[Math.floor(this._hasValueIndex++ / 2)]);
	}

	// * RETURNS THE CURRENT PAGE
	/**
	 * Current page getter
	 * @yields {Array} - Structured objects for LWC HTML iteration
	 * ________________________________
	 *
	 * data: {section custom meta data},
	 * rows: [{
	 *      id: 123,
	 *      fields : [{
	 *          api: AccountId,
	 *          req: true (Boolean),
	 *          label: Contact,
	 *          type: ID (Schema.DisplayType)
	 *          value: Field Value
	 *      }]
	 * }]
	 */
	get currentPage() {
		let curPage = [];
		if (this.page) {
			curPage = [
				...this.page.map((s) => {
					let sect = { data: s };
					if (!s.DisplayByDefault__c) {
						// sect.display = false;
						sect.display = 'display:none';
					}
					if (s.Section_Field_Set__c) {
						sect.columnClass =
							'field-div slds-col slds-size_1-of-1 slds-medium-size_1-of-' +
							s.Section_Field_Columns__c +
							' ' +
							s.DeveloperName;
						let cols = parseInt(s.Section_Field_Columns__c, 10);
						let directionRows = s.Section_Field_Flow__c == 'Left Right';
						let fieldArray = this.fieldsetmap[s.Section_Field_Set__c];
						let rows = Math.ceil(fieldArray.length / cols);
						let fieldRows = []; // {id:iterRow, fields:[{field}, {from}, {fieldArray}]}
						for (let i = 0; i < rows; i++) {
							if (directionRows) {
								let startIndex = i * cols;
								let endIndex = (i + 1) * cols;
								fieldRows.push({
									id: i,
									fields: fieldArray.slice(startIndex, endIndex),
								});
							} else {
								let fieldSlice = [];
								for (let j = 0; j < cols; j++) {
									let rcIndex = i + j * rows;
									if (rcIndex < fieldArray.length) {
										fieldSlice.push(fieldArray[rcIndex]);
									}
								}
								fieldRows.push({
									id: i,
									fields: fieldSlice,
								});
							}
						}
						sect.rows = fieldRows;
					}
					return sect;
				}),
			];
		}
		return curPage;
	}

	get isLoading() {
		if (this.loadingData || this.savingData) {
			return true;
		}
		return false;
	}
}