// RadianHub - Developer p.hart
// Apex class for a LWC based universal application dependent on  custom metadata and object field sets

public without sharing class UniversalApp {
	public final static String NOT_FOUND = 'Application \'DeveloperName\' not found in Custom Metadata.';
	public final static String NO_SECTION = 'Application sections were not found in Custom Metadata.';
	public final static String NO_FIELDSETS = 'Field sets were not found for object: {0}.';
	public final static String NULL_FIELDSETS = 'The field set(s) were not found for the following Universal App Sections: {0}.';
	public final static String NULL_FIELDSET = 'The field set {0} was not found on {1}.';

	public static Universal_App__mdt[] apps;
	public static Universal_App_Section__mdt[] sects;

	// Method   - queryApps
	// Descr.   - Segregated (for testing) mdt query which updates the class static variable "apps"
	// Input    - String DeveloperName of CustomMetadata 'Universal App'
	private static void queryApps(String appDevName) {
		apps = [
			SELECT
				Id,
				CSS__c,
				DeveloperName,
				Logo_URL__c,
				MasterLabel,
				Object__c,
				Post_Submit_Fields__c,
				Page_Redirect__c,
				Object_with_Boolean__c,
				Boolean_Field__c,
				Page_Redirect_if_True__c,
				Page_Redirect_if_False__c
			FROM Universal_App__mdt
			WHERE DeveloperName = :appDevName
		];
	}

	// Method   - querySects
	// Descr.   - Segregated (for testing) mdt query which updates the class static variable "sects"
	// Input    - Id of 'Universal App'
	private static void querySects(String appId) {
		sects = [
			SELECT
				Id,
				DeveloperName,
				MasterLabel,
				Order__c,
				Page__c,
				Section_Body__c,
				Section_Field_Set__c,
				Section_Field_Columns__c,
				Section_Field_Flow__c,
				Section_Header__c,
				conditionalRequire__c,
				conditionalRender__c,
				DisplayByDefault__c
			FROM Universal_App_Section__mdt
			WHERE Universal_App__c = :appId
		];
	}

	/**
	 * @description : Query all fields in a sObject and return the results.
	 * @author Zachary Csotya | 06/28/2022
	 * @param Id rId
	 * @param String objName
	 * @return sObject
	 **/
	public static sObject queryRecord(Id rId, String objName) {
		Map<String, Schema.SObjectField> fields = ((SObject) Type.forName('Schema', objName)?.newInstance())
			?.getSObjectType()
			?.getDescribe()
			?.fields
			?.getMap();

		String expr = ' ';
		SObject obj = null;
		for (Integer i = 0; i < fields.values().size() - 1; i++) {
			expr += fields.values()[i] + ', ';
		}
		expr += fields.values()[fields.values().size() - 1];
		String qry = 'SELECT' + expr + ' FROM ' + objName + ' WHERE Id = ' + '\'' + rId + '\'';
		obj = Database.query(qry);

		return obj;
	}

	/**
	 * @description : Query all fields in a sObject and return the results.
	 * @author Zachary Csotya | 08/02/2022
	 * @param String fieldName
	 * @param String objName
	 * @param String recordId
	 * @return sObject
	 **/
	@AuraEnabled
	public static sObject queryForBoolean(String fieldName, String objName, String recordId) {
		List<SObject> obj = null;
		String qry = 'SELECT ' + fieldName + ' FROM ' + objName + ' WHERE Id = ' + '\'' + recordId + '\'';
		obj = Database.query(qry);

		if (obj.size() == 1) {
			return obj[0];
		} else {
			return null;
		}
	}

	// Method   - retrieveApp
	// Descr.   - Aura enabled (LWC c-univ-app) method for returning map of Universal Application and field sets
	// Input    - String DeveloperName of CustomMetadata 'Universal App'
	// Output   - Map<String, Object> {'data' -> [{api -> fieldAPI__c, options...}, ...], 'error' -> 'String'}
	@AuraEnabled(cacheable=true)
	public static Map<String, Object> retrieveApp(String appDevName, Id recordId) {
		Map<String, Object> ret = new Map<String, Object>();

		try {
			// Query for application, prepopulate in testing
			if (apps == null) {
				queryApps(appDevName);
			}

			if (apps == null || apps.size() != 1) {
				ret.put('error', NOT_FOUND);
			} else {
				Universal_App__mdt application = apps[0];

				// Query for sections, prepopulate in testing
				if (sects == null) {
					querySects(application.Id);
				}

				if (sects == null || sects.size() == 0) {
					ret.put('error', NO_SECTION);
				} else {
					Map<String, List<Object>> fieldsetmap = new Map<String, List<Object>>();

					Map<String, Schema.FieldSet> objectFieldSetMap = ((SObject) Type.forName(
								'Schema',
								application.Object__c
							)
							?.newInstance())
						?.getSObjectType()
						?.getDescribe()
						?.fieldSets
						?.getMap();

					if (objectFieldSetMap == null) {
						ret.put('error', String.format(NO_FIELDSETS, new List<Object>{ application.Object__c }));
					} else {
						Map<String, Set<String>> mapfieldset = new Map<String, Set<String>>();
						// Map<String, Map<String, String>> mapFieldSetting = new Map<String, Map<String, String>>();
						Map<String, Map<String, Universal_App_Field_Setting__mdt>> mapFieldSetting = new Map<String, Map<String, Universal_App_Field_Setting__mdt>>();

						for (Universal_App_Section__mdt section : sects) {
							String sectionFieldSet = section.Section_Field_Set__c;
							if (String.isNotBlank(sectionFieldSet)) {
								for (Universal_App_Field_Setting__mdt fieldSetting : queryFieldSettings()) {
									if (fieldSetting.Universal_App_Section__c == section.Id) {
										if (mapFieldSetting.containsKey(sectionFieldSet)) {
											if (
												!mapFieldSetting.get(sectionFieldSet)
													.containsKey(fieldSetting.Field_Name__c)
											) {
												mapFieldSetting.get(sectionFieldSet)
													.put(
														fieldSetting.Field_Name__c,
														// fieldSetting.Expected_Field_Label__c
														fieldSetting
													);
											}
										} else {
											mapFieldSetting.put(
												sectionFieldSet,
												new Map<String, Universal_App_Field_Setting__mdt>{
													// fieldSetting.Field_Name__c => fieldSetting.Expected_Field_Label__c
													fieldSetting.Field_Name__c => fieldSetting
												}
											);
										}
									}
								}

								if (mapfieldset.containsKey(sectionFieldSet)) {
									mapfieldset.get(sectionFieldSet).add(section.DeveloperName);
								} else {
									mapfieldset.put(sectionFieldSet, new Set<String>{ section.DeveloperName });
								}
							}
						}

						Set<String> nullFieldSets = new Set<String>();
						sObject fieldValues = null;

						if (recordId != null) {
							fieldValues = queryRecord(recordId, application.Object__c);
						}

						for (String fieldSet : mapfieldset.keySet()) {
							Schema.FieldSet objFieldSet = objectFieldSetMap.get(fieldSet);
							if (objFieldSet != null) {
								List<Schema.FieldSetMember> fields = objFieldSet.getFields();
								List<Object> fieldMembers = new List<Object>();
								for (Schema.FieldSetMember member : fields) {
									String altLabel;
									Boolean hasAltLabel = false;
									Boolean isFile = false;
									String acceptedFileTypes = '';
									Boolean isLink = false;
									String linkURL = '';
									String linkTarget = '_blank';

									if (mapFieldSetting?.containsKey(fieldSet)) {
										if (mapFieldSetting.get(fieldSet)?.containsKey(member.getFieldPath())) {
											Universal_App_Field_Setting__mdt fieldSetting = mapFieldSetting.get(
													fieldSet
												)
												.get(member.getFieldPath());

											hasAltLabel = true;
											altLabel = fieldSetting.Expected_Field_Label__c;
											isFile = fieldSetting.Type__c == 'File' ? true : false;
											isLink = fieldSetting.Type__c == 'Link' ? true : false;
											acceptedFileTypes = fieldsetting.Accepted_File_Types__c;
											linkURL = fieldSetting.URL__c;
											linkTarget = fieldSetting.Target__c;
										}
									}

									Map<String, Object> fieldMember = new Map<String, Object>{
										'api' => member.getFieldPath(),
										'req' => (member.getDBRequired() || member.getRequired()),
										'label' => member.getLabel(),
										'type' => member.getType().name(),
										'hasAltLabel' => hasAltLabel,
										'altLabel' => altLabel,
										'isBool' => member.getType().name() == 'BOOLEAN' ? true : false,
										'isFile' => isFile,
										'acceptedFileTypes' => acceptedFileTypes,
										'isLink' => isLink,
										'linkURL' => linkURL,
										'linkTarget' => linkTarget
									};

									if (recordId != null) {
										fieldMember.put('value', fieldValues.get(member.getFieldPath()));
									}
									fieldMembers.add(fieldMember);
								}
								fieldsetmap.put(fieldSet, fieldMembers);
							} else {
								nullFieldSets.addAll(new List<String>(mapfieldset.get(fieldSet)));
							}
						}

						if (nullFieldSets.size() > 0) {
							ret.put('error', String.format(NULL_FIELDSETS, new List<Object>{ nullFieldSets }));
						}

						ret.put(
							'data',
							new Map<String, Object>{
								'application' => application,
								'sections' => sects,
								'fieldsetmap' => fieldsetmap
							}
						);
					}
				}
			}
		} catch (Exception e) {
			ret.put('error', e.getTypeName() + ' | ' + e.getMessage() + ' | ' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> submitApp(SObject sObj, String application, List<Id> cvIds) {
		Map<String, Object> ret = new Map<String, Object>();

		Id sObjectId;

		try {
			switch on application {
				when 'Registration' {
					Contact newCommunityMember = (Contact) sObj;

					List<Contact> existingCommunityMember = [
						SELECT Id
						FROM Contact
						WHERE Email = :newCommunityMember.Email
					];

					if (existingCommunityMember.size() > 0) {
						throw new CustomException(
							'A community member already exists under this email address. Please contact the Grants and Contracts Manager at ECI@wfu.edu to make changes to your file or with any questions.'
						);
					}

					Database.UpsertResult result = Database.upsert(newCommunityMember, false);
					if (!result.isSuccess()) {
						throw new CustomException(result.getErrors()[0].getMessage());
					}
					ret.put('data', result.Id);

					sObjectId = result.Id;
				}
				when 'Grant_Application' {
					Opportunity newGrantApplication = (Opportunity) sObj;

					List<Contact> existingCommunityMember = [
						SELECT Id, Email, AccountId
						FROM Contact
						WHERE Email = :newGrantApplication.Email_Address__c
					];

					if (existingCommunityMember.size() == 0) {
						newGrantApplication.AccountId = [
							SELECT Id
							FROM Account
							WHERE Community_Registration_Default__c = TRUE
							LIMIT 1
						][0]
						.Id;
					} else {
						newGrantApplication.AccountId = existingCommunityMember[0].AccountId;
						newGrantApplication.Community_Member__c = existingCommunityMember[0].Id;
					}

					newGrantApplication.StageName = 'Application Received';
					newGrantApplication.CloseDate = Date.today();
					newGrantApplication.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
						.get('Grant_Application')
						.getRecordTypeId();

					Database.UpsertResult result = Database.upsert(newGrantApplication, false);
					if (!result.isSuccess()) {
						throw new CustomException(result.getErrors()[0].getMessage());
					}

					ret.put('data', result.Id);

					sObjectId = result.Id;
				}
				when 'Faculty_Workshop' {
					Opportunity workshopSubmission = (Opportunity) sObj;

					List<Contact> existingCommunityMember = [
						SELECT Id, Email, AccountId
						FROM Contact
						WHERE Email = :workshopSubmission.Email_Address__c
					];

					if (existingCommunityMember.size() == 0) {
						workshopSubmission.AccountId = [
							SELECT Id
							FROM Account
							WHERE Community_Registration_Default__c = TRUE
							LIMIT 1
						][0]
						.Id;
					} else {
						workshopSubmission.AccountId = existingCommunityMember[0].AccountId;
						workshopSubmission.Community_Member__c = existingCommunityMember[0].Id;
					}

					workshopSubmission.Name = workshopSubmission.First_Name__c + ' ' + workshopSubmission.Last_Name__c;
					workshopSubmission.StageName = 'Application Received';
					workshopSubmission.CloseDate = Date.today();
					workshopSubmission.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
						.get('Workshop_Application')
						.getRecordTypeId();

					Database.UpsertResult result = Database.upsert(workshopSubmission, false);
					if (!result.isSuccess()) {
						throw new CustomException(result.getErrors()[0].getMessage());
					}

					ret.put('data', result.Id);

					sObjectId = result.Id;
				}
				when 'Conference_Workshop' {
					Opportunity workshopSubmission = (Opportunity) sObj;

					List<Contact> existingCommunityMember = [
						SELECT Id, Email, AccountId
						FROM Contact
						WHERE Email = :workshopSubmission.Email_Address__c
					];

					if (existingCommunityMember.size() == 0) {
						workshopSubmission.AccountId = [
							SELECT Id
							FROM Account
							WHERE Community_Registration_Default__c = TRUE
							LIMIT 1
						][0]
						.Id;
					} else {
						workshopSubmission.AccountId = existingCommunityMember[0].AccountId;
						workshopSubmission.Community_Member__c = existingCommunityMember[0].Id;
					}

					// workshopSubmission.Name = workshopSubmission.First_Name__c + ' ' + workshopSubmission.Last_Name__c;
					workshopSubmission.StageName = 'Application Received';
					workshopSubmission.CloseDate = Date.today();
					workshopSubmission.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
						.get('Workshop_Application')
						.getRecordTypeId();

					Database.UpsertResult result = Database.upsert(workshopSubmission, false);
					if (!result.isSuccess()) {
						throw new CustomException(result.getErrors()[0].getMessage());
					}

					ret.put('data', result.Id);

					sObjectId = result.Id;
				}
				when else {
					Database.UpsertResult result = Database.upsert(sObj, false);
					if (!result.isSuccess()) {
						throw new CustomException(result.getErrors()[0].getMessage());
					}

					ret.put('data', result.Id);
					sObjectId = result.Id;
				}
			}
			if (cvIds.size() > 0) {
			// if (cdIdsString != null) {
				// List<Id> cdIds = (List<Id>) JSON.deserialize(cdIdsString, List<Id>.class);
			// 	List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
			// 	for(Id cvId : cvIds) {
			// 		cdls.add(createContentLink(cvId, sObjectId));
			// 	}

			// 	insert cdls;

				createContentDocumentLinks(cvIds, sObjectId);
			}

		} catch (CustomException customException) {
			ret.put('error', customException.getMessage());
		} catch (Exception e) {
			System.debug(e);
			System.debug(e.getTypeName() + ' | ' + e.getMessage() + ' | ' + e.getStackTraceString());
			ret.put('error', e.getMessage());
		}

		return ret;
	}

	private static void createContentDocumentLinks(List<Id> cvIds, Id recordId){
		List<Id> cdIds = new List<Id>();
		List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();

		if(cvIds == null || recordId == null) {
			return;
		}

		for(ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds]) {
			cdIds.add(cv.ContentDocumentId);
		}

		for(Id cdId : cdIds) {
			cdls.add(createContentLink(cdId, recordId));
		}

		if(cdls.size() > 0){
			insert cdls;
		}
	}

	private static ContentDocumentLink createContentLink(Id contentDocumentId, Id recordId) {
		ContentDocumentLink cdl = new ContentDocumentLink();
		cdl.ContentDocumentId = contentDocumentId;
		cdl.LinkedEntityId = recordId;
		cdl.ShareType = 'V';
		return cdl;
	}

	@AuraEnabled
	public static void deleteFiles(List<Id> contentVersionIds){
		List<ContentDocument> cdsToDelete = new List<ContentDocument>();
		try {
			for(ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :contentVersionIds]){
				cdsToDelete.add(new ContentDocument(Id = cv.ContentDocumentId));
			}

			delete cdsToDelete;
			
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	public class CustomException extends Exception {
	}

	private static List<Universal_App_Field_Setting__mdt> queryFieldSettings() {
		return [
			SELECT
				Id,
				DeveloperName,
				MasterLabel,
				Expected_Field_Label__c,
				Field_Name__c,
				Universal_App_Section__c,
				Type__c,
				Accepted_File_Types__c,
				URL__c,
				Target__c
			FROM Universal_App_Field_Setting__mdt
		];
	}

	// @AuraEnabled
	// public static void submitChildObjects(List<childRecordsWrapper> childObjs, Id parentId) {
	// 	try {
	// 		List<SObject> records = new List<SObject>();
	// 		for (childRecordsWrapper wrapper : childObjs) {
	// 			for (SObject record : wrapper.records) {
	// 				record.put(wrapper.parentField, parentId);
	// 			}
	// 			records.addAll(wrapper.records);
	// 		}
	// 		insert records;
	// 	} catch (Exception e) {
	// 		throw new AuraHandledException(e.getMessage());
	// 	}
	// }

	// @AuraEnabled
	// public static Map<String, Object> getChildObjectFields(String ObjectName, String FieldSetName) {
	// 	Map<String, Object> ret = new Map<String, Object>();

	// 	Map<String, List<Object>> fieldsetmap = new Map<String, List<Object>>();

	// 	Schema.FieldSet objFieldSet = ((SObject) Type.forName('Schema', ObjectName)?.newInstance())
	// 		?.getSObjectType()
	// 		?.getDescribe()
	// 		?.fieldSets
	// 		?.getMap()
	// 		?.get(FieldSetName);

	// 	if (objFieldSet == null) {
	// 		ret.put('error', String.format(NULL_FIELDSET, new List<Object>{ FieldSetName, ObjectName }));
	// 	} else {
	// 		Map<String, Set<String>> mapfieldset = new Map<String, Set<String>>();
	// 		Map<String, Map<String, String>> mapFieldSetting = new Map<String, Map<String, String>>();

	// 		Set<String> nullFieldSets = new Set<String>();
	// 		sObject fieldValues = null;

	// 		List<Schema.FieldSetMember> fields = objFieldSet.getFields();
	// 		List<Object> fieldMembers = new List<Object>();
	// 		for (Schema.FieldSetMember member : fields) {
	// 			String altLabel;
	// 			Boolean hasAltLabel = false;

	// 			if (mapFieldSetting?.containsKey(FieldSetName)) {
	// 				if (mapFieldSetting.get(FieldSetName)?.containsKey(member.getFieldPath())) {
	// 					hasAltLabel = true;
	// 					altLabel = mapFieldSetting.get(FieldSetName).get(member.getFieldPath());
	// 				}
	// 			}

	// 			Map<String, Object> fieldMember = new Map<String, Object>{
	// 				'api' => member.getFieldPath(),
	// 				'req' => (member.getDBRequired() || member.getRequired()),
	// 				'label' => member.getLabel(),
	// 				'type' => member.getType().name(),
	// 				'hasAltLabel' => hasAltLabel,
	// 				'altLabel' => altLabel
	// 			};

	// 			fieldMembers.add(fieldMember);
	// 		}

	// 		ret.put('fielddata', fieldMembers);
	// 	}

	// 	return ret;
	// }

	// public class childRecordsWrapper {
	// 	@AuraEnabled
	// 	public String objectName { get; set; }
	// 	@AuraEnabled
	// 	public String parentField { get; set; }
	// 	@AuraEnabled
	// 	public List<SObject> records { get; set; }
	// }
}