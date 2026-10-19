@AbapCatalog.sqlViewName: 'ZEVOOSLSDOCIT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Document Item DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_SalesDocumentItem
  as select from C_SalesDocumentItemDEX
  association [0..*] to ZEVO_O_SalesDocSchedLine as _ScheduleLine
    on $projection.SalesDocument = _ScheduleLine.SalesDocument
   and $projection.SalesDocumentItem = _ScheduleLine.SalesDocumentItem
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
{
  key SalesDocument,
  key SalesDocumentItem,
      SDDocumentCategory,
      SalesDocumentType as SalesDocumentTypeCode,
      SalesDocumentItemCategory,
      CreationDate,
      CreationTime,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      SalesOrganization,
      DistributionChannel,
      Division,
      Material,
      Product,
      SoldToParty,
      ShipToParty,
      BillToParty,
      PayerParty,
      SalesDocumentDate,
      OrderQuantity,
      OrderQuantityUnit,
      NetAmount,
      TransactionCurrency,
      ReferenceSDDocument,
      ReferenceSDDocumentCategory,
      _ScheduleLine,
      _SoldToParty
}
