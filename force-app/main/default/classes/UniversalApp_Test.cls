@isTest
public class UniversalApp_Test {
    
    @isTest
    static void retrieveCustomMetadata() {

        // Error scenario -- no app found
        Map<String,Object> ret = UniversalApp.retrieveApp('Testing_Not_Found', null);

        System.assertEquals(UniversalApp.NOT_FOUND, ret.get('error'), 'Did not handle the correct error scenario: '+UniversalApp.NOT_FOUND);
        
        // Error scenario -- catch error
        UniversalApp.apps = new List<Universal_App__mdt>();

        ret = UniversalApp.retrieveApp('FindThisApp', null);
        
        // Error scenario -- no sections found
        Universal_App__mdt app = new Universal_App__mdt(DeveloperName='FindThisApp', Object__c='Account');
        UniversalApp.apps = new List<Universal_App__mdt>{app};

        ret = UniversalApp.retrieveApp('FindThisApp', null);

        System.assertEquals(UniversalApp.NO_SECTION, ret.get('error'), 'Did not handle the correct error scenario: '+UniversalApp.NO_SECTION);

        // Success scenario -- returned data
        app = new Universal_App__mdt(DeveloperName='FindThisApp', Object__c='Account');
        UniversalApp.apps = new List<Universal_App__mdt>{app};
        Universal_App_Section__mdt sect = new Universal_App_Section__mdt(DeveloperName='Section', Page__c=1, Order__c=1, Section_Field_Set__c='NOT_PRESENT');
        UniversalApp.sects = new List<Universal_App_Section__mdt>{sect};

        ret = UniversalApp.retrieveApp('FindThisApp', null);

        System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');
        
        // Error scenario -- no object, but with sections
        app = new Universal_App__mdt(DeveloperName='FindThisApp', Object__c='NOT_FOUND____c');
        UniversalApp.apps = new List<Universal_App__mdt>{app};
        
        ret = UniversalApp.retrieveApp('FindThisApp', null);
        
        System.assertEquals(true, ret.containsKey('error'), 'Did not handle the correct error scenario: '+UniversalApp.NO_FIELDSETS);
        
        // Success scenario -- with recordId
		Contact appObj = new Contact(LastName='Test');
        insert appObj;
        
        app = new Universal_App__mdt(DeveloperName='FindThisApp', Object__c='Contact');
        UniversalApp.apps = new List<Universal_App__mdt>{app};
        sect = new Universal_App_Section__mdt(DeveloperName='Section', Page__c=1, Order__c=1, Section_Field_Set__c='NOT_PRESENT', Universal_App__c=app.Id);
        UniversalApp.sects = new List<Universal_App_Section__mdt>{sect};

        ret = UniversalApp.retrieveApp('FindThisApp', appObj.Id);

        System.assertEquals(true, ret.containsKey('data'), 'Did not successfully return the app & section data.');

        // Query for Boolean Test
        String fld = 'LastName';
        String obj = 'Contact';
        String objId = (String) appObj.Id;

        sObject qry = UniversalApp.queryForBoolean(fld, obj , objId);
        system.debug(qry.get(fld) + ' ' + appObj.get(fld));
        System.assertEquals(true, qry.get(fld) == appObj.get(fld), 'Queried field does not equal actual');
        
    }
    
    @isTest
    static void submitSObject() {
        // May or may not succeed -- depends on org Validation Rules / custom code
        // No system asserts here
        Account act = new Account(Name='Test Submit');
        Map<String, Object> ret = new Map<String,Object>();
        ret = UniversalApp.submitApp(act);
        
        // Fail scenario
        Account actNull = null;
        UniversalApp.submitApp(actNull);
    }
}