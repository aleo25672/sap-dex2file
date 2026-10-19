@AbapCatalog.sqlViewName: 'ZEVOOOUTBDITM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Outbound Delivery Item DEX (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_OutboundDelivItem
  as select from C_OutboundDeliveryItemDEX
  association [0..1] to ZEVO_O_BusinessPartner as _SoldToParty
    on $projection.SoldToParty = _SoldToParty.BusinessPartner
  association [0..1] to ZEVO_O_BusinessPartner as _ShipToParty
    on $projection.ShipToParty = _ShipToParty.BusinessPartner
{
  key OutboundDelivery,
  key OutboundDeliveryItem,
      SalesOrganization,
      BillingCompanyCode,
      ForwardingAgent,
      BillToParty,
      PayerParty,
      ShipToParty,
      SoldToParty,
      Supplier,
      CustomerGroup,
      OverallGoodsMovementStatus,
      OverallPackingStatus,
      ActualGoodsMovementDate,
      DeliveryDate,
      StatisticsDate,
      PlannedGoodsIssueDate,
      DeliveryBlockReason,
      DeliveryDocumentType as DeliveryDocumentTypeCode,
      DeliveryPriority,
      SDDocumentCategory,
      ShippingPoint,
      TotalNumberOfPackage,
      UnloadingPointName,
      IncotermsClassification,
      IncotermsTransferLocation,
      IncotermsVersion,
      IncotermsLocation1,
      IncotermsLocation2,
      _SoldToParty,
      _ShipToParty
}
