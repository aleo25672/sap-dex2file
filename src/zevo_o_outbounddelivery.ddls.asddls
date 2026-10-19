@AbapCatalog.sqlViewName: 'ZEVOOOUTBDEL'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Outbound Delivery Header DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_OutboundDelivery
  as select from C_OutboundDeliveryDEX
  association [0..*] to ZEVO_O_OutboundDelivItem as _Item
    on $projection.OutboundDelivery = _Item.OutboundDelivery
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
  association [0..1] to ZEVO_O_BusinessPartner as _ShipToParty
    on $projection.ShipToParty = _ShipToParty.BusinessPartner
{
  key OutboundDelivery,
      SDDocumentCategory,
      DeliveryDocumentType as DeliveryDocumentTypeCode,
      CreatedByUser,
      CreationDate,
      CreationTime,
      LastChangedByUser,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      ShippingPoint,
      SalesOrganization,
      SalesOffice,
      ShipToParty,
      SoldToParty,
      DeliveryDate,
      PlannedGoodsIssueDate,
      ActualGoodsMovementDate,
      ActualGoodsMovementTime,
      OverallGoodsMovementStatus,
      OverallPickingStatus,
      OverallSDProcessStatus,
      TransactionCurrency,
      TotalNetAmount,
      DocumentDate,
      DeliveryBlockReason,
      ShippingCondition,
      _Item,
      _SoldToParty,
      _ShipToParty
}
