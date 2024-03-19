@isTest
public class UniversalApp_Test {
	@isTest
	static void retrieveCustomMetadata() {
		// Error scenario -- no app found
		Map<String, Object> ret = UniversalApp.retrieveApp('Testing_Not_Found', null);

		System.assertEquals(
			UniversalApp.NOT_FOUND,
			ret.get('error'),
			'Did not handle the correct error scenario: ' + UniversalApp.NOT_FOUND
		);

		// Error scenario -- catch error
		UniversalApp.apps = new List<Universal_App__mdt>();

		ret = UniversalApp.retrieveApp('FindThisApp', null);

		// Error scenario -- no sections found
		Universal_App__mdt app = new Universal_App__mdt(DeveloperName = 'FindThisApp', Object__c = 'Account');
		UniversalApp.apps = new List<Universal_App__mdt>{ app };

		ret = UniversalApp.retrieveApp('FindThisApp', null);

		System.assertEquals(
			UniversalApp.NO_SECTION,
			ret.get('error'),
			'Did not handle the correct error scenario: ' + UniversalApp.NO_SECTION
		);

		// Success scenario -- returned data
		app = new Universal_App__mdt(DeveloperName = 'FindThisApp', Object__c = 'Account');
		UniversalApp.apps = new List<Universal_App__mdt>{ app };
		Universal_App_Section__mdt sect = new Universal_App_Section__mdt(
			DeveloperName = 'Section',
			Page__c = 1,
			Order__c = 1,
			Section_Field_Set__c = 'NOT_PRESENT'
		);
		UniversalApp.sects = new List<Universal_App_Section__mdt>{ sect };

		ret = UniversalApp.retrieveApp('FindThisApp', null);

		System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');

		// Error scenario -- no object, but with sections
		app = new Universal_App__mdt(DeveloperName = 'FindThisApp', Object__c = 'NOT_FOUND____c');
		UniversalApp.apps = new List<Universal_App__mdt>{ app };

		ret = UniversalApp.retrieveApp('FindThisApp', null);

		System.assertEquals(
			true,
			ret.containsKey('error'),
			'Did not handle the correct error scenario: ' + UniversalApp.NO_FIELDSETS
		);

		// Success scenario -- with recordId
		Contact appObj = new Contact(LastName = 'Test');
		insert appObj;

		app = new Universal_App__mdt(DeveloperName = 'FindThisApp', Object__c = 'Contact');
		UniversalApp.apps = new List<Universal_App__mdt>{ app };
		sect = new Universal_App_Section__mdt(
			DeveloperName = 'Section',
			Page__c = 1,
			Order__c = 1,
			Section_Field_Set__c = 'NOT_PRESENT',
			Universal_App__c = app.Id
		);
		UniversalApp.sects = new List<Universal_App_Section__mdt>{ sect };

		ret = UniversalApp.retrieveApp('FindThisApp', appObj.Id);

		System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');

		// Query for Boolean Test
		String fld = 'LastName';
		String obj = 'Contact';
		String objId = (String) appObj.Id;

		sObject qry = UniversalApp.queryForBoolean(fld, obj, objId);
		system.debug(qry.get(fld) + ' ' + appObj.get(fld));
		System.assertEquals(true, qry.get(fld) == appObj.get(fld), 'Queried field does not equal actual');

		// Success scenario -- without recordId
		app = new Universal_App__mdt(DeveloperName = 'Faculty_Workshop', Object__c = 'Opportunity');
		UniversalApp.apps = new List<Universal_App__mdt>{ app };
		sect = new Universal_App_Section__mdt(
			DeveloperName = 'Faculty_Workshop_Information',
			Page__c = 1,
			Order__c = 1,
			Section_Field_Set__c = 'Faculty_Workshop_Information',
			Universal_App__c = app.Id
		);
		UniversalApp.sects = new List<Universal_App_Section__mdt>{ sect };

		ret = UniversalApp.retrieveApp('Faculty_Workshop', null);

		System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');
	}

	@isTest
	static void submitSObject() {
		// May or may not succeed -- depends on org Validation Rules / custom code
		// No system asserts here
		Account act = new Account(Name = 'Test Submit');
		Map<String, Object> ret = new Map<String, Object>();

		List<UniversalApp.File> files = new List<UniversalApp.File>();

		UniversalApp.File file = new UniversalApp.File();
		file.filename = 'Test file';
		file.base64 = EncodingUtil.base64Encode(Blob.valueOf('data'));

		files.add(file);

		ret = UniversalApp.submitApp(act, null, JSON.serialize(files));

		// Fail scenario
		Account actNull = null;
		UniversalApp.submitApp(actNull, null, null);
	}

