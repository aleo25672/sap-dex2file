@AbapCatalog.sqlViewName: 'ZEVOOSLSCONTR'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Contract Header (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_O_SalesContract
  as select from I_SalesContract
  association [0..*] to ZEVO_O_SalesContractItem as _Item
    on $projection.SalesContract = _Item.SalesContract
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
      // S/4 2023 (108): SalesOrganization, DistributionChannel, OrganizationDivision,
      // SalesGroup, SalesOffice, SoldToParty not on local I_SalesContract
      SalesContractDate,
      SalesContractValidityStartDate,
      SalesContractValidityEndDate,
      TotalNetAmount,
      TransactionCurrency,
      OverallSDProcessStatus,
      OverallSDDocumentRejectionSts,
      _Item
}
