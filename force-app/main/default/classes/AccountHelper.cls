public with sharing class AccountHelper {

    public static void setTypeProspect(List<SObject> objects) {
        for (SObject obj : objects) {
            Account acc = (Account) obj;
            if (acc.Type == null) {
                acc.Type = 'Prospect';
            }
        }
    }

    public static void addressCopy(List<Account> accounts) {
        for (Account acc : accounts) {
            if (acc.ShippingStreet != null) {
                acc.BillingStreet = acc.ShippingStreet;
            }
            if (acc.ShippingCity != null) {
                acc.BillingCity = acc.ShippingCity;
            }
            if (acc.ShippingState != null) {
                acc.BillingState = acc.ShippingState;
            }
            if (acc.ShippingPostalCode != null) {
                acc.BillingPostalCode = acc.ShippingPostalCode;
            }
            if (acc.ShippingCountry != null) {
                acc.BillingCountry = acc.ShippingCountry;
            }
        }
    }

    public static void setRating(List<Account> accounts) {
        for (Account acc : accounts) {
            if (acc.Phone != null && acc.Website != null && acc.Fax != null) {
                acc.Rating = 'Hot';
            }
        }
    }

    public static void defaultContact(List<Account> accounts) {
        List<Contact> contacts = new List<Contact>();
        for (Account acc : accounts) {
            Contact con = new Contact();
            con.LastName = 'DefaultContact';
            con.Email = 'default@email.com';
            con.AccountId = acc.Id;
            contacts.add(con);
        }
        insert contacts;
    }
}
