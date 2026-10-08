@AbapCatalog.sqlViewName: 'ZEVOCSUPPITEM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Supplier Invoice Item (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_SupplierInvItem
  as select from C_SupplierInvoiceItemDEX
  association [1..1] to ZEVO_C_SupplierInvoice as _Header
    on $projection.SupplierInvoice = _Header.SupplierInvoice and $projection.FiscalYear = _Header.FiscalYear
  association [0..1] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseOrder = _PurchaseOrderItem.PurchaseOrder and $projection.PurchaseOrderItem = _PurchaseOrderItem.PurchaseOrderItem
  association [0..*] to ZEVO_C_GoodsMovementDoc as _GoodsMovement
    on $projection.PrmthbReferenceDocument = _GoodsMovement.MaterialDocument and $projection.PrmthbReferenceDocumentFsclyr = _GoodsMovement.MaterialDocumentYear
{
  key SupplierInvoice,
  key FiscalYear,
  key SupplierInvoiceItem,
      QtyInPurchaseOrderPriceUnit,
      PurchaseOrderPriceUnit,
      PurchaseOrderQuantityUnit,
      PurchaseOrder,
      PurchaseOrderItem,
      PrmthbReferenceDocument,
      PrmthbReferenceDocumentFsclyr,
      PrmthbReferenceDocumentItem,
      PurchaseOrderItemMaterial,
      QuantityInPurchaseOrderUnit,
      SuplrInvcItmHasQualityVariance,
      SuplrInvcItemHasOrdPrcQtyVarc,
      SuplrInvcItemHasQtyVariance,
      SuplrInvcItemHasPriceVariance,
      SuplrInvcItemHasOtherVariance,
      SuplrInvcItemHasAmountOutsdTol,
      SuplrInvcItemHasDateVariance,
      IsSubsequentDebitCredit,
      Plant,
      DocumentCurrency,
      SupplierInvoiceItemAmount,
      SuplrInvcAutomReducedAmount,
      UnplannedDeliveryCost,
      DocumentHeaderText,
      DocumentDate,
      PostingDate,
      CompanyCode,
      SupplierInvoiceOrigin,
      InvoicingParty,
      UnplannedDeliveryCostTaxCode,
      ReverseDocument,
      ReverseDocumentFiscalYear,
      SupplierInvoiceIDByInvcgParty,
      IsInvoice,
      SupplierInvoiceStatus,
      _Header,
      _PurchaseOrderItem,
      _GoodsMovement
}