	@isTest
	static void submitSObject_Contact() {
		// May or may not succeed -- depends on org Validation Rules / custom code
		// No system asserts here
		Account act = new Account(Name = 'Test Submit');
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);

		Map<String, Object> ret = new Map<String, Object>();

		List<UniversalApp.File> files = new List<UniversalApp.File>();

		UniversalApp.File file = new UniversalApp.File();
		file.filename = 'Test file';
		file.base64 = EncodingUtil.base64Encode(Blob.valueOf('data'));

		files.add(file);

		ret = UniversalApp.submitApp(con, 'Registration', JSON.serialize(files));

		// Fail scenario
		Contact conNull = null;
		UniversalApp.submitApp(conNull, null, null);
	}

	@isTest
	static void submitSObject_Error_ExistingContact() {
		// May or may not succeed -- depends on org Validation Rules / custom code
		// No system asserts here
		Account act = new Account(Name = 'Test Submit');
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);
		insert con;

		Contact con2 = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);

		Map<String, Object> ret = new Map<String, Object>();

		List<UniversalApp.File> files = new List<UniversalApp.File>();

		UniversalApp.File file = new UniversalApp.File();
		file.filename = 'Test file';
		file.base64 = EncodingUtil.base64Encode(Blob.valueOf('data'));

		files.add(file);

		Test.startTest();
		ret = UniversalApp.submitApp(con2, 'Registration', JSON.serialize(files));
		Test.stopTest();

		System.assertEquals(true, ret.containsKey('error'), 'Did not successfully return the app & section data.');
	}

	@isTest
	static void submitSObject_GrantApplication_NewContact() {
		Account act = new Account(Name = 'Test Submit', Community_Registration_Default__c = true);
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);
		insert con;

		Opportunity opp = new Opportunity(AccountId = act.Id);

		Map<String, Object> ret = new Map<String, Object>();

		List<UniversalApp.File> files = new List<UniversalApp.File>();

		UniversalApp.File file = new UniversalApp.File();
		file.filename = 'Test file';
		file.base64 = EncodingUtil.base64Encode(Blob.valueOf('data'));

		files.add(file);

		ret = UniversalApp.submitApp(opp, 'Grant_Application', JSON.serialize(files));
	}

	@isTest
	static void submitSObject_GrantApplication_ExistingContact() {
		Account act = new Account(Name = 'Test Submit', Community_Registration_Default__c = true);
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);
		insert con;

		Opportunity opp = new Opportunity(
			Name = 'Test opp',
			AccountId = act.Id,
			Email_Address__c = 'testcontact@wfu.com.test'
		);

		Map<String, Object> ret = new Map<String, Object>();

		Test.startTest();
		ret = UniversalApp.submitApp(opp, 'Grant_Application', null);
		Test.stopTest();

		System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');
	}

	@isTest
	static void submitSObject_FacultyWorkshop() {
		Account act = new Account(Name = 'Test Submit', Community_Registration_Default__c = true);
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);
		insert con;

		Opportunity opp = new Opportunity(
			Name = 'Test opp',
			AccountId = act.Id,
			Email_Address__c = 'testcontact@wfu.com.test2'
		);

		Map<String, Object> ret = new Map<String, Object>();

		Test.startTest();
		ret = UniversalApp.submitApp(opp, 'Faculty_Workshop', null);
		Test.stopTest();

		System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');
	}

	@isTest
	static void submitSObject_FacultyWorkshop_ExistingContact() {
		Account act = new Account(Name = 'Test Submit', Community_Registration_Default__c = true);
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);
		insert con;

		Opportunity opp = new Opportunity(
			Name = 'Test opp',
			AccountId = act.Id,
			Email_Address__c = 'testcontact@wfu.com.test'
		);

		Map<String, Object> ret = new Map<String, Object>();

		Test.startTest();
		ret = UniversalApp.submitApp(opp, 'Faculty_Workshop', null);
		Test.stopTest();

		System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');
	}

	@isTest
	static void submitSObject_FacultyWorkshop_Error() {
		Account act = new Account(Name = 'Test Submit', Community_Registration_Default__c = true);
		insert act;

		Contact con = new Contact(
			AccountId = act.Id,
			FirstName = 'Test',
			LastName = 'Contact',
			Email = 'testcontact@wfu.com.test'
		);
		insert con;

		Opportunity opp = new Opportunity(AccountId = act.Id, Email_Address__c = 'testcontact@wfu.com.test');

		Map<String, Object> ret = new Map<String, Object>();

		Test.startTest();
		ret = UniversalApp.submitApp(opp, 'Faculty_Workshop', null);
		Test.stopTest();

		System.assertEquals(true, ret.containsKey('error'), 'Did not successfully return the app & section data.');
	}
}