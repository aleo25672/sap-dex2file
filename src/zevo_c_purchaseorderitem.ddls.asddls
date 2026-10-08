@AbapCatalog.sqlViewName: 'ZEVOCPUROITEM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Order Item (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseOrderItem
  as select from C_PurchaseOrderItemDEX
  association [1..1] to ZEVO_C_PurchaseOrder as _Header
    on $projection.PurchaseOrder = _Header.PurchaseOrder
  association [0..*] to ZEVO_C_PurchaseOrderHist as _History
    on $projection.PurchaseOrder = _History.PurchaseOrder and $projection.PurchaseOrderItem = _History.PurchaseOrderItem
  association [0..*] to ZEVO_C_PurOrdAcctAssgmt as _AccountAssignment
    on $projection.PurchaseOrder = _AccountAssignment.PurchaseOrder and $projection.PurchaseOrderItem = _AccountAssignment.PurchaseOrderItem
  association [0..1] to ZEVO_C_PurchRequisitionItem as _PurchaseRequisitionItem
    on $projection.PurchaseRequisition = _PurchaseRequisitionItem.PurchaseRequisition and $projection.PurchaseRequisitionItem = _PurchaseRequisitionItem.PurchaseRequisitionItem
  association [0..1] to ZEVO_C_PurchContractItem as _PurchaseContractItem
    on $projection.PurchaseContract = _PurchaseContractItem.PurchaseContract and $projection.PurchaseContractItem = _PurchaseContractItem.PurchaseContractItem
{
  key PurchaseOrder,
  key PurchaseOrderItem,
      PurchaseOrderType,
      PurchasingGroup,
      PurchasingOrganization,
      PurchasingDocumentOrigin,
      Supplier,
      SupplyingSupplier,
      SupplyingPlant,
      DocumentCurrency,
      ExchangeRate,
      InvoicingParty,
      PurchaseOrderDate,
      ValidityStartDate,
      ValidityEndDate,
      CreationDate,
      LastChangeDateTime,
      PurgDocumentItemDeletionCode,
      MaterialGroup,
      Material,
      ManufacturerMaterial,
      PurchaseOrderCategory,
      PurchasingOrderReason,
      PurchaseOrderItemText,
      PurchaseOrderItemCategory,
      CompanyCode,
      Plant,
      StorageLocation,
      PurchaseContract,
      PurchaseContractItem,
      BaseUnit,
      OrderQuantity,
      PurchaseOrderQuantityUnit,
      NetPriceAmount,
      NetAmount,
      LocalCurrency,
      NetPriceQuantity,
      OrderPriceUnit,
      RequisitionerName,
      RetailPromotion,
      IsCompletelyDelivered,
      IsReturnsItem,
      IsFinallyInvoiced,
      InvoiceIsExpected,
      OrderItemQtyToBaseQtyDnmntr,
      OrderItemQtyToBaseQtyNmrtr,
      InvoiceIsGoodsReceiptBased,
      GoodsReceiptIsExpected,
      EvaldRcptSettlmtIsAllowed,
      AccountAssignmentCategory,
      GoodsReceiptIsNonValuated,
      MaterialType,
      OverdelivTolrtdLmtRatioInPct,
      ServicePerformer,
      TaxCode,
      UnderdelivTolrtdLmtRatioInPct,
      UnlimitedOverdeliveryIsAllowed,
      SupplierMaterialNumber,
      ProductTypeCode,
      CreatedByUser,
      ExpectedOverallLimitAmount,
      OverallLimitAmount,
      RequirementSegment,
      ReleaseIsNotCompleted,
      PurchasingCompletenessStatus,
      IsStatisticalItem,
      MultipleAcctAssgmtDistribution,
      PurchaseRequisition,
      PurchaseRequisitionItem,
      SupplierConfirmationControlKey,
      PurchasingDocumentDeletionCode,
      _Header,
      _History,
      _AccountAssignment,
      _PurchaseRequisitionItem,
      _PurchaseContractItem
}
