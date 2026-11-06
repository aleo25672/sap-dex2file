@AbapCatalog.sqlViewName: 'ZEVOOOUTBDEL'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Outbound Delivery Header (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@Metadata.ignorePropagatedAnnotations: true
define view ZEVO_O_OutboundDelivery
  // S/4 2023 (108): C_OutboundDeliveryDEX missing — I_DeliveryDocument + category J
  as select from I_DeliveryDocument
  association [0..*] to ZEVO_O_OutboundDelivItem as _Item
    on $projection.OutboundDelivery = _Item.OutboundDelivery
  association [0..*] to ZEVO_O_GoodsMovementDoc as _GoodsMovement
    on $projection.OutboundDelivery = _GoodsMovement.DeliveryDocument
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
  association [0..1] to ZEVO_O_BusinessPartner as _ShipToParty
    on $projection.ShipToParty = _ShipToParty.BusinessPartner
{
  key DeliveryDocument as OutboundDelivery,
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
      DocumentDate,
      DeliveryBlockReason,
      ShippingCondition,
      _Item,
      _GoodsMovement,
      _SoldToParty,
      _ShipToParty
}
where SDDocumentCategory = 'J'
