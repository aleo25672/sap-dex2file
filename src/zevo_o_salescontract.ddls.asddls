@AbapCatalog.sqlViewName: 'ZEVOOSLSCONTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Contract Header (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_SalesContract
  as select from I_SalesContract
  association [0..*] to ZEVO_O_SalesContractItem as _Item
    on $projection.SalesContract = _Item.SalesContract
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
{
  key SalesContract,
      SalesContractType as SalesContractTypeCode,
      CreatedByUser,
      LastChangedByUser,
      CreationDate,
      CreationTime,
      LastChangeDate,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangeDateTime,
      SalesOrganization,
      DistributionChannel,
      OrganizationDivision,
      SalesGroup,
      SalesOffice,
      SoldToParty,
      CustomerGroup,
      SalesContractDate,
      SalesContractValidityStartDate,
      SalesContractValidityEndDate,
      TotalNetAmount,
      TransactionCurrency,
      OverallSDProcessStatus,
      OverallSDDocumentRejectionSts,
      _Item,
      _SoldToParty
}
