/**
 * @File Name          : CreateLead.cls
 * @Description        : 
 * @Group              : 
 * @Last Modified By   : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On   : 11/13/2019, 5:03:08 PM
 * @Modification Log   : 
 * Ver       Date            Author                 Modification
 * 1.0    11/6/2019   ChangeMeIn@UserSettingsUnder.SFDoc     Initial Version
**/

public with Sharing class CreateLead {
    public CreateLead() {
    }

    public static RestResponse res = RestContext.response;
    public static string returnMessage = '';
    public static string fieldMessage = '';
    public static Boolean leadConvert = false;
    public static Boolean leadException = false;
    public static Boolean accountException = false;
    public static Boolean repeat = false;
    public static string setOwner;
    public static Id LeadIdd;
    public static Id accountIdd;
    public static Id contactIdd;

    public static void jsonRequest(JSONWrapper request)
    {
        try
        {
            if(request.IsNewLeadExpected == true)
            {
                leadAvailablity(request.LeadInfo);
                return;
            }

            if(request.EntityInfo!=null && request.EntityInfo.MoulaId!=null)
            {
                returnMessage = returnMessage + ' Updating/Creating account for MID: ' + request.EntityInfo.MoulaId;
                accountAvailablity(request.EntityInfo);
            }

            if(request.ApplicantInfo!=null && request.ApplicantInfo.UserId!=null && accountException==false)
            {                
                returnMessage = returnMessage + ' Updating/Creating contact for email: ' + request.ApplicantInfo.Email;
                contactAvailablity(request.ApplicantInfo);
            }

            if(request.ApplicationInfo.LoanAppId == null)
            {
                repeat = true;
                if (request.LeadInfo!=null && request.LeadInfo.Email != null)
                {
                    leadAvailablity(request.LeadInfo);
                }
                
                if(request.EntityInfo != null && request.ApplicantInfo != null 
                    && request.EntityInfo.MoulaId != null && request.ApplicantInfo.UserId != null)
                {
                    if(RestContext.response.statusCode != 400)
                    {
                        accountAvailablity(request.EntityInfo);
                        if(accountException != true)
                        {
                            contactAvailablity(request.ApplicantInfo);
                        }
                   }
                }
                else
                {
                    res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Moula Id or User Id Required');
                }
            }
            else
            {
                System.debug('calling opportunityAvailability');
                opportunityAvailablity(request.ApplicationInfo, request.LeadInfo, request.EntityInfo, request.ApplicantInfo);
            }
        }
        catch(Exception e)
        {
            RestContext.response.statusCode = 400;
            res.responseBody = Blob.valueOf('Error occured updating/creating objects. ' + returnMessage + '\r\n' + e.getCause()+' Message:\r\n'+e.getMessage()+'\r\nLine:\r\n'+
                e.getLineNumber()+'\r\nStack Trace:\r\n'+e.getStackTraceString());
        }
    }

    //If lead available with the given email, update. Else create
    public static void leadAvailablity(JSONWrapper.LeadInfo leads){
       try
       {
            List<Lead> existingLead = new List<Lead>();
            List<Lead> createLead = new List<Lead>();
            for(Lead leadSO : [SELECT id,
                                      Company,
                                      Title,
                                      FirstName,
                                      LastName,
                                      Email,
                                      MobilePhone,
                                      Phone,
                                      State,
                                      Loan_Application_ID__c,
                                      Partner_Portal_GUID__c,
                                      LeadSource,
                                      OwnerId,
                                      Status,
                                      Lead_Type__c
                              FROM Lead
                              WHERE Email = :leads.Email AND 
                                  (Status != :Label.Cancelled_Status AND Status != :Label.Loan_Application_Submitted)]){
                if(leads.Company != null)
                {
                    leadSO.Company = leads.Company;
                }
                else 
                {
                    leadSO.Company = leads.LastName;
                }
                
                leadSO.Title = leads.Title;
                leadSO.FirstName = leads.FirstName;
                leadSO.LastName = leads.LastName;
                leadSO.Email = leads.Email;
                leadSO.MobilePhone = leads.MobilePhone;

                if(leads.Phone !=null)
                {
                    leadSO.Phone = leads.Phone;
                }

                leadSO.State = leads.State;
                leadSO.Partner_Portal_GUID__c = leads.ReferralId;
                leadSO.LeadSource = leads.LeadSource;
                leadSO.Lead_Type__c = leads.LeadType;
                existingLead.add(leadSO);
            }

            if(!existingLead.isEmpty() && existingLead.size() > 0 )
            {
                update existingLead;
                if(repeat == false && leadConvert == false)
                {
                    res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Lead Updated');
                }
                else if(leadConvert == true)
                {
                    LeadIdd = existingLead[0].id;
                    if(existingLead[0].OwnerId == Label.DirectQueue)
                    {
                        setOwner = Label.DirectQueue_User_Id;
                    }
                    else 
                    {
                        setOwner = existingLead[0].OwnerId;
                    }
                }
                else
                {
                    returnMessage = returnMessage + '\r\n' + 'Lead Updated ';
                    res.responseBody = Blob.valueOf(returnMessage);
                }
            }
            else if(leadConvert == true)
            {
                leadConvert = false;
                res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Lead does not exists');
            }
            else
            { 
                Lead leasSO = new Lead();
                if(leads.Company != null)
                {
                    leasSO.Company = leads.Company;
                }
                else
                {
                    leasSO.Company = leads.LastName;
                }
                
                leasSO.RecordTypeId = Label.Customer_Record_Type;
                leasSO.Title = leads.Title;
                leasSO.FirstName = leads.FirstName;
                leasSO.LastName = leads.LastName;
                leasSO.Email = leads.Email;
                leasSO.MobilePhone = leads.MobilePhone;

                if(leads.Phone !=null)
                {
                    leasSO.Phone = leads.Phone;
                }

                leasSO.State = leads.State;
                leasSO.Loan_Application_ID__c = leads.CurrentLoanId;
                leasSO.Partner_Portal_GUID__c = leads.ReferralId;
                leasSO.LeadSource = leads.LeadSource;
                leasSO.Lead_Type__c = leads.LeadType;
                setPartnerAccountAndContact(leasSO, leads.PartnerId);
                createLead.add(leasSO);
            }

            if(!createLead.isEmpty() && createLead.size() > 0)
            {
                insert createLead;
                if(repeat == false && leadConvert == false)
                {
                     res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Lead Created');
                }
                else
                {
                    returnMessage = returnMessage + '\r\n' + 'Lead Created ';
                    res.responseBody = Blob.valueOf(returnMessage);
                }
            }
        }
        catch(Exception e)
        {
            leadException = true;
            RestContext.response.statusCode = 400;
            res.responseBody = Blob.valueOf('Error occured creating/updating Lead. ' + returnMessage + '\r\n' + e.getCause()+'Message:\r\n'+e.getMessage()+'\r\nLine:\r\n'
                                    + e.getLineNumber()+'\r\nStack Trace:\r\n'+e.getStackTraceString());
        }
    }
    
    public static Lead  findOpenLeadByEmail(String email)
    {
        List<Lead> leadSOs = [SELECT id,
                                      Company,
                                      Title,
                                      FirstName,
                                      MiddleName,
                                      LastName,
                                      Email,
                                      MobilePhone,
                                      Phone,
                                      State,
                                      Loan_Application_ID__c,
                                      Partner_Portal_GUID__c,
                                      LeadSource,
                                      OwnerId,
                                      Status,
                                      Lead_Type__c
                              FROM Lead
                              WHERE Email = :email AND 
                                (Status != :Label.Cancelled_Status AND Status != :Label.Loan_Application_Submitted)];

       if(leadSOs==null || leadSOs.isEmpty()|| leadSOs.size()==0)
       {
           return null;
       }
       else
       {
            if(leadSOs[0].OwnerId == Label.DirectQueue)
            {
                setOwner = Label.DirectQueue_User_Id;
            }
            else
            {
                setOwner = leadSOs[0].OwnerId;
            }
           return leadSOs[0];
       }
    }
    
    public static Lead createLeadFromContact(JSONWrapper.ApplicantInfo contact)
    {
        Lead leasSO = new Lead();

        leasSO.Company = contact.LastName;

        leasSO.RecordTypeId = Label.Customer_Record_Type;
        leasSO.Title = contact.Title;
        leasSO.FirstName = contact.FirstName;
        leasSO.LastName = contact.LastName;
        leasSO.Email = contact.Email;
        leasSO.MobilePhone = contact.MobilePhone;
        leasSO.State = 'VIC';
        leasSO.LeadSource = '';
        leasSO.Lead_Type__c = 'GetStarted';
        insert leasSO;

        return findOpenLeadByEmail(contact.Email);
    }
    
    //If account available with the given moulaId, update. Else create
    public static string accountId;
    public static void accountAvailablity(JSONWrapper.EntityInfo accounts)
    {
        try{
            List<Account> existingAccount = new List<Account>();
            List<Account> createAccount = new List<Account>();
            for(Account accountSO : [SELECT id,
                                            Phone,
                                            Trading_Year__c,
                                            Name,
                                            Moula_GUID__c,
                                            ABN_ACN__c,
                                            ACN__c,
                                            Type_of_Trust__c,
                                            Structure__c,
                                           // Prior_Borrower__c,
                                            Industry_Level_1__c,
                                            Industry_Level_2__c,
                                            Industry_Level_3__c,
                                            BillingStreet,
                                            BillingCity,
                                            BillingState,
                                            BillingPostalCode,
                                            RecordTypeId
                                    FROM Account 
                                    WHERE EntityID__c =: accounts.MoulaId])            
            {
                System.debug('account found: '+ accounts.MoulaId);
                accountSO.Phone = accounts.Phone;
                accountSO.Name = accounts.EntityName;
                accountSO.Trading_Year__c = accounts.TradingYear;
                accountSO.Industry_Level_1__c = accounts.Industry1;
                accountSO.Industry_Level_2__c = accounts.Industry2;
                accountSO.Industry_Level_3__c = accounts.Industry3;
                accountSO.BillingStreet  = accounts.BusinessAddress.Street;
                accountSO.BillingCity = accounts.BusinessAddress.City;
                accountSO.BillingState = accounts.BusinessAddress.State;
                accountSO.BillingPostalCode = accounts.BusinessAddress.Postcode;
               // accountSO.Prior_Borrower__c = accounts.PriorBorrower;
                accountSO.Moula_GUID__c = accounts.MoulaGuid;
                accountSO.ABN_ACN__c = accounts.ABN;
                accountSO.ACN__c = accounts.ACN;
                accountSO.Structure__c = translateCompanyType(accounts.CompanyType);
                accountSO.Type_of_Trust__c = 'None';
                accountSO.Relationship_to_Structure__c=translateCompositionComposition(accounts.CompanyType,accounts.CompanyComposition);
                existingAccount.add(accountSO);
                returnMessage = returnMessage + '\r\nRelationsihip to Structure: ' + translateCompositionComposition(accounts.CompanyType,accounts.CompanyComposition);
            }

            if(!existingAccount.isEmpty() && existingAccount.size() > 0 )
            {                
                update existingAccount;
                if(leadConvert == true)
                {
                    accountIdd = existingAccount[0].id;
                }
                else
                {
                    returnMessage = returnMessage + '\r\n' + 'Account Updated ';
                    res.responseBody = Blob.valueOf(returnMessage);
                }
            }
            else
            {
                System.debug('creating new account for :' + accounts.MoulaId);
                Account accountSO = new Account();
                accountSO.Phone = accounts.Phone;
                accountSO.Name = accounts.EntityName;
                accountSO.Trading_Year__c = accounts.TradingYear;
                accountSO.EntityID__c = accounts.MoulaId;
                accountSO.Industry_Level_1__c = accounts.Industry1;
                accountSO.Industry_Level_2__c = accounts.Industry2;
                accountSO.Industry_Level_3__c = accounts.Industry3;
                accountSO.BillingStreet  = accounts.BusinessAddress.Street;
                accountSO.BillingCity = accounts.BusinessAddress.City;
                accountSO.BillingState = accounts.BusinessAddress.State;
                accountSO.BillingPostalCode = accounts.BusinessAddress.Postcode;
               // accountSO.Prior_Borrower__c = accounts.PriorBorrower;
                accountSO.Moula_GUID__c = accounts.MoulaGuid;
                accountSO.ABN_ACN__c = accounts.ABN;
                accountSO.Structure__c = translateCompanyType(accounts.CompanyType);
                accountSO.Type_of_Trust__c = 'None';
                accountSO.Relationship_to_Structure__c = translateCompositionComposition(accounts.CompanyType,accounts.CompanyComposition);
                accountSO.RecordTypeId = Label.Customer_Account;
                createAccount.add(accountSO);
                returnMessage = returnMessage + '\r\nRelationsihip to Structure: ' + translateCompositionComposition(accounts.CompanyType,accounts.CompanyComposition);
            }

            if(!createAccount.isEmpty() && createAccount.size() > 0)
            {
                insert createAccount;
                accountId = createAccount[0].id;
                if(leadConvert == true)
                {
                    accountIdd = createAccount[0].id;
                }
                else
                {
                     returnMessage =  returnMessage + '\r\n' + 'Account Created ';
                     res.responseBody = Blob.valueOf(returnMessage);
                }
            }
        }
        catch(Exception e)
        {
            accountException = true;
            RestContext.response.statusCode = 400;
            res.responseBody = Blob.valueOf('Erro occured creating/updating Account. ' + returnMessage + '\r\n' + e.getCause()+'Message:\r\n'+e.getMessage()+'\r\nLine:\r\n'+
                e.getLineNumber()+'\r\nStack Trace:\r\n'+e.getStackTraceString());
        }
    }

    //If contact available with the given userId, update. Else create
    public static void contactAvailablity(JSONWrapper.ApplicantInfo contacts){
        try{
            List<Contact> extistingContacts = new List<Contact>();
            List<Contact> createContacts = new List<Contact>();
            for(Contact contactSO : [SELECT id,
                                            Title,
                                            FirstName,
                                            MiddleName,
                                            LastName,
                                            Birthdate,
                                            Email,
                                            MobilePhone,
                                            Phone,
                                            MailingStreet ,
                                            MailingCity,
                                            MailingState,
                                            MailingPostalCode,
                                            AccountId
                                    FROM Contact
                                    WHERE UserID__c =: contacts.UserId])
            {
                System.debug('contact found: ' + contacts.Email + '  - '+ contacts.UserId + '>> AccountId: ' + accountIdd);
                contactSO.Title = contacts.Title;
                contactSO.FirstName = contacts.FirstName;
                contactSO.MiddleName = contacts.MiddleName;
                contactSO.LastName = contacts.LastName;
                contactSO.Birthdate = contacts.DateOfBirth;
                contactSO.Email = contacts.Email;
                contactSO.MobilePhone = contacts.MobilePhone;
                contactSO.Phone = contacts.Phone;
                if(contacts.ApplicantAddress!=null)
                {
                    contactSO.MailingStreet = contacts.ApplicantAddress.Street;
                    contactSO.MailingCity = contacts.ApplicantAddress.City;
                    contactSO.MailingState = contacts.ApplicantAddress.State;
                    contactSO.MailingPostalCode = contacts.ApplicantAddress.Postcode;
                }
                
                if(accountIdd!=null)
                {
                    contactSO.AccountId = accountIdd;
                }
                extistingContacts.add(contactSO);
            }
            
            System.debug('existingContacts: Empty: '+extistingContacts.isEmpty()+' -- Size: '+extistingContacts.size());

            if(!extistingContacts.isEmpty() && extistingContacts.size() > 0 )
            {
                update extistingContacts;

                System.debug('found contact: '+extistingContacts[0].id + '   Lead Convert: '+leadConvert);

                if(leadConvert == true)
                {
                    contactIdd = extistingContacts[0].id;
                }
                else
                {
                    returnMessage =  returnMessage + '\r\n' + ' Contact Updated ';
                    res.responseBody = Blob.valueOf(returnMessage);
                }
            }
            else
            {
                System.debug('creating Contact' + contacts.Email+'  - '+contacts.UserId);
                Contact contactSO = new Contact();
                contactSO.Title = contacts.Title;
                contactSO.FirstName = contacts.FirstName;
                contactSO.MiddleName = contacts.MiddleName;
                contactSO.LastName = contacts.LastName;
                contactSO.Birthdate = contacts.DateOfBirth;
                contactSO.Email = contacts.Email;
                contactSO.MobilePhone = contacts.MobilePhone;
                contactSO.Phone = contacts.Phone;
                if(contacts.ApplicantAddress!=null)
                {
                    contactSO.MailingStreet  = contacts.ApplicantAddress.Street;
                    contactSO.MailingCity = contacts.ApplicantAddress.City;
                    contactSO.MailingState = contacts.ApplicantAddress.State;
                    contactSO.MailingPostalCode = contacts.ApplicantAddress.Postcode;
                }
                contactSO.AccountId = accountIdd;
                contactSO.UserID__c = contacts.UserId;
                createContacts.add(contactSO);
            }

            if(!createContacts.isEmpty() && createContacts.size() > 0 )
            {
                insert createContacts;

                System.debug('Inserted contact: '+ createContacts[0].id + '   Lead Convert: '+leadConvert);

                if(leadConvert == true)
                {
                    contactIdd = createContacts[0].id;
                }
                else
                {
                    returnMessage =  returnMessage + 'Contact Created ';
                    res.responseBody = Blob.valueOf(returnMessage);
                }
            }
        }
        catch(Exception e)
        {
            RestContext.response.statusCode = 400;
            res.responseBody = Blob.valueOf('Error occured creating/updating contact.  '+returnMessage + '\r\n' + e.getCause()+'Message:\r\n'+e.getMessage()+'\r\nLine:\r\n'+
                e.getLineNumber()+'\r\nStack Trace:\r\n'+e.getStackTraceString());
        }
    }

    //If LoanAppId present in existing opportunity, update the opportunity, else if lead available with the given email id, convert it
    public static void opportunityAvailablity(JSONWrapper.ApplicationInfo opportunities, JSONWrapper.LeadInfo leads,
                                              JSONWrapper.EntityInfo accounts, JSONWrapper.ApplicantInfo contacts){
        try{
            List<Opportunity> existingOpportunity = new List<Opportunity>();
            List<Opportunity> updateOpportunity = new List<Opportunity>();
            for(Opportunity opportunitySO : [SELECT id,
                                                    Name,
                                                    LeadSource,
                                                    CloseDate,
                                                    StageName,
                                                    Loan_Application_ID__c,
                                                    LoanID__c,
                                                    Requested_Amount__c,
                                                    Purpose_of_Funds__c,
                                                    Executed_Date__c,
                                                    Interest_Rate__c,
                                                    Offered_Amount__c,
                                                    Gross_Amount__c,
                                                    Admin_Stage__c,
                                                    Submitted_Date__c,
                                                    Requested_Term__c,
                                                    Offered_Term__c
                                            FROM Opportunity
                                            WHERE Loan_Application_ID__c =: opportunities.LoanAppId
                                                AND StageName != :Label.Closed_Stage]){
                System.debug('opportunityAvailability found with loan app id: ' + opportunities.LoanAppId);
                opportunitySO.Loan_Application_ID__c = opportunities.LoanAppId;
                opportunitySO.LoanID__c = opportunities.LoanId;
                opportunitySO.Requested_Amount__c = opportunities.RequestedAmount;
                
                if(opportunities.AppExecutedDate != null)
                {
                    opportunitySO.Executed_Date__c = opportunities.AppExecutedDate.date();
                }
                
                if(opportunities.InterestRate != null)
                {
                    opportunitySO.Interest_Rate__c = opportunities.InterestRate * 100;
                }
                opportunitySO.Offered_Amount__c = opportunities.AmountOffered;
                opportunitySO.Gross_Amount__c = opportunities.GrossAmount;
                opportunitySO.Admin_Stage__c = opportunities.LoanAppStatus;
                if(opportunities.LoanAppSubmittedOn!=null)
                {
                    opportunitySO.Submitted_Date__c = opportunities.LoanAppSubmittedOn.date();
                }
                opportunitySO.Requested_Term__c = opportunities.RequestedTerm;
                opportunitySO.Offered_Term__c = opportunities.TermOffered;
                opportunitySO.Amount = opportunities.NetAmountFinanced;
                setPreviouOpportunityId(opportunitySO,opportunities.PreviousApplicationId);
                existingOpportunity.add(opportunitySO);
            }

            if(!existingOpportunity.isEmpty() && existingOpportunity.size() > 0 )
            {
                update existingOpportunity;
                res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Opportunity Updated AppId: ' + opportunities.LoanAppId
                        + ' Status: ' + existingOpportunity[0].Admin_Stage__c);
            }
            else 
            {
                System.debug('did not find opportunity: ' + opportunities.LoanAppId);
                /*if (leads.Email != null && leads.LastName != null) {*/
                if(contacts.Email!=null)
                {
                    System.debug('finding lead by email: ' + contacts.Email);
                    leadConvert = true;
                    Lead leadSO = findOpenLeadByEmail(contacts.Email);
                    if(leadSO==null)
                    {
                        System.debug('creating lead for: '+ contacts.Email);
                        leadSO = createLeadFromContact(contacts);
                    }

                    if(leadSO==null)
                    {
                        res.responseBody=Blob.valueOf(returnMessage + '\r\n' + 'Unable to create lead to create opportunity');
                        RestContext.response.statusCode=400;
                        return;
                    }

                    LeadIdd = leadSO.id;

                    updateContactFromLead(leadSO, contacts);

                    /*leadAvailablity(leads);*/
                } 
                else 
                {
                    if (leads.Email == null) 
                    {
                        fieldMessage = 'Email field is missing ';
                    }
                    if (leads.LastName == null) 
                    {
                        if (fieldMessage != null) 
                        {
                            fieldMessage = fieldMessage + 'LastName field is missing';
                        }
                        else 
                        {
                            fieldMessage = 'LastName field is missing';
                        }
                    }

                    RestContext.response.statusCode = 400;
                    res.responseBody = Blob.valueOf(returnMessage + '\r\n' + fieldMessage);
                    return;
                }
                
                if(LeadIdd != null)
                {
                    if(accounts.MoulaId != null && contacts.UserId != null)
                    { 
                        System.debug('checking account availability: '+accounts.MoulaId);
                        accountAvailablity(accounts);

                        if(accountIdd != null)   
                        {
                            System.debug('checking contact availability: '+ contacts.UserId);
                            contactAvailablity(contacts);
                        }  
                    }
                    else
                    {
                        RestContext.response.statusCode = 400;
                        res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Moula Id or User Id Required');
                        return;
                    }
                }

                Database.LeadConvert lc = new Database.LeadConvert();                
                if(LeadIdd != null && accountIdd != null && contactIdd != null)
                {
                    lc.setLeadId(LeadIdd);
                    lc.setAccountId(accountIdd);
                    lc.setContactId(contactIdd);
                    lc.setOwnerId(setOwner);

                    System.debug('LeadIdd##'+LeadIdd + '  accountIdd ##'+ accountIdd + '  contactIdd##'+ contactIdd);
                    
                    lc.setConvertedStatus('Loan_Application_Submitted');
                    Database.LeadConvertResult lcr = Database.convertLead(lc);
                    if (lcr.isSuccess()) 
                    {
                        id opportunityId = lcr.getOpportunityId();
                        Opportunity opportunitySO = [SELECT Name,
                                                            LeadSource,
                                                            CloseDate,
                                                            StageName,
                                                            Loan_Application_ID__c,
                                                            LoanID__c,
                                                            Requested_Amount__c,
                                                            Purpose_of_Funds__c,
                                                            Executed_Date__c,
                                                            Interest_Rate__c,
                                                            Offered_Amount__c,
                                                            Gross_Amount__c,
                                                            Admin_Stage__c,
                                                            Submitted_Date__c,
                                                            Requested_Term__c,
                                                            Offered_Term__c,
                                                            Opportunity_Status__c
                                                    FROM Opportunity
                                                    WHERE id =: opportunityId];
                        opportunitySO.Loan_Application_ID__c = opportunities.LoanAppId;
                        opportunitySO.LoanID__c = opportunities.LoanId;
                        opportunitySO.Requested_Amount__c = opportunities.RequestedAmount;

                        if(opportunities.AppExecutedDate!=null)
                        {
                            opportunitySO.Executed_Date__c = opportunities.AppExecutedDate.date();
                        }
                        
                        if(opportunities.InterestRate != null)
                        {
                            opportunitySO.Interest_Rate__c = opportunities.InterestRate * 100;
                        }
                        
                        opportunitySO.Offered_Amount__c = opportunities.AmountOffered;
                        opportunitySO.Gross_Amount__c = opportunities.GrossAmount;
                        opportunitySO.Admin_Stage__c = opportunities.LoanAppStatus;

                        if(opportunities.LoanAppSubmittedOn!=null)
                        {
                            opportunitySO.Submitted_Date__c = opportunities.LoanAppSubmittedOn.date();
                        }
                        
                        opportunitySO.Requested_Term__c = opportunities.RequestedTerm;
                        opportunitySO.Offered_Term__c = opportunities.TermOffered;
                        opportunitySO.Amount = opportunities.NetAmountFinanced;
                        opportunitySO.Opportunity_Status__c = Label.App_incomplete_Status;
                        opportunitySO.StageName = Label.Apply_Stage;
                        setPreviouOpportunityId(opportunitySO,opportunities.PreviousApplicationId);
                        updateOpportunity.add(opportunitySO);
                    }
                }

                if(!updateOpportunity.isEmpty() && updateOpportunity.size() > 0)
                {
                    update updateOpportunity;  
                    res.responseBody = Blob.valueOf(returnMessage + '\r\n' + 'Lead converted');
                }
            } 
        }
        catch (Exception e) 
        {
            RestContext.response.statusCode = 400;
            res.responseBody = Blob.valueOf('Error updating Opportunity. '+returnMessage + '\r\nCuase: ' + e.getCause()+'Message: '+e.getMessage()+'\r\nLine: '+
                e.getLineNumber()+'\r\nStack Trace:\r\n'+e.getStackTraceString());
        }
    }

    private static void updateContactFromLead(Lead lead, JSONWrapper.ApplicantInfo contact)
    {
        if(contact.FirstName==null || String.isEmpty(contact.FirstName))
        {
            contact.FirstName=lead.FirstName;
        }

        if(contact.MiddleName==null || String.isEmpty(contact.MiddleName))
        {
            contact.MiddleName=lead.MiddleName;
        }

        if(contact.LastName==null || String.isEmpty(contact.LastName))
        {
            contact.LastName=lead.LastName;
        }

        if(contact.Title==null || String.isEmpty(contact.Title))
        {
            contact.Title=lead.Title;
        }

        if(contact.MobilePhone==null || String.isEmpty(contact.MobilePhone))
        {
            contact.MobilePhone=lead.MobilePhone;
        }

        if(contact.Email==null || String.isEmpty(contact.Email))
        {
            contact.Email=lead.Email;
        }
    }

    private static String translateCompanyType(String companyType)
    {
        if(companyType.toLowercase().contains('trust'))
        {
            return 'Trust';
        }
        return companyType;
    }
    
    private static String translateCompositionComposition(string companyType, string companyComposition)
    {
        if(companyType.toLowercase().contains('trust'))
        {
             if(companyComposition=='Corporation')
            {
                return 'Corporate Trustee';
            }

            if(companyComposition=='Individual')
            {
                return 'Individual Trustee';
            }

            return companyComposition;
        }

        if(companyType.toLowercase().contains('partner'))
        {
             if(companyComposition=='Corporation')
            {
                return 'Corporate Partner';
            }

            if(companyComposition=='Individual')
            {
                return 'Individual Partner';
            }

            return companyComposition;
        }

        if(companyComposition.toLowercase()=='sole')
        {
             return '';
        }

         return companyComposition;
    }

    private static void setPreviouOpportunityId(Opportunity opp, string oldLoanAppId)
    {
        if(oldLoanAppId==null||String.isEmpty(oldLoanAppId))
        {
            return;
        }

        for(Opportunity o : [SELECT id, Loan_Application_ID__c,Opportunity_Status__c
                                            FROM Opportunity
                                            WHERE Loan_Application_ID__c =: oldLoanAppId AND id !=: opp.id])
        {
            returnMessage = returnMessage + '\r\nPrevious Opportunity: ' + o.Opportunity_Status__c + '\tID: '+o.id;
            opp.Previous_Application_Id__c=o.id;
        }
    }

    private static void setPartnerAccountAndContact(Lead lead, string partnerId)
    {
        if(partnerId==null||string.isEmpty(partnerId))
        {
            return;
        }

        for(Contact contact: [SELECT id, Name, AccountId FROM Contact WHERE Partner_Portal_GUID__c =: partnerId])
        {
            returnMessage = returnMessage + '\r\nSet Partner Account and Contact Id';
            lead.Partner_Contact__c = contact.Id;
            lead.Partner_Account__c = contact.AccountId;
        }
    }
}