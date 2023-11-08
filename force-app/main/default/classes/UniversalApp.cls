// RadianHub - Developer p.hart
// Apex class for a LWC based universal application dependent on  custom metadata and object field sets

public with sharing class UniversalApp {
	public final static String NOT_FOUND = 'Application \'DeveloperName\' not found in Custom Metadata.';
	public final static String NO_SECTION = 'Application sections were not found in Custom Metadata.';
	public final static String NO_FIELDSETS = 'Field sets were not found for object: {0}.';
	public final static String NULL_FIELDSETS = 'The field set(s) were not found for the following Universal App Sections: {0}.';

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
		Map<String, Schema.SObjectField> fields = ((SObject) Type.forName('Schema', objName)?.newInstance())?.getSObjectType()?.getDescribe()?.fields?.getMap();

		String expr = ' ';
		SObject obj = null;
		for (Integer i = 0 ; i < fields.values().size() - 1 ; i++) {
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
        system.debug(qry);
		obj = Database.query(qry);
        system.debug('Queried Records '+obj.size());

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

					Map<String, Schema.FieldSet> objectFieldSetMap = ((SObject) Type.forName('Schema', application.Object__c)?.newInstance())
						?.getSObjectType()
						?.getDescribe()
						?.fieldSets
						?.getMap();

					if (objectFieldSetMap == null) {
						ret.put('error', String.format(NO_FIELDSETS, new List<Object>{ application.Object__c }));
					} else {
						Map<String, Set<String>> mapfieldset = new Map<String, Set<String>>();

						for (Universal_App_Section__mdt s : sects) {
							String sfs = s.Section_Field_Set__c;
							if (String.isNotBlank(sfs)) {
								if (mapfieldset.containsKey(sfs)) {
									mapfieldset.get(sfs).add(s.DeveloperName);
								} else {
									mapfieldset.put(sfs, new Set<String>{ s.DeveloperName });
								}
							}
						}

						Set<String> nullFieldSets = new Set<String>();
						sObject fieldValues = null;

						if (recordId != null) {
							fieldValues = queryRecord(recordId, application.Object__c);
							system.debug(fieldValues);
						}

						for (String fs : mapfieldset.keySet()) {
							Schema.FieldSet objFieldSet = objectFieldSetMap.get(fs);
							if (objFieldSet != null) {
								List<Schema.FieldSetMember> fields = objFieldSet.getFields();
								List<Object> fieldMembers = new List<Object>();
								for (Schema.FieldSetMember member : fields) {
									Map<String, Object> fieldMember = new Map<String, Object>{
										'api' => member.getFieldPath(),
										'req' => (member.getDBRequired() || member.getRequired()),
										'label' => member.getLabel(),
										'type' => member.getType().name()
									};	
									if (recordId != null) {
										fieldMember.put('value', fieldValues.get(member.getFieldPath()));
									}
									fieldMembers.add(fieldMember);
								}
								fieldsetmap.put(fs, fieldMembers);
							} else {
								nullFieldSets.addAll(new List<String>(mapfieldset.get(fs)));
							}
						}
						system.debug(fieldsetmap);

						if (nullFieldSets.size() > 0) {
							ret.put('error', String.format(NULL_FIELDSETS, new List<Object>{ nullFieldSets }));
						}

						ret.put('data', new Map<String, Object>{ 'application' => application, 'sections' => sects, 'fieldsetmap' => fieldsetmap });
					}
				}
			}
		} catch (Exception e) {
			ret.put('error', e.getTypeName() + ' | ' + e.getMessage() + ' | ' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> submitApp(SObject sObj) {
		Map<String, Object> ret = new Map<String, Object>();

		try {
			upsert sObj;
			ret.put('data', sObj.Id);
		} catch (Exception e) {
			ret.put('error', e.getTypeName() + ' | ' + e.getMessage() + ' | ' + e.getStackTraceString());
		}

		return ret;
	}
}