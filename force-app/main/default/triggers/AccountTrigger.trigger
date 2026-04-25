trigger AccountTrigger on Account (before insert, after insert) {

    if (Trigger.isBefore && Trigger.isInsert) {
        List<Account> accounts = (List<Account>) Trigger.new;
        AccountHelper.setTypeProspect(Trigger.new);
        AccountHelper.addressCopy(accounts);
        AccountHelper.setRating(accounts);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        AccountHelper.defaultContact((List<Account>) Trigger.new);
    }
}
