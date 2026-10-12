@AbapCatalog.sqlViewName: 'ZEVOFIGLLINE'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'G/L Account Line Item (General Ledger)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view ZEVO_FI_GLAcctLineItem
  as select from I_GLAccountLineItemRawData
  association [0..1] to ZEVO_FI_CompanyCode as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode
  association [0..1] to ZEVO_FI_GLAccount as _GLAccount
    on $projection.ChartOfAccounts = _GLAccount.ChartOfAccounts
   and $projection.GLAccount = _GLAccount.GLAccount
  association [0..1] to ZEVO_FI_Ledger as _Ledger
    on $projection.SourceLedger = _Ledger.Ledger
  association [0..1] to ZEVO_FI_AccountingDocType as _AccountingDocType
    on $projection.AccountingDocumentType = _AccountingDocType.AccountingDocumentType
  association [0..1] to ZEVO_FI_HouseBank as _HouseBank
    on $projection.CompanyCode = _HouseBank.CompanyCode
   and $projection.HouseBank = _HouseBank.HouseBank
{
  key SourceLedger,
  key CompanyCode,
  key FiscalYear,
  key AccountingDocument,
  key LedgerGLLineItem,
      ChartOfAccounts,
      ControllingArea,
      cast( GLAccount as abap.char(10) ) as GLAccount,
      CostCenter,
      ProfitCenter,
      FunctionalArea,
      BusinessArea,
      Segment,
      FinancialAccountType,
      AccountingDocumentType,
      PostingKey,
      DebitCreditCode,
      DocumentDate,
      @Semantics.businessDate.at: true
      PostingDate,
      FiscalPeriod,
      CreationDate,
      CreationDateTime,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangeDateTime,
      AccountingDocCreatedByUser,
      CompanyCodeCurrency,
      AmountInCompanyCodeCurrency,
      TransactionCurrency,
      AmountInTransactionCurrency,
      ReferenceDocumentType,
      ReferenceDocument,
      ReferenceDocumentContext,
      ReferenceDocumentItem,
      Supplier,
      Customer,
      PurchasingDocument,
      PurchasingDocumentItem,
      Plant,
      TaxCode,
      HouseBank,
      HouseBankAccount,
      ClearingDate,
      ClearingJournalEntry,
      ClearingJournalEntryFiscalYear,
      cast( OffsettingAccount as abap.char(10) ) as OffsettingAccount,
      OffsettingAccountType,
      OrderID,
      WBSElementInternalID,
      _CompanyCode,
      _GLAccount,
      _Ledger,
      _AccountingDocType,
      _HouseBank
}
