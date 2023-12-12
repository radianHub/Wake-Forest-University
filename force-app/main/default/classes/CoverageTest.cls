@isTest
public with sharing class CoverageTest {
	@isTest
	private static void addCoverage() {
		Test.startTest();
		Coverage.addCoverage();
		Test.stopTest();
	}
}