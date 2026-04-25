public class OpportunityTriggerHandler extends TriggerHandler {

    // Prevents recursion when afterUpdate writes back to Opportunity.Description
    private static Boolean isRunning = false;

    protected override void beforeInsert() {
        setType((List<Opportunity>) Trigger.new);
    }

    protected override void afterInsert() {
        insertTask((List<Opportunity>) Trigger.new);
    }

    protected override void beforeUpdate() {
        validateAmount((List<Opportunity>) Trigger.new);
        setPrimaryContact((List<Opportunity>) Trigger.new);
    }

    protected override void afterUpdate() {
        updateDescriptionFromStage((List<Opportunity>) Trigger.new);
    }

    protected override void beforeDelete() {
        validateCloseOpportunity((List<Opportunity>) Trigger.old);
    }

    protected override void afterDelete() {
        notifyOwnersOpportunityDeleted((List<Opportunity>) Trigger.old);
    }

    protected override void afterUndelete() {
        assignPrimaryContact(Trigger.newMap);
    }

    // Set default Type to 'New Customer' on insert
    private static void setType(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    // Create a follow-up Task for each newly inserted Opportunity
    private static void insertTask(List<Opportunity> opps) {
        List<Task> tasks = new List<Task>();
        for (Opportunity opp : opps) {
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tasks.add(tsk);
        }
        insert tasks;
    }

    // Validate Amount > 5000 on update
    private static void validateAmount(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.Amount != null && opp.Amount < 5000) {
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }

    // Set Primary Contact to the Account's CEO contact on update
    private static void setPrimaryContact(List<Opportunity> opps) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opps) {
            accountIds.add(opp.AccountId);
        }

        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();
        for (Contact con : [SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]) {
            if (!accountIdToContact.containsKey(con.AccountId)) {
                accountIdToContact.put(con.AccountId, con);
            }
        }

        for (Opportunity opp : opps) {
            if (opp.Primary_Contact__c == null && accountIdToContact.containsKey(opp.AccountId)) {
                opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
            }
        }
    }

    // Append stage change entry to Description on update; static flag stops recursion
    private static void updateDescriptionFromStage(List<Opportunity> opps) {
        if (isRunning) {
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : opps) {
            if (opp.StageName != null) {
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Description = (opp.Description != null ? opp.Description : '')
                    + '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                oppsToUpdate.add(oppToUpdate);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            isRunning = true;
            update oppsToUpdate;
            isRunning = false;
        }
    }

    // Prevent deletion of any closed Opportunity
    private static void validateCloseOpportunity(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.IsClosed) {
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    // Notify each Opportunity owner by email when their Opportunity is deleted
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : opps) {
            ownerIds.add(opp.OwnerId);
        }

        Map<Id, User> owners = new Map<Id, User>([SELECT Id, Email FROM User WHERE Id IN :ownerIds]);

        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { owners.get(opp.OwnerId).Email });
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name + ' has been deleted.');
            mails.add(mail);
        }

        try {
            Messaging.sendEmail(mails);
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
    }

    // Assign the VP Sales contact as Primary Contact on undelete when none is set
    private static void assignPrimaryContact(Map<Id, SObject> oppNewMap) {
        Set<Id> accountIds = new Set<Id>();
        for (SObject obj : oppNewMap.values()) {
            Opportunity opp = (Opportunity) obj;
            if (opp.Primary_Contact__c == null) {
                accountIds.add(opp.AccountId);
            }
        }

        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();
        for (Contact con : [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId IN :accountIds]) {
            if (!accountIdToContact.containsKey(con.AccountId)) {
                accountIdToContact.put(con.AccountId, con);
            }
        }

        Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();
        for (SObject obj : oppNewMap.values()) {
            Opportunity opp = (Opportunity) obj;
            if (opp.Primary_Contact__c == null && accountIdToContact.containsKey(opp.AccountId)) {
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                oppsToUpdate.put(opp.Id, oppToUpdate);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate.values();
        }
    }
}
